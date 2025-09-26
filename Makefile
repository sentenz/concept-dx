# SPDX-License-Identifier: Apache-2.0

ifneq (,$(wildcard .env))
	include .env
	export
endif

# Define Variables

IS_WINDOWS := $(findstring Windows_NT,$(OS))
POWERSHELL := powershell

ifeq ($(IS_WINDOWS),Windows_NT)
	PIP_VENV := .venv/Scripts
else
	PIP_VENV := .venv/bin
endif

SHELL := bash
.SHELLFLAGS := -euo pipefail -c
.ONESHELL:

# Define Targets

default: help

# NOTE Targets MUST have a leading comment line starting with `##` to be included in the list. See the targets below for examples.
help:
ifeq ($(IS_WINDOWS),Windows_NT)
	@echo "TODO Implement Windows help script"
else
	@awk 'BEGIN {printf "Tasks\n\tA collection of tasks used in the current project.\n\n"}'
	@awk 'BEGIN {printf "Usage\n\tmake $(shell tput -Txterm setaf 6)<task>$(shell tput -Txterm sgr0)\n\n"}' $(MAKEFILE_LIST)
	@awk '/^##/{c=substr($$0,3);next}c&&/^[[:alpha:]][[:alnum:]_-]+:/{print "$(shell tput -Txterm setaf 6)\t" substr($$1,1,index($$1,":")) "$(shell tput -Txterm sgr0)",c}1{c=0}' $(MAKEFILE_LIST) | column -s: -t
endif
.PHONY: help

# ── Setup & Teardown ─────────────────────────────────────────────────────────────────────────────

# Prompt for credentials and cache them for the current session
permission:
ifeq ($(IS_WINDOWS),Windows_NT)
	@echo "TODO Implement Windows permissions handling"
else
	@sudo -v
endif
.PHONY: permission

## Initialize a software development workspace with requisites
bootstrap:
ifeq ($(IS_WINDOWS),Windows_NT)
	$(POWERSHELL) -File ./scripts/Bootstrap.ps1
else
	@$(MAKE) -s permission; \
	cd scripts/ && chmod +x bootstrap.sh && ./bootstrap.sh
endif
.PHONY: bootstrap

## Install and configure all dependencies essential for development
setup:
ifeq ($(IS_WINDOWS),Windows_NT)
	@echo "TODO Implement Windows setup task"
else
	@$(MAKE) -s permission; \
	cd scripts/ && chmod +x setup.sh && ./setup.sh
endif
.PHONY: setup

## Remove development artifacts and restore the host to its pre-setup state
teardown:
ifeq ($(IS_WINDOWS),Windows_NT)
	@echo "TODO Implement Windows teardown task"
else
	@$(MAKE) -s permission; \
	cd scripts/ && chmod +x teardown.sh && ./teardown.sh
endif
.PHONY: teardown

# TODO Migrate to Setup.ps1
## Install the PSScriptAnalyzer PowerShell module on a Windows system
install-pwsh-analyzer:
ifeq ($(IS_WINDOWS),Windows_NT)
	$(POWERSHELL) -Command "Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber"
else
	@echo "TODO Implement Linux install-pwsh-analyzer task"
endif
.PHONY: install-pwsh-analyzer

# TODO Migrate to Setup.ps1
## Use PSScriptAnalyzer to lint PowerShell scripts and modules on Windows
lint-pwsh-analyze:
ifeq ($(IS_WINDOWS),Windows_NT)
	$(POWERSHELL) -Command "Invoke-ScriptAnalyzer -Path $(@D) -Recurse -Severity Warning,Error | Out-String"
else
	@echo "TODO Implement Linux lint-pwsh-analyze task"
endif
.PHONY: lint-pwsh-analyze

# ── Secret Manager ───────────────────────────────────────────────────────────────────────────────

SOPS_UID ?= sops-dx

# Usage: make secret-gpg-generate SOPS_UID=<uid>
#
## Generate a new GPG key pair for SOPS
secret-gpg-generate:
	@gpg --batch --quiet --passphrase '' --quick-generate-key "$(SOPS_UID)" ed25519 cert,sign 0
	@NEW_FPR="$$(gpg --list-keys --with-colons "$(SOPS_UID)" | awk -F: '/^fpr:/ {print $$10; exit}')"
	@gpg --batch --quiet --passphrase '' --quick-add-key "$${NEW_FPR}" cv25519 encrypt 0
.PHONY: secret-gpg-generate

# Usage: make secret-gpg-show SOPS_UID=<uid>
#
## Print the GPG key fingerprint for SOPS (.sops.yaml)
secret-gpg-show:
	@FPR="$$(gpg --list-keys --with-colons "$(SOPS_UID)" | awk -F: '/^fpr:/ {print $$10; exit}')"; \
	if [ -z "$${FPR}" ]; then \
		echo "error: no fingerprint found for UID '$(SOPS_UID)'" >&2; \
		exit 1; \
	fi; \
	echo -e "UID: $(SOPS_UID)\nFingerprint: $${FPR}"
.PHONY: secret-gpg-show

# Usage: make secret-gpg-remove SOPS_UID=<uid>
#
## Remove an existing GPG key for SOPS (interactive)
secret-gpg-remove:
	if ! gpg --list-keys "$(SOPS_UID)" >/dev/null 2>&1; then
		echo "warning: no key found for '$(SOPS_UID)'" >&2
		exit 0
	fi
	echo "info: deleting key for '$(SOPS_UID)'"
	# Delete private key first, then public key
	gpg --yes --delete-secret-keys "$(SOPS_UID)"
	gpg --yes --delete-keys "$(SOPS_UID)"
.PHONY: secret-gpg-remove

# Usage: make secret-sops-encrypt <files>
#
## Encrypt file using SOPS
secret-sops-encrypt:
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "usage: make secret-sops-encrypt <files>"; \
		exit 1; \
	fi

	export PATH="$$PATH:$(shell go env GOPATH 2>/dev/null)/bin"
	@for file in $(filter-out $@,$(MAKECMDGOALS)); do \
		if [ -f "$$file" ]; then \
			sops --encrypt --in-place "$$file"; \
		else \
			echo "Skipping (not found): $$file" >&2; \
		fi; \
	done
.PHONY: secret-sops-encrypt

# Usage: make secret-sops-decrypt <files>
#
## Decrypt file using SOPS
secret-sops-decrypt:
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "usage: make secret-sops-encrypt <files>"; \
		exit 1; \
	fi

	export PATH="$$PATH:$(shell go env GOPATH 2>/dev/null)/bin"
	@for file in $(filter-out $@,$(MAKECMDGOALS)); do \
		if [ -f "$$file" ]; then \
			sops --decrypt --in-place "$$file"; \
		else \
			echo "Skipping (not found): $$file" >&2; \
		fi; \
	done
.PHONY: secret-sops-decrypt

# Usage: make secret-sops-view <file>
#
## View a file encrypted with SOPS
secret-sops-view:
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "usage: make secret-sops-view <file>"; \
		exit 1; \
	fi

	export PATH="$$PATH:$(shell go env GOPATH 2>/dev/null)/bin"
	sops --decrypt "$(filter-out $@,$(MAKECMDGOALS))"
.PHONY: secret-sops-view
