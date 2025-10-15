@echo off

SET BASEPATH=%~dp0

CALL "%JULIA_1112%" --project=%BASEPATH% --startup-file=no %BASEPATH%\retrieve_deploy_data.jl %* 2>nul