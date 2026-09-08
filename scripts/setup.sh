#!/bin/bash
#
# Install and configure all dependencies essential for development.

# -x: print a trace (debug)
# -u: treat unset variables
# -o pipefail: return value of a pipeline
set -uo pipefail

# Include Scripts

source "$(dirname "${BASH_SOURCE[0]}")/shell/bootstrap_manager.sh"

# Control Flow Logic

bootstrap_manager_setup
exit "${?}"
