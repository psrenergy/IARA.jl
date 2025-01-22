@echo off

@REM Colocar variaveis de ambiente se necessário
SET FORMATTERPATH=%~dp0

%JULIA_1112% --color=yes --project=%FORMATTERPATH% %FORMATTERPATH%\format.jl
