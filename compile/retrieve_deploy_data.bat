@echo off

SET BASEPATH=%~dp0

CALL "%JULIA_1112%" --project=%BASEPATH% %BASEPATH%\retrieve_deploy_data.jl %*