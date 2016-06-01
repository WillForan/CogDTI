#!/usr/bin/env bash
set -e
cd $(dirname $0)

. funcs_src.bash

processDTI $@
exit 0
