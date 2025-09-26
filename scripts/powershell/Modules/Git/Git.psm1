<#
.SYNOPSIS
    Retrieves the root directory of the Git repository.

.DESCRIPTION
    This function uses the git rev-parse command to get the root directory of the Git repository.

.OUTPUTS
    System.String
    The root directory path of the Git repository.

.EXAMPLE
    $rootDirectory = Get-Git-Root-Directory
    Write-Output "Repository Root: $rootDirectory"
#>
function Get-Git-Root-Directory {
    [CmdletBinding()]
    param ()

    begin {
        if ($IsWindows) {
            $cmd = "git.exe"
        } elseif ($IsLinux -or $IsMacOS) {
            $cmd = "git"
        }

        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            throw "The '$cmd' command line tool is not available in the system PATH."
        }
    }

    process {
        try {
            & $cmd rev-parse --show-superproject-working-tree --show-toplevel 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Git command failed with exit code $LASTEXITCODE"
            }
        } catch {
            Write-Error "Failed to retrieve the repository root. Error: $_"
        }
    }
}
