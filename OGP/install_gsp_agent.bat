@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM  install_gsp_agent.bat
REM  - Installs Cygwin locally (under this folder)
REM  - Installs Pure-FTPd (TLS), OpenSSH (sshd), Apache (httpd)
REM  - Fetches GSP agent bundle and configures the agent
REM  - Registers services and firewall rules
REM ============================================================

::-------------------------
:: 0) Admin check
::-------------------------
net session >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
  echo [ERROR] Please run this script as Administrator.
  pause
  exit /b 1
)

::-------------------------
:: 1) Paths & settings
::-------------------------
set "WD=%~dp0"
pushd "%WD%"
set "WD=%WD:~0,-1%"
set "SETUP_EXE=%TEMP%\setup-x86_64.exe"
set "CYG_CACHE=%WD%\cygTemp"
set "MIRROR=https://mirrors.kernel.org/sourceware/cygwin/"

:: Passive FTP port range (adjust if needed)
set "FTP_PASV_FIRST=50000"
set "FTP_PASV_LAST=50100"

:: Package list (add/remove as needed)
set "PKGS=bash,coreutils,ca-certificates,curl,wget,tar,unzip,zip,gzip,bzip2,dos2unix,nano,git,subversion,rsync,screen,procps-ng,perl,perl-HTTP-Daemon,perl-Path-Class,perl-XML-Parser,perl-Archive-Zip,perl-XML-Simple,perl-Archive-Extract,perl-DBI,libmariadb3,openssh,cygrunsrv,pure-ftpd,openssl,httpd"

:: GSP Agent release ZIP
set "GSP_URL=https://github.com/GameServerPanel/GSP-Agent-Windows/releases/download/stable_release/GSP_Stable.zip"
set "GSP_ZIP=%WD%\GSP_Stable.zip"
set "GSP_TMP=%WD%\gsp_unpack"

:: Cygwin env for this session (before system integration)
set CYGWIN=server ntsec
set PATH=%WD%\bin;%WD%\usr\sbin;%PATH%
set SHELL=/bin/bash

echo.
echo === GSP Agent / Cygwin bootstrap starting ===

::-------------------------
:: 2) Prompt for / ensure cyg_server account
::-------------------------
set "CYGUSR=cyg_server"
for /f "tokens=1,*" %%A in ('wmic os get Caption ^| findstr /r /v "^$"') do set "OSNAME=%%A %%B" >nul 2>&1

REM Check existence
NET USER | FINDSTR /I "\<%CYGUSR%\>" >nul
if errorlevel 1 (
  echo.
  echo [%CYGUSR%] account not found. It will be created as a local admin.
)

echo.
set /p PASS=Enter password to set for user '%CYGUSR%': 

NET USER | FINDSTR /I "\<%CYGUSR%\>" >nul
if errorlevel 1 (
  net user %CYGUSR% "%PASS%" /add
  net localgroup Administrators %CYGUSR% /add
) else (
  REM Ensure password is updated to what we just entered
  net user %CYGUSR% "%PASS%"
  net localgroup Administrators %CYGUSR% /add
)

REM Quick credential check via a throwaway scheduled task
schtasks /Create /RU "%CYGUSR%" /SC ONCE /ST 00:00 /TN "cygsvr_test" /TR "cmd.exe /c exit 0" /F /RL HIGHEST /RP "%PASS%" >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
  echo [ERROR] Could not validate credentials for %CYGUSR%. Re-run and check the password.
  exit /b 1
) else (
  schtasks /Delete /TN "cygsvr_test" /F >nul 2>&1
)

::-------------------------
:: 3) Download and install Cygwin (quiet)
::-------------------------
echo.
echo [+] Downloading Cygwin setup from cygwin.com ...
powershell -NoP -NonI -Command ^
  "Invoke-WebRequest 'https://www.cygwin.com/setup-x86_64.exe' -OutFile '%SETUP_EXE%'"

if not exist "%SETUP_EXE%" (
  echo [ERROR] Could not download setup-x86_64.exe
  exit /b 1
)

