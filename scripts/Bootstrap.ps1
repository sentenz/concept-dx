# Initialize a software development workspace on Windows.

Set-StrictMode -Version Latest

# Internal Advanced Function

function Initialize-ScopeVariable {
    [CmdletBinding()]
    param ()

    begin {
        # Array of Hashtables for Winget Packages
        # See https://winget.ragerworks.com/
        $Script:WingetPackage = @(
            @{ Id = "ezwinports.make"        ; Info = "" },
            @{ Id = "Task.Task"              ; Info = "" },
            @{ Id = "Ninja-build.Ninja"      ; Info = "" },
            @{ Id = "Ccache.Ccache"          ; Info = "" },
            @{ Id = "Python.Python.3.12"     ; Info = "" }
        )

        # Hashtable for Python Virtual Environment
        $Script:PipVenv = @{
            Path = Join-Path -Path (Get-Location) -ChildPath ".venv"
            Pip  = Join-Path -Path ".venv" -ChildPath "Scripts/pip.exe"
        }

        # Array of Hashtables for Python Packages
        $Script:PipPackage = @(
            @{
                Name    = "<package-name>"
                Version = "<version>" # Leave empty for latest
                Url     = "https://pypi.org/simple"
                Info    = ""
            }
        )

        # Array of Hashtables for Downloads
        $Script:Download = @(
            @{
                Description = "GCC-ARM Toolchain"
                Url         = "https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi.tar.xz"
                Version     = "14.2.rel1"
                Path        = Join-Path -Path $Env:USERPROFILE -ChildPath "AppData/Local/Programs/Tools/arm-gnu-toolchain"
                Info        = ""
            },
            @{
                Description = "PowerShell"
                Url         = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.0/PowerShell-7.5.0-win-x64.msi"
                Version     = "7.5.0"
                Path        = ""
                Info        = ""
            },
            @{
                Description = "Sonar-Scanner CLI"
                Url         = "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-7.1.0.4889-windows-x64.zip"
                Version     = "7.1.0.4889"
                Path        = Join-Path -Path $Env:USERPROFILE -ChildPath "AppData/Local/Programs/Tools/sonar-scanner"
                Info        = ""
            }
        )
    }

    process { }

    end { }
}

function Install-WingetPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [array] $Packages
    )

    begin {
        # Ensure winget is available
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Error "winget is not installed or not found in PATH."
            return
        }
    }

    process {
        # Install each package
        foreach ($pkg in $Packages) {
            $id = $pkg.Id

            try {
                Write-Verbose "Installing Winget package: $($id)"

                winget install --id=$id -e --scope user --accept-package-agreements --accept-source-agreements --silent
            } catch {
                Write-Warning "Failed to install package: $($id) - $($_.Exception.Message)"
            }
        }
    }

    end { }
}

function Install-PipPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [array]$Packages,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$Venv
    )

    begin {
        # Create virtual environment
        try {
            Write-Verbose "Creating Python virtual environment at: $Venv.Path"
            if (-not (Test-Path -Path $Venv.Path)) {
                python -m venv $Venv.Path
            }
        } catch {
            Write-Error "Failed to create virtual environment: $($_.Exception.Message)"
        }
        # Upgrade pip in virtual environment
        try {
            Write-Verbose "Upgrading pip to the latest version in $Venv.Path"
            & $Venv.Pip install --upgrade pip
        } catch {
            Write-Warning "Failed to upgrade pip in $Venv.Path - $($_.Exception.Message)"
        }
    }

    process {
        # Install each package in virtual environment
        foreach ($pkg in $Packages) {
            $name = $pkg.Name
            $version = $pkg.Version
            $url = $pkg.Url

            try {
                Write-Verbose "Installing Python package in $Venv.Path: $name"

                if ($version) {
                    & $Venv.Pip install "$name==$version" --index-url $url --upgrade
                } else {
                    & $Venv.Pip install $name --index-url $url --upgrade
                }
            } catch {
                Write-Warning "Failed to install package in $Venv.Path: $($name) - $($_.Exception.Message)"
            }
        }
    }

    end {
        try {
            Write-Verbose "Cleaning pip cache in $Venv.Path"
            & $Venv.Pip cache purge
        } catch {
            Write-Warning "Failed to purge pip cache in $Venv.Path - $($_.Exception.Message)"
        }
    }
}

