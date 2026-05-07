@echo off

SET BASEPATH=%~dp0

julia +1.11.2 --project=%BASEPATH% %BASEPATH%\main.jl %*