@echo off

SET BASEPATH=%~dp0

CALL julia +1.12.5 --project=%BASEPATH% --startup-file=no %BASEPATH%\retrieve_deploy_data.jl %* 2>nul