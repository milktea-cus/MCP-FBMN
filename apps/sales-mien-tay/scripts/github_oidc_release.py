#!/usr/bin/env python3
"""Owner-approved signed Android release using short-lived GitHub OIDC.

The private signing keystore never enters Git, chat, Actions artifacts or logs.
Cloudflare stores an AES-GCM encrypted copy in private R2. New versions fetch
that same keystore and upload verified APK bytes through an OIDC-scoped Worker.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import urllib.error
import urllib.parse
import urllib.request

AUDIENCE = "field-work-android-release-mcp-fbmn"
BASE = "https://field-sales-api.milktea-cus.workers.dev/api/internal/field-work/android"
PUBLIC = "https://field-sales-api.milktea-cus.workers.dev/api/v1/app/releases/install.apk"
ALIAS = "field-work"


def oidc():
    url = os.environ["ACTIONS_ID_TOKEN_REQUEST_URL"]
    sep = "&" if "?" in url else "?"
    url += sep + "audience=" + urllib.parse.quote(AUDIENCE, safe="")
    request = urllib.request.Request(url, headers={
        "Authorization": "Bearer " + os.environ["ACTIONS_ID_TOKEN_REQUEST_TOKEN"]
    })
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)["value"]


def call(path, method="GET", payload=None, headers=None, stream=False):
    # Cloudflare workers.dev Browser Integrity Check rejects Python-urllib default UA (1010).
    # Identify this legitimate CI client; OIDC remains required by the Worker.
    authorization = {"Authorization": "Bearer " + oidc(),
                     "User-Agent": "FieldWork-Release-Publisher/1.0 (+https://github.com/milktea-cus/MCP-FBMN)",
                     "Accept": "application/json"}
    if headers:
        authorization.update(headers)
    if isinstance(payload, dict):
        payload = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        authorization["Content-Type"] = "application/json"
    req = urllib.request.Request(
        BASE + path, data=payload, method=method, headers=authorization,
    )
    response = urllib.request.urlopen(req, timeout=120)
    if stream:
        return response
    with response:
        return json.load(response)


def safe_oidc_claims():
    """Only public workflow identity claims for troubleshooting, never the JWT."""
    token = oidc()
    encoded = token.split(".")[1]
    encoded += "=" * (-len(encoded) % 4)
    claims = json.loads(base64.urlsafe_b64decode(encoded))
    keys = ("iss", "aud", "sub", "repository", "repository_id",
            "actor", "event_name", "ref", "job_workflow_ref")
    return {key: claims.get(key) for key in keys}


def fingerprint(path, password):
    report = subprocess.check_output([
        "keytool", "-list", "-v", "-keystore", str(path),
        "-storepass", password, "-alias", ALIAS,
    ], text=True, stderr=subprocess.STDOUT)
    match = re.search(r"SHA256:\s*([A-Fa-f0-9:]{64,95})", report)
    if not match:
        raise RuntimeError("Signing certificate fingerprint not found")
    digest = match.group(1).replace(":", "").lower()
    if not re.fullmatch("[a-f0-9]{64}", digest):
        raise RuntimeError("Signer SHA-256 invalid")
    return digest


def generate(path):
    password = secrets.token_urlsafe(36)
    subprocess.run([
        "keytool", "-genkeypair", "-noprompt", "-alias", ALIAS,
        "-keyalg", "RSA", "-keysize", "3072", "-validity", "36500",
        "-storetype", "PKCS12", "-keystore", str(path),
        "-storepass", password, "-keypass", password,
        "-dname", "CN=Field Work, OU=FBMN, O=FBMN, C=VN",
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    digest = fingerprint(path, password)
    return {
        "keystoreBase64": base64.b64encode(path.read_bytes()).decode("ascii"),
        "password": password, "alias": ALIAS, "signerSha256": digest,
    }


def signing():
    target = Path(os.environ["RUNNER_TEMP"]) / "field-work-release.jks"
    try:
        config = call("/signing")
        first = False
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            if exc.code == 403:
                print("OIDC rejected; public claim metadata:",
                      json.dumps(safe_oidc_claims(), ensure_ascii=False))
            message = exc.read(200).decode("utf-8", errors="replace")
            raise RuntimeError("Cloudflare signing retrieval failed: HTTP " +
                               str(exc.code) + " response=" + message[:160]) from None
        first = True
        config = generate(target)
        try:
            call("/signing", method="POST", payload=config)
        except urllib.error.HTTPError as post_error:
            raise RuntimeError("Unable to bootstrap signer: HTTP " + str(post_error.code)) from None
        # Re-read encrypted R2 material rather than trusting local first-run state.
        config = call("/signing")
    if config.get("alias") != ALIAS:
        raise RuntimeError("Signer alias mismatch")
    password = config.get("password", "")
    data = base64.b64decode(config["keystoreBase64"], validate=True)
    if len(data) < 1000 or len(data) > 60000:
        raise RuntimeError("Signing keystore size invalid")
    target.write_bytes(data)
    target.chmod(0o600)
    actual = fingerprint(target, password)
    if actual != config.get("signerSha256"):
        raise RuntimeError("Signing certificate does not match encrypted R2 state")
    gh_env = Path(os.environ["GITHUB_ENV"])
    with gh_env.open("a", encoding="utf-8") as env:
        for name, value in [
            ("FIELD_WORK_ANDROID_KEYSTORE_PATH", str(target)),
            ("FIELD_WORK_ANDROID_STORE_PASSWORD", password),
            ("FIELD_WORK_ANDROID_KEY_ALIAS", ALIAS),
            ("FIELD_WORK_ANDROID_KEY_PASSWORD", password),
            ("FIELD_WORK_CERT_SHA256", actual),
        ]:
            if "\n" in value or "\r" in value:
                raise RuntimeError("Invalid signing value")
            env.write(name + "=" + value + "\n")
    # GitHub masks the password in any subsequent job output.
    print("::add-mask::" + password)
    print("Persistent signer " + ("bootstrapped" if first else "restored") +
          " from encrypted private R2; signer SHA-256 pinned.")


def publish(args):
    apk = Path(args.apk)
    if not apk.is_file():
        raise RuntimeError("Signed APK not found")
    size = apk.stat().st_size
    if size < 4096 or size > 100 * 1024 * 1024:
        raise RuntimeError("Signed APK too large for verified Worker upload")
    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    signer = Path(os.environ["RUNNER_TEMP"], "field-work-signer.txt").read_text().strip()
    if signer != os.environ.get("FIELD_WORK_CERT_SHA256"):
        raise RuntimeError("Signed APK certificate differs from persistent release key")
    try:
        call("/artifact/" + str(args.version_code), method="PUT",
             payload=apk.read_bytes(), headers={
                 "Content-Type": "application/vnd.android.package-archive",
                 "X-APK-SHA256": digest,
                 "X-APK-SIGNER-SHA256": signer,
             })
        # Independently read the remote object and hash the exact bytes.
        remote = hashlib.sha256()
        read = 0
        with call("/artifact/" + str(args.version_code), stream=True) as response:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                remote.update(chunk)
                read += len(chunk)
        if read != size or remote.hexdigest() != digest:
            raise RuntimeError("R2 download checksum mismatch: latest pointer unchanged")
        published = call("/promote", method="POST", payload={
            "versionCode": args.version_code, "versionName": args.version_name,
            "size": size, "sha256": digest, "signerSha256": signer,
            "notes": args.notes,
        })
    except urllib.error.HTTPError as exc:
        raise RuntimeError("R2 publication failed: HTTP " + str(exc.code)) from None
    if published.get("published") is not True:
        raise RuntimeError("Release manifest has not been published")
    print("Verified signed APK published to private R2.")
    print("Installer download: " + PUBLIC)
    print("VersionCode:", args.version_code, "SHA-256:", digest)


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_subparsers(dest="mode", required=True)
    mode.add_parser("signing")
    release = mode.add_parser("publish")
    release.add_argument("--apk", required=True)
    release.add_argument("--version-code", type=int, required=True)
    release.add_argument("--version-name", required=True)
    release.add_argument("--notes", required=True)
    args = parser.parse_args()
    if args.mode == "signing":
        signing()
    else:
        publish(args)


if __name__ == "__main__":
    main()
