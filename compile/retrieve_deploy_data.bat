@echo off

SET BASEPATH=%~dp0

CALL julia +1.11.2 --project=%BASEPATH% --startup-file=no %BASEPATH%\retrieve_deploy_data.jl %* 2>nul