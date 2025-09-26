# DX Concept

Developer Experience (DX) encompasses the practices, tools, and workflows that streamline software development, ensuring consistency, automation, and maintainability across environments and teams.

- [1. Details](#1-details)
  - [1.1. Prerequisites](#11-prerequisites)
- [2. Usage](#2-usage)
  - [2.1. Bootstrap](#21-bootstrap)
  - [2.2. Dev Containers](#22-dev-containers)
  - [2.3. Task Runner](#23-task-runner)
    - [2.3.1. Makefile](#231-makefile)
  - [2.4. Release Manager](#24-release-manager)
    - [2.4.1. Semantic-Release](#241-semantic-release)
  - [2.5. Dependency Manager](#25-dependency-manager)
    - [2.5.1. Renovate](#251-renovate)
  - [2.6. Secret Manager](#26-secret-manager)
    - [2.6.1. SOPS](#261-sops)
- [3. Troubleshoot](#3-troubleshoot)
  - [3.1. TODO](#31-todo)
- [4. References](#4-references)

## 1. Details

### 1.1. Prerequisites

## 2. Usage

### 2.1. Bootstrap

A bootstrap script initializes an environment, application, or system by installing dependencies, configuring settings, or preparing the system for further operations.

- [scripts/](scripts/README.md)
  > Collection of bootstrap, setup, or teardown scripts across multiple environments.

### 2.2. Dev Containers

A Development Container (Dev Container) utilizes a container as a full-featured development environment.

- [.devcontainer/](.devcontainer/README.md)
  > Collection of Dev Container resources published under `mcr.microsoft.com/devcontainers`.

### 2.3. Task Runner

#### 2.3.1. Makefile

- [Makefile](Makefile)
  > The Makefile serves as the task runner.

  > [!NOTE]
  > - Run the `make help` command in the terminal to list the tasks used for the project.
  > - Targets **must** have a leading comment line starting with `##` to be included in the task list.

  ```plaintext
  $ make help

  Tasks
          A collection of tasks used in the current project.

  Usage
          make <task>

          bootstrap              Initialize a software development workspace with requisites
          setup                  Install and configure all dependencies essential for development
          teardown               Remove development artifacts and restore the host to its pre-setup state
          secret-gpg-generate    Generate a new GPG key pair for SOPS
          secret-gpg-show        Print the GPG key fingerprint for SOPS (.sops.yaml)
          secret-gpg-remove      Remove an existing GPG key for SOPS (interactive)
          secret-sops-encrypt    Encrypt file using SOPS
          secret-sops-decrypt    Decrypt file using SOPS
          secret-sops-view       View a file encrypted with SOPS
  ```

### 2.4. Release Manager

#### 2.4.1. Semantic-Release

The [semantic-release](https://github.com/semantic-release/semantic-release) tool automates release workflows, including determining the next version number, generating a `CHANGELOG.md` file, and publishing the release notes with artifacts.

- [.gitlab-ci.yml](.gitlab-ci.yml)

  ```yaml
  include:
    - component: $CI_SERVER_FQDN/ci-cd/manager/semantic-release@~latest
  ```

### 2.5. Dependency Manager

#### 2.5.1. Renovate

[Renovate](https://github.com/renovatebot/renovate) automates dependency updates by creating Pull Requests (PRs) or Merge Requests (MRs) to update versions.

- [.gitlab-ci.yml](.gitlab-ci.yml)

  ```yaml
  include:
    - component: $CI_SERVER_FQDN/ci-cd/manager/renovate@~latest
  ```

### 2.6. Secret Manager

#### 2.6.1. SOPS

1. GPG Key Pair Generation

    - Task Runner
      > Generate a new key pair to be used with SOPS.

      > [!NOTE]
      > The UID can be customized via the `SOPS_UID` variable (defaults to `sops-dx`).

      ```sh
      make secret-gpg-generate SOPS_UID=<uid>
      ```

2. GPG Public Key Fingerprint

    - Task Runner
      > Print the  GPG Public Key fingerprint associated with a given UID.

      ```sh
      make secret-gpg-show SOPS_UID=<uid>
      ```

    - [.sops.yaml](.sops.yaml)
      > The GPG UID is required for populating in `.sops.yaml`.

      ```yaml
      creation_rules:
        - pgp: "<fingerprint>" # <uid>
      ```

3. SOPS Encrypt/Decrypt

    - Task Runner
      > Encrypt/decrypt one or more files in place using SOPS.

      ```sh
      make secret-sops-encrypt <files>
      make secret-sops-decrypt <files>
      ```

## 3. Troubleshoot

### 3.1. TODO

TODO

## 4. References

- GitHub [SOPS](https://github.com/getsops/sops) repository.
- GitHub [Task](https://github.com/go-task/task) repository.
- GnuPG [GPG](https://www.gnupg.org/) pages.
- Conventional [Commits](https://www.conventionalcommits.org/en/v1.0.0/) pages.
- Semantic [Versioning](https://semver.org/) pages.
