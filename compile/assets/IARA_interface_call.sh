#!/bin/bash

BASEPATH=$(dirname "$0")

unset JULIA_HOME
unset JULIA_BINDIR

"$BASEPATH/IARA_interface_call" $@