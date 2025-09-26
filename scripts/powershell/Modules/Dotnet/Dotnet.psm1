<#
.SYNOPSIS
    Publish a .NET project for deployment using the specified parameters.

.DESCRIPTION
    This function publishes a .NET project by running the `dotnet publish` command with the specified parameters.
    It supports specifying the runtime, configuration, self-contained option, and additional command-line constants.

.PARAMETER ProjectPath
    The path to the .csproj file of the a .NET project to publish.

.PARAMETER Runtime
    Specifies the target runtime for the application. Default is "win-x64".

.PARAMETER Configuration
    specifies the build configuration to use for the publish operation. Default is "Release".

.PARAMETER SelfContained
    Indicates whether to produce a self-contained deployment. Default is $false.

.PARAMETER CommandLineConstants
    Additional command-line constants to pass a custom MSBuild property to the `dotnet publish` command.

.EXAMPLE
    Publish-Dotnet -ProjectPath "Example.csproj" -CommandLineConstants "RELEASE_FREIGABE"

    This example publishes the "Example.csproj" project with the specified command-line constants.

.EXAMPLE
    Publish-Dotnet -ProjectPath "Example.csproj"

    This example publishes the "Example.csproj" project with default parameters.
#>
function Publish-Dotnet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectPath,

        [string]$Runtime = "win-x64",

        [ValidateSet("Debug", "Release")]
        [string]$Configuration = "Release",

        [bool]$SelfContained = $false,

        [string]$CommandLineConstants = ""
    )

    begin {
        $selfContainedParam = if ($SelfContained) { "true" } else { "false" }
    }

    process {
        try {
            dotnet publish $ProjectPath --runtime $Runtime -c $Configuration --self-contained $selfContainedParam $CommandLineConstants
        } catch {
            Write-Error "In: $PSCommandPath Error: $_"
        }
    }
}
