@echo off

SET DOCSPATH=%~dp0

CALL "%JULIA_1112%" --project=%DOCSPATH% %DOCSPATH%\make.jl
