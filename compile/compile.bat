@echo off

SET BASEPATH=%~dp0

CALL julia +1.11.2 --project=%BASEPATH% %BASEPATH%\compile.jl %*