@echo off

SET DOCSPATH=%~dp0

CALL julia +1.12.5 --project=%DOCSPATH% %DOCSPATH%\make.jl %*
