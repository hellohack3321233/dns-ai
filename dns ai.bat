@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title ИИ + DNS + hosts

:: ================== НАСТРОЙКИ ==================
set "AI_LIST=Gemini,ChatGPT,Claude,Grok,Deepl"
set "DNS_LIST=Google:dns.google,Cloudflare:1.1.1.1,Quad9:dns.quad9.net,OpenDNS:208.67.222.222,Comss:router.comss.one,Malw:dns.malw.link"

set "DOMAINS_Gemini=gemini.google.com accounts.google.com www.google.com"
set "DOMAINS_ChatGPT=chatgpt.com auth.openai.com openai.com"
set "DOMAINS_Claude=claude.ai anthropic.com"
set "DOMAINS_Grok=grok.com x.ai"
set "DOMAINS_Deepl=deepl.com"
:: ================================================

net session >nul 2>&1
if %errorlevel% neq 0 (set "NO_ADMIN=1") else (set "NO_ADMIN=0")

:: ============ ГЛАВНОЕ МЕНЮ ============
:main
cls
if "!NO_ADMIN!"=="1" echo [ВНИМАНИЕ] Нет прав админа — DNS/hosts могут не примениться.& echo.
echo ==========================================
echo          Выберите ИИ-агента
echo ==========================================
set "IDX=0"
for %%A in (!AI_LIST!) do (
    set /a "IDX+=1"
    echo   [!IDX!] %%A
)
echo   [0] Выход
if "!NO_ADMIN!"=="1" echo   [A] Перезапустить от администратора
echo ==========================================
set /p "PICK=Введите цифру: "
if /i "!PICK!"=="A" (
    if "!NO_ADMIN!"=="1" goto elevate
    goto main
)
if "!PICK!"=="0" goto quit
set "IDX=0"
for %%A in (!AI_LIST!) do (
    set /a "IDX+=1"
    if "!IDX!"=="!PICK!" (
        set "AI_NAME=%%A"
        goto menu_dns
    )
)
goto main

:: ============ ПЕРЕЗАПУСК ОТ АДМИНА ============
:elevate
cls
echo Запрашиваю права администратора...
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
if !errorlevel! neq 0 (
    echo [ОШИБКА] Не удалось получить права. Нажми любую клавишу.
    pause >nul
    goto main
)
echo Старое окно закроется.
timeout /t 1 >nul
exit /b 0

:: ============ МЕНЮ DNS ============
:menu_dns
cls
echo ==========================================
echo    Выбран ИИ: !AI_NAME!
echo ==========================================
echo          Выберите DNS-сервер
echo ==========================================
set "IDX=0"
for %%D in (!DNS_LIST!) do (
    set /a "IDX+=1"
    for /f "tokens=1 delims=:" %%a in ("%%D") do echo   [!IDX!] %%a
)
echo   [0] Назад
echo ==========================================
set /p "PICK=Введите цифру: "
if "!PICK!"=="0" goto main
set "IDX=0"
for %%D in (!DNS_LIST!) do (
    set /a "IDX+=1"
    if "!IDX!"=="!PICK!" (
        for /f "tokens=1,2 delims=:" %%a in ("%%D") do (
            set "DNS_NAME=%%a"
            set "DNS_DOMAIN=%%b"
        )
        goto process
    )
)
goto menu_dns

:: ============ ОБРАБОТКА ============
:process
set "DNS_DOMAIN=!DNS_DOMAIN: =!"
cls
echo ==========================================
echo  ИИ : !AI_NAME!
echo  DNS: !DNS_NAME! (!DNS_DOMAIN!)
echo ==========================================
echo.

set "ADAPTERS=Wi-Fi Ethernet"
for %%A in (%ADAPTERS%) do (
    netsh interface show interface name="%%A" >nul 2>&1
    if !errorlevel! equ 0 (
        echo DNS для "%%A"...
        netsh interface ip set dns name="%%A" static !DNS_DOMAIN! >nul 2>&1
    )
)
ipconfig /flushdns >nul 2>&1
echo.

echo ==========================================
echo  nslookup через !DNS_DOMAIN!
echo ==========================================
echo.

set "KEY=DOMAINS_!AI_NAME!"
set "OUT=%TEMP%\ai_%RANDOM%.txt"
if exist "!OUT!" del "!OUT!" >nul 2>&1
echo # === !AI_NAME! (DNS: !DNS_NAME! / !DNS_DOMAIN!) ===> "!OUT!"

for %%D in (!%KEY%!) do (
    set "NSL=%TEMP%\n_%RANDOM%.txt"
    nslookup %%D !DNS_DOMAIN! > "!NSL!" 2>&1
    set "GOT="
    for /f "usebackq tokens=*" %%L in ("!NSL!") do (
        set "LN=%%L"
        echo !LN! | findstr /r /c:"Address:[ ]*[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul
        if !errorlevel! equ 0 (
            for /f "tokens=2 delims=:" %%P in ("!LN!") do (
                set "TIP=%%P"
                set "TIP=!TIP: =!"
                for /f "tokens=1 delims=	 " %%Q in ("!TIP!") do set "TIP=%%Q"
                if not "!TIP!"=="!DNS_DOMAIN!" (
                    echo !SEEN! | findstr /c:" !TIP! " >nul
                    if !errorlevel! neq 0 (
                        set "SEEN=!SEEN! !TIP! "
                        echo !TIP!    %%D>> "!OUT!"
                        echo   [OK] !TIP!  -  %%D
                        set "GOT=1"
                    )
                )
            )
        )
    )
    if not defined GOT echo   [FAIL] %%D
    del "!NSL!" >nul 2>&1
)

echo # === конец !AI_NAME! ===>> "!OUT!"
echo.
echo ==========================================
echo  Результат
echo ==========================================
type "!OUT!"
echo.

set /p "W=Записать в hosts? (Y/N): "
if /i "!W!"=="Y" (
    set "H=%SystemRoot%\System32\drivers\etc\hosts"
    if exist "!H!" (
        if not exist "!H!.bak" copy "!H!" "!H!.bak" >nul
        :: пустая строка-разделитель + блок
        echo.>> "!H!"
        type "!OUT!" >> "!H!"
        echo [Готово] записано.
    ) else echo [ОШИБКА] hosts не найден.
) else echo [Пропущено].
del "!OUT!" >nul 2>&1

echo.
echo  [1] В меню    [2] Выход
set /p "W=Введите цифру: "
if "!W!"=="2" goto quit
goto main

:: ============ ВЫХОД ============
:quit
echo.
echo Выход. Закроется по крестику или любой клавише.
pause >nul
endlocal