@echo off

SET BASEPATH=%~dp0

CALL julia +1.12.5 --color=yes --project=%BASEPATH%\.. -e "import Pkg; Pkg.Registry.update(); Pkg.test()"