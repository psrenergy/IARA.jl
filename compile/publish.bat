@echo off

SET BASE_PATH=%~dp0

CALL julia +1.11.7 --project=%BASE_PATH% %BASE_PATH%\publish.jl %*
