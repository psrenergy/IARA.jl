@echo off

SET BASEPATH=%~dp0

CALL "%JULIA_1100%" --color=yes --project=%BASEPATH%\.. -e "import Pkg; Pkg.Registry.update(); Pkg.test()"