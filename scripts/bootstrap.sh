#!/bin/bash
#
# Initialize a software development workspace with requisites.

# -x: print a trace (debug)
# -u: treat unset variables
# -o pipefail: return value of a pipeline
set -uo pipefail

# Include Scripts

source "$(dirname "${BASH_SOURCE[0]}")/shell/bootstrap_manager.sh"

# Control Flow Logic

bootstrap_manager_bootstrap
exit "${?}"
