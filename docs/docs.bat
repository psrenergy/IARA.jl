@echo off

SET DOCSPATH=%~dp0

julia +1.11.2 --project=%DOCSPATH% %DOCSPATH%\make.jl %*
