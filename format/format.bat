@echo off

@REM Colocar variaveis de ambiente se necessário
SET FORMATTERPATH=%~dp0

CALL julia +1.12.5 --color=yes --project=%FORMATTERPATH% %FORMATTERPATH%\format.jl
