@echo off

REM Verificar se esta rodando como administrador
net session >nul 2>&1
if %errorlevel% == 0 (
    echo.
    echo =====================================================
    echo  ERRO: Este script nao deve ser executado como Administrador!
    echo  Por favor, execute-o sem privilegios elevados.
    echo =====================================================
    echo.
    pause
    exit /b 1
)

perl src\Poseidon\poseidon.pl
pause
