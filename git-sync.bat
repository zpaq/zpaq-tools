cd /d %~dp0
7z x -y %1
git add *
git status -s
set NewestFileDate=2000/06/07 02:11
for /f "tokens=2 delims= " %%x in ('git status -s') do (
for %%a in (%%x) do (
if "%%~ta" GTR "!NewestFileDate!" ( set NewestFileDate=%%~ta )
)
)
echo %NewestFileDate%
git commit --date="%NewestFileDate%" -m "%1"
del %1
rem 