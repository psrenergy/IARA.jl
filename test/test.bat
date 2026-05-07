@echo off

SET BASEPATH=%~dp0

julia +1.11.2 --color=yes --project=%BASEPATH%\.. -e "import Pkg; Pkg.Registry.update(); Pkg.test()"