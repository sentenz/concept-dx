#!/bin/bash
#
# Remove development artifacts and restore the host to its pre-setup state.

# -x: print a trace (debug)
# -u: treat unset variables
# -o pipefail: return value of a pipeline
set -uo pipefail

# Include Scripts

source "$(dirname "${BASH_SOURCE[0]}")/shell/bootstrap_manager.sh"

# Control Flow Logic

bootstrap_manager_teardown
exit "${?}"
