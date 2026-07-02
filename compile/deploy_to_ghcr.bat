@echo off

SET BASEPATH=%~dp0

CALL julia +1.11.2 --project=%BASEPATH% --startup-file=no %BASEPATH%\deploy_to_ghcr.jl