@echo off

@REM Colocar variaveis de ambiente se necessário
SET BASEPATH=%~dp0
SET REVISE_PATH="%BASEPATH%\revise"

SET XPRESS_JL_NO_DEPS_ERROR=1
SET XPRESS_JL_NO_AUTO_INIT=1
SET XPRESS_JL_SKIP_LIB_CHECK=1
SET XPRESS_JL_NO_INFO=1

SET XPRESSDIR=
SET XPAUTH_PATH=


julia --color=yes --project=%REVISE_PATH% --load=%REVISE_PATH%\revise_load_script.jl
