#!/usr/bin/env python3
"""Fail-closed immutable APK publishing to private R2; CI signing only.

The release pointer is updated LAST, after independent remote byte verification.
Never feed this script unsigned or debug-signed APKs. No credentials or keystores
are stored or printed; boto3 reads R2 credentials only from CI environment.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path

import boto3
from botocore.exceptions import ClientError

BUCKET = "sales-mien-tay-app-releases"
PACKAGE = "com.example.sales_mien_tay"
MAX_SIZE = 250 * 1024 * 1024


def sha256(data):
    digest = hashlib.sha256()
    if hasattr(data, "read"):
        while True:
            chunk = data.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    else:
        digest.update(data)
    return digest.hexdigest()


def missing(exc):
    return isinstance(exc, ClientError) and exc.response.get("Error", {}).get("Code") in (
        "404", "NoSuchKey", "NotFound"
    )


def fetch_or_none(client, key):
    try:
        result = client.get_object(Bucket=BUCKET, Key=key)
    except ClientError as exc:
        if missing(exc):
            return None
        raise
    return result["Body"].read()


def head_or_none(client, key):
    try:
        return client.head_object(Bucket=BUCKET, Key=key)
    except ClientError as exc:
        if missing(exc):
            return None
        raise


def publish(apk, version_code, version_name, signer, notes):
    account = os.environ["CF_ACCOUNT_ID"].strip()
    if len(account) != 32 or not all(c in "0123456789abcdef" for c in account):
        raise ValueError("R2 Cloudflare account is not configured")
    if not os.environ.get("AWS_ACCESS_KEY_ID") or not os.environ.get("AWS_SECRET_ACCESS_KEY"):
        raise ValueError("R2 publisher credentials are missing")
    if version_code < 2 or version_code > 100_000_000:
        raise ValueError("Invalid versionCode")
    if not version_name or len(version_name) > 48:
        raise ValueError("Invalid release versionName")
    if len(signer) != 64 or not all(c in "0123456789abcdef" for c in signer):
        raise ValueError("Signing certificate fingerprint is missing")
    if len(notes) > 2000:
        raise ValueError("Release notes are too long")
    length = apk.stat().st_size
    if length < 4096 or length > MAX_SIZE:
        raise ValueError("APK size invalid")
    with apk.open("rb") as source:
        digest = sha256(source)

    s3 = boto3.client(
        "s3", endpoint_url=f"https://{account}.r2.cloudflarestorage.com",
        region_name="auto",
    )
    key = f"releases/{version_code}/field-work-{version_code}.apk"
    if head_or_none(s3, key) is not None:
        raise ValueError("Immutable APK version already exists: refusing overwrite")
    previous = fetch_or_none(s3, "releases/latest.json")
    if previous:
        old = json.loads(previous)
        if old.get("packageName") != PACKAGE or int(old.get("versionCode", 0)) >= version_code:
            raise ValueError("New release version must increase monotonically")

    with apk.open("rb") as source:
        s3.put_object(
            Bucket=BUCKET, Key=key, Body=source,
            ContentType="application/vnd.android.package-archive",
            Metadata={"sha256": digest, "signersha256": signer},
        )
    head = head_or_none(s3, key)
    if not head or head["ContentLength"] != length or head.get("Metadata", {}).get("sha256") != digest             or head.get("Metadata", {}).get("signersha256") != signer:
        raise RuntimeError("R2 metadata check failed; latest pointer unchanged")
    remote = s3.get_object(Bucket=BUCKET, Key=key)
    if sha256(remote["Body"]) != digest:
        raise RuntimeError("Downloaded R2 APK checksum differs; latest pointer unchanged")

    manifest = {
        "schema": 1,
        "packageName": PACKAGE,
        "versionCode": version_code,
        "versionName": version_name,
        "size": length,
        "sha256": digest,
        "signerSha256": signer,
        "objectKey": key,
        "notes": notes,
        "releasedAt": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
    }
    payload = json.dumps(manifest, ensure_ascii=False, separators=(",", ":")).encode("utf-8")

    if previous:
        history = f"releases/history/before-{version_code}.json"
        existing = fetch_or_none(s3, history)
        if existing is not None and existing != previous:
            raise ValueError("Existing rollback history differs; cannot publish")
        if existing is None:
            s3.put_object(Bucket=BUCKET, Key=history, Body=previous,
                          ContentType="application/json")
            if fetch_or_none(s3, history) != previous:
                raise RuntimeError("Rollback snapshot verification failed")
    # A single PUT of a small JSON object is atomic; no latest pointer changes
    # until the immutable APK and the previous manifest snapshot are verified.
    s3.put_object(Bucket=BUCKET, Key="releases/latest.json", Body=payload,
                  ContentType="application/json", CacheControl="no-store")
    confirmed = fetch_or_none(s3, "releases/latest.json")
    if confirmed != payload:
        if previous is not None:
            s3.put_object(Bucket=BUCKET, Key="releases/latest.json", Body=previous,
                          ContentType="application/json", CacheControl="no-store")
        raise RuntimeError("Latest manifest read-back failed")
    print(f"PUBLISHED: {PACKAGE} v{version_name} code={version_code} "
          f"size={length} sha256={digest} signer={signer} (R2 private)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", required=True, type=Path)
    parser.add_argument("--version-code", required=True, type=int)
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--signer-sha256", required=True)
    parser.add_argument("--notes", default="")
    args = parser.parse_args()
    publish(args.apk, args.version_code, args.version_name,
            args.signer_sha256.lower().replace(":", ""), args.notes)
