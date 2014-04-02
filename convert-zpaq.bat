cd /d %~dp0
set CWD=%CD%
echo %CWD:~0,6%
pushd zpaq
git reset --hard 1bee6c5eb5a29d62ce0ea32b044787752fccfd20
popd

pause
Setlocal EnableDelayedExpansion
for %%i in (zpaq001 zpaq002 zpaq003 zpaq004 zpaq006
zpaq007 zpaq008 zpaq009 zpaq100 unzpaq1 fast
unzpaq101 unzpaq102 zpaq102 unzpaq103 zpaq103a zpaq103b
zpaq104 zpaq105 unzpaq106 zpaq106 zpaqsfx106
zpipe100
zpaq107 bwt_j2 bwt_j3 exe_j1
unzpaq108 zpaq108 bmp_j4 bwt_slowmode1 jpg_test2 zpaq109 zpaq110
zp110 libzpaq001 libzpaq002
zpipe200
libzpaq100 libzpaq101 libzpaq102
libzpaq200 libzpaq201 libzpaq202
zpaq.203 libzpaq.202 zpipe.201 zpsfx.100 min mid max
zpaq.204
zpaq.205
libzpaq.202a
pzpaq.001
pzpaq.002
pzpaq.003
pzpaq.004
pzpaq.005
bwt.1
unzp.100
zp.101
zp.102
zp.103
wbpe100
wbpe110
zpaq300
zpaq301
bmp_j4a
libzpaq300
libzpaq400
zpaq400
zpaq401
zpaq402
libzpaq401
zpaq403
lz1
unzpaq200
libzpaq500
libzpaq501
tiny_unzpaq
zpaq404
zpsfx101
zpaq500
zpaq600
zpaq601
zpaq602
zpaq603
zpaq604
bmp_j4b
zpaq605
zpaq606
zpaq607
lazy100
lazy210
zpaq616
) do (
set NAME=%%i

if exist "down\%%i.zip" (
set FILE_EXT=zip
unzip -o down\%%i.zip -d zpaq\

if "!NAME!" NEQ "zpaq103b" (
if "!NAME:~0,6!" EQU "zpaq10" (
pushd zpaq
git rm zpaq10*.cpp
git rm --ignore-unmatch zpaq.cpp
popd
)
)

)

if exist "down\%%i.cpp" (
set FILE_EXT=cpp
pushd zpaq
if "!NAME:~0,6!" EQU "unzpaq" (
git rm unzpaq*.cpp
) else (
if "!NAME:~0,5!" EQU "zpsfx" (
git rm zpsfx*.cpp
) else  (
git rm tiny_unzpaq.cpp
)
)
popd
copy /Y down\%%i.cpp zpaq\
)
if exist "down\%%i.cfg" (
set FILE_EXT=cfg
copy /Y down\%%i.cfg zpaq\
)
pushd zpaq
git add -u
git add *
git commit -m "%%i.!FILE_EXT!"
popd
)


pause