<#
.SYNOPSIS
    A resilient web request with retry logic and timeout settings.

.DESCRIPTION
    The `Invoke-Cmdlet-WebRequest` uses Invoke-WebRequest function to downloads a file from a specified URI and saves
    it to a specified output file. It includes retry logic in case of failures, customizable retry delay, and timeout
    settings. The security protocol is set to TLS 1.2 or fallsback to TLS 1.1 or TLS 1.0 for compatibility.

.PARAMETER Uri
    The URI to which the request is made.

.PARAMETER MaxRetries
    The maximum number of retry attempts.

.PARAMETER RetryDelay
    The delay between retries in seconds.

.EXAMPLE
    Invoke-Cmdlet-WebRequest -Uri "https://example.com"  -OutFile "C:\Tools\"
#>
function Invoke-Cmdlet-WebRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutFile,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 5,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelay = 2,

        [Parameter(Mandatory = $false)]
        [hashtable]$Headers = @{},

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 10
    )

    begin {
        $attempt = 0
        $success = $false

        # Ensure TLS 1.2 or higher is used, but allow fallback to TLS 1.1 or TLS 1.0
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
    }

    process {
        while (-not $success -and $attempt -lt $MaxRetries) {
            try {
                Invoke-WebRequest -Uri $Uri -OutFile $OutFile -TimeoutSec $TimeoutSeconds -ErrorAction Stop -ProgressAction SilentlyContinue
                $success = $true
            } catch {
                Write-Warning "Failed to download $OutFile from $Uri. Attempt $($attempt + 1) of $MaxRetries."
                Start-Sleep -Seconds $RetryDelay
                $attempt++
            }
        }
    }

    end {
        if (-not $success) {
            throw "Failed to download $OutFile after $MaxRetries attempts."
        }
    }
}
