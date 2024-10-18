@echo off

SET DOCSPATH=%~dp0

CALL "%JULIA_1100%" --project=%DOCSPATH% %DOCSPATH%\make.jl
