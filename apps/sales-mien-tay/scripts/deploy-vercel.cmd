@echo off
setlocal
REM Production only. Run after backend/auth readiness, CI and UAT.
if not defined VERCEL_TOKEN (echo Set VERCEL_TOKEN in your private environment. & exit /b 1)
if not defined API_BASE_URL (echo Set API_BASE_URL to the verified production HTTPS Worker URL. & exit /b 1)
if not defined VERCEL_CLI_VERSION (echo Set VERCEL_CLI_VERSION to a reviewed exact CLI version. & exit /b 1)
set "VERCEL_ORG_ID=team_8KoQUR2ALt0Mc4eywJoz8wjH"
set "VERCEL_PROJECT_ID=prj_5fNaLxgkk5kYTKXKdY3NOKkFLnXQ"
pushd "%~dp0..\apps\sales_flutter" || exit /b 1
call flutter create --platforms=web,android . || goto :fail
call flutter pub get || goto :fail
call flutter analyze --no-fatal-infos || goto :fail
call flutter test || goto :fail
call flutter build web --release --dart-define=API_BASE_URL=%API_BASE_URL% || goto :fail
copy /Y vercel.json build\web\vercel.json >nul || goto :fail
cd build\web || goto :fail
if not exist .vercel mkdir .vercel
> .vercel\project.json echo {"orgId":"%VERCEL_ORG_ID%","projectId":"%VERCEL_PROJECT_ID%"}
call npx --yes vercel@%VERCEL_CLI_VERSION% deploy --prod --yes || goto :fail
popd
exit /b 0
:fail
popd
exit /b 1