echo.
echo [+] Installing Cygwin to %WD% ...
if not exist "%CYG_CACHE%" mkdir "%CYG_CACHE%" >nul 2>&1

start /wait "" "%SETUP_EXE%" ^
  --quiet-mode ^
  --root "%WD%" ^
  --local-package-dir "%CYG_CACHE%" ^
  --no-shortcuts --no-startmenu --no-desktop ^
  --site "%MIRROR%" ^
  --packages "%PKGS%"

IF %ERRORLEVEL% NEQ 0 (
  echo [ERROR] Cygwin setup failed. Check %WD%\Cygwin64_Agent_Setup.log if present.
  exit /b 1
)

:: Ensure this session sees the new Cygwin first
set PATH=%WD%\bin;%WD%\usr\sbin;%PATH%

::-------------------------
:: 4) Fetch GSP agent bundle
::-------------------------
echo.
echo [+] Downloading GSP agent bundle ...
powershell -NoP -NonI -Command ^
  "Invoke-WebRequest '%GSP_URL%' -OutFile '%GSP_ZIP%'"

if not exist "%GSP_ZIP%" (
  echo [ERROR] Could not download GSP_Stable.zip
  exit /b 1
)

echo [+] Unpacking GSP agent bundle ...
if exist "%GSP_TMP%" rmdir /S /Q "%GSP_TMP%" >nul 2>&1
powershell -NoP -NonI -Command ^
  "Expand-Archive -LiteralPath '%GSP_ZIP%' -DestinationPath '%GSP_TMP%' -Force"

xcopy /E /I /Y "%GSP_TMP%\*" "%WD%\" >nul

:: Copy resource monitoring files to their proper locations
if exist "%~dp0Cfg\Config.pm" (
    echo [+] Installing resource monitoring configuration...
    if not exist "%WD%\OGP\Cfg" mkdir "%WD%\OGP\Cfg" >nul 2>&1
    copy /Y "%~dp0Cfg\Config.pm" "%WD%\OGP\Cfg\Config.pm" >nul
)

if exist "%~dp0DB" (
    echo [+] Installing database schema files...
    if not exist "%WD%\OGP\DB" mkdir "%WD%\OGP\DB" >nul 2>&1
    xcopy /E /I /Y "%~dp0DB\*" "%WD%\OGP\DB\" >nul
)

:: Cleanup bundle
del /q "%GSP_ZIP%" >nul 2>&1
rmdir /S /Q "%GSP_TMP%" >nul 2>&1

::-------------------------
:: 5) Configure and register services inside Cygwin
::-------------------------
echo.
echo [+] Configuring services (sshd, pure-ftpd, httpd) and GSP agent ...

REM --- Make agent scripts executable and run configurator ---
if exist "%WD%\bin\bash.exe" (
  "%WD%\bin\bash.exe" -lc "chmod +x /OGP/agent_conf.sh /bin/ogp_agent 2>/dev/null || true"
  "%WD%\bin\bash.exe" -lc "bash /OGP/agent_conf.sh -p '%PASS%'" 
) else (
  echo [ERROR] bash.exe not found under %WD%\bin
  exit /b 1
)

REM --- OpenSSH (sshd) ---
"%WD%\bin\bash.exe" -lc "/usr/bin/ssh-host-config -y -w '%PASS%' -c ntsec"
"%WD%\bin\bash.exe" -lc "cygrunsrv --start sshd || true"

REM --- Pure-FTPd TLS: generate self-signed cert + PureDB (empty) ---
"%WD%\bin\bash.exe" -lc ^
  "mkdir -p /etc/pure-ftpd; \
   openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
     -subj '/C=US/ST=NA/L=NA/O=GSP/OU=OGP/CN='\"$(hostname)\" \
     -keyout /etc/pure-ftpd/pure-ftpd.key -out /etc/pure-ftpd/pure-ftpd.crt; \
   cat /etc/pure-ftpd/pure-ftpd.key /etc/pure-ftpd/pure-ftpd.crt > /etc/pure-ftpd/pure-ftpd.pem; \
   chmod 600 /etc/pure-ftpd/pure-ftpd.pem; \
   touch /etc/pureftpd.passwd; \
   pure-pw mkdb /etc/pureftpd.pdb -f /etc/pureftpd.passwd"

