@echo off

@REM Colocar variaveis de ambiente se necessário
SET FORMATTERPATH=%~dp0

julia +1.11.2 --color=yes --project=%FORMATTERPATH% %FORMATTERPATH%\format.jl
