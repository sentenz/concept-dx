#!/bin/bash
#
# Bootstrap Manager for the shell scripts based bootstrap, setup and teardown workflow.

source "$(dirname "${BASH_SOURCE[0]}")/pkg.sh"

# Package Definitions

readonly -A BOOTSTRAP_MANAGER_APT_PACKAGES=(
  ["make"]=""
  ["git"]=""
  ["jq"]=""
  ["bash"]=""
  ["ca-certificates"]=""
  ["go"]=""
)

readonly -A BOOTSTRAP_MANAGER_NPM_PACKAGES=(
  ["skills"]="1.5.1"
)

readonly -A SETUP_MANAGER_GO_PACKAGES=(
  ["go.mozilla.org/sops/cmd/sops"]="3.4.0"
)

readonly -A SETUP_MANAGER_NPM_PACKAGES=(
  ["lefthook"]="2.1.6"
)

readonly -A TEARDOWN_MANAGER_NPM_PACKAGES=(
  ["lefthook"]=""
)

readonly -A TEARDOWN_MANAGER_GO_PACKAGES=(
  ["go.mozilla.org/sops/cmd/sops"]=""
)

# Control Flow Logic

# Initialize a software development workspace with requisites.
#
# Arguments:
#   None
# Returns:
#   $? - 0 on success, non-zero on failure
function bootstrap_manager_bootstrap() {
  local -i retval=0

  pkg_apt_install_list BOOTSTRAP_MANAGER_APT_PACKAGES
  ((retval |= $?))

  pkg_apt_clean
  ((retval |= $?))

  pkg_npm_install_list BOOTSTRAP_MANAGER_NPM_PACKAGES
  ((retval |= $?))

  pkg_npm_clean
  ((retval |= $?))

  return "${retval}"
}

# Install and configure all dependencies essential for development.
#
# Arguments:
#   None
# Returns:
#   $? - 0 on success, non-zero on failure
function bootstrap_manager_setup() {
  local -i retval=0

  pkg_go_install_list SETUP_MANAGER_GO_PACKAGES
  ((retval |= $?))

  pkg_go_clean
  ((retval |= $?))

  pkg_npm_install_list SETUP_MANAGER_NPM_PACKAGES
  ((retval |= $?))

  pkg_npm_clean
  ((retval |= $?))

  return "${retval}"
}

# Remove development artifacts and restore the host to its pre-setup state.
#
# Arguments:
#   None
# Returns:
#   $? - 0 on success, non-zero on failure
function bootstrap_manager_teardown() {
  # NOTE Use reversed order of bootstrap_manager_bootstrap and bootstrap_manager_setup for tearing down

  local -i retval=0

  pkg_npm_uninstall_list TEARDOWN_MANAGER_NPM_PACKAGES
  ((retval |= $?))

  pkg_npm_clean
  ((retval |= $?))

  pkg_go_uninstall_list TEARDOWN_MANAGER_GO_PACKAGES
  ((retval |= $?))

  pkg_go_clean
  ((retval |= $?))

  pkg_apt_uninstall_list BOOTSTRAP_MANAGER_APT_PACKAGES
  ((retval |= $?))

  pkg_apt_clean
  ((retval |= $?))

  return "${retval}"
}