REM --- Register Pure-FTPd service (TLS required, passive port range, PureDB auth) ---
"%WD%\bin\bash.exe" -lc ^
  "cygrunsrv --remove pure-ftpd 2>/dev/null || true; \
   cygrunsrv --install pure-ftpd \
     -p /usr/sbin/pure-ftpd.exe \
     -a \"--tls=2 --daemonize --maxclientsnumber 50 --passiveportrange %FTP_PASV_FIRST%:%FTP_PASV_LAST% --login=puredb:/etc/pureftpd.pdb\" \
     -d \"Pure-FTPd (TLS)\"; \
   cygrunsrv --start pure-ftpd || true"

REM --- Apache httpd ---
"%WD%\bin\bash.exe" -lc ^
  "if [ -f /etc/httpd/conf/httpd.conf ]; then \
      grep -q '^ServerName ' /etc/httpd/conf/httpd.conf || echo 'ServerName localhost:80' >> /etc/httpd/conf/httpd.conf; \
      sed -i 's/^#ServerName .*/ServerName localhost:80/' /etc/httpd/conf/httpd.conf 2>/dev/null || true; \
   fi; \
   cygrunsrv --remove httpd 2>/dev/null || true; \
   cygrunsrv --install httpd -p /usr/sbin/httpd.exe -a '-DFOREGROUND' -d 'Apache HTTP Server (Cygwin)'; \
   cygrunsrv --start httpd || true"

::-------------------------
:: 6) Windows Firewall rules
::-------------------------
echo.
echo [+] Adding Windows Firewall rules ...
netsh advfirewall firewall add rule name="Cygwin OpenSSH (TCP/22)" dir=in action=allow protocol=TCP localport=22 >nul
netsh advfirewall firewall add rule name="Cygwin Pure-FTPd Control (TCP/21)" dir=in action=allow protocol=TCP localport=21 >nul
netsh advfirewall firewall add rule name="Cygwin Pure-FTPd Passive (TCP/%FTP_PASV_FIRST%-%FTP_PASV_LAST%)" dir=in action=allow protocol=TCP localport=%FTP_PASV_FIRST%-%FTP_PASV_LAST% >nul
netsh advfirewall firewall add rule name="Cygwin Apache (TCP/80)" dir=in action=allow protocol=TCP localport=80 >nul

::-------------------------
:: 7) Rebase (optional) and schedule OGP agent at boot
::-------------------------
if exist "%WD%\rebase_post_ins.bat" (
  call "%WD%\rebase_post_ins.bat"
)

echo.
echo [+] Creating Scheduled Task: "OGP agent start on boot"
schtasks /delete /tn "OGP agent start on boot" /f >nul 2>&1
schtasks /create /tn "OGP agent start on boot" /sc ONSTART /ru "%CYGUSR%" /rp "%PASS%" /rl HIGHEST /tr "\"%WD%\agent_start.bat\""

echo [+] Starting OGP agent now...
schtasks /Run /TN "OGP agent start on boot" >nul 2>&1

echo.
echo ============================================================
echo   Done.
echo   - Cygwin root: %WD%
echo   - Services: sshd, pure-ftpd, httpd  (registered via cygrunsrv)
echo   - OGP agent: scheduled to start at boot as %CYGUSR%
echo   - FTP TLS cert: /etc/pure-ftpd/pure-ftpd.pem  (self-signed)
echo   - Passive FTP range: %FTP_PASV_FIRST%-%FTP_PASV_LAST%
echo   - Open ports: 22, 21, %FTP_PASV_FIRST%-%FTP_PASV_LAST%, 80
echo ============================================================
pause
exit /b 0