function Invoke-SetupDownload {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [array] $Downloads
    )

    begin { }

    process {
        foreach ($item in $Downloads) {
            $filename = Split-Path $item.Url -Leaf
            $filepath = $item.Path
            $url = $item.Url
            $description = $item.Description

            try {
                Write-Verbose "[$description] Downloading from $url"

                Invoke-WebRequest -Uri $url -OutFile $filename -ErrorAction Stop
            } catch {
                Write-Error "[$description] Failed to download: $($_.Exception.Message)"
                continue
            }

            switch -Wildcard ($filename) {
                "arm-gnu-toolchain-*.tar.xz" {
                    try {
                        if (-not (Test-Path -Path $filepath)) {
                            New-Item -ItemType Directory -Force -Path $filepath | Out-Null
                        }

                        tar -xf $filename -C $filepath --strip-components=1

                        $envPath = Join-Path -Path $filepath -ChildPath "bin"
                        if ($Env:Path -notlike "*${envPath}*") {
                            $Env:Path += ";$envPath"
                        }

                        Write-Verbose "[$description] Extracted to $filepath"
                    } catch {
                        Write-Error "[$description] Failed: $($_.Exception.Message)"
                    } finally {
                        if (Test-Path $filename) {
                            Remove-Item -Path $filename -Force -Recurse -ErrorAction Stop
                        }
                    }
                }

                "PowerShell-*.msi" {
                    try {
                        Start-Process msiexec.exe -Wait -ArgumentList "/i `"$filename`" /quiet"
                        Write-Verbose "[$description] Installed"
                    } catch {
                        Write-Error "[$description] Failed: $($_.Exception.Message)"
                    } finally {
                        if (Test-Path $filename) {
                            Remove-Item -Path $filename -Force -Recurse -ErrorAction Stop
                        }
                    }
                }

                "sonar-scanner-*.zip" {
                    try {
                        if (-not (Test-Path -Path $filepath)) {
                            New-Item -ItemType Directory -Force -Path $filepath | Out-Null
                        }

                        Expand-Archive -LiteralPath $filename -DestinationPath $filepath -Force

                        $source = Get-ChildItem -Path $filepath -Directory -Filter "sonar-scanner-*" | Select-Object -First 1
                        Get-ChildItem -Path $source.FullName -Force | ForEach-Object {
                            Copy-Item -Path $_.FullName -Destination $filepath -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        Remove-Item -Path $source.FullName -Force -Recurse -ErrorAction Stop

                        $envPath = Join-Path -Path $filepath -ChildPath "bin"
                        if ($Env:Path -notlike "*${envPath}*") {
                            $Env:Path += ";$envPath"
                        }

                        Write-Verbose "[$description] Extracted and installed to $filepath"
                    } catch {
                        Write-Error "[$description] Failed: $($_.Exception.Message)"
                    } finally {
                        if (Test-Path $filename) {
                            Remove-Item -Path $filename -Force -Recurse -ErrorAction Stop
                        }
                    }
                }

                default {
                    Write-Warning "[$description] No handler for file: $filename"
                }
            }
        }
    }

    end { }
}

# Workflow

try {
    Initialize-ScopeVariable
    Install-WingetPackage -Packages $Script:WingetPackage -Verbose
    Install-PipPackage -Packages $Script:PipPackage -Venv $Script:PipVenv -Verbose
    Invoke-SetupDownload -Downloads $Script:Download -Verbose
} catch {
    Write-Error "In: $PSCommandPath Error: $_"
    $Host.SetShouldExit(1)
}
