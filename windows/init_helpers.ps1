#Requires -Version 7
# Helper functions and variables

############################### Helper variables ###############################

$DOWNLOAD_PATH = (
        New-Object -ComObject "Shell.Application"
    ).NameSpace("shell:Downloads").Self.Path


############################### Helper functions ###############################

function FindCommandOr([String] $command, [ScriptBlock] $else) {
    Get-Command $command -ErrorAction "SilentlyContinue" | Out-Null
    if (-not $?) {
        $else.Invoke()
        Get-Command $command -ErrorAction "Stop"
    }
}

function FindFontOr([String] $font, [ScriptBlock] $else) {
    [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    $fonts = (
            New-Object System.Drawing.Text.InstalledFontCollection
        ).Families | ForEach { $_.Name }
    if (-not $fonts.contains("$font")) {
        $else.Invoke()
    }
}

function MakeDirIfDoesNotExist([String] $directory) {
    New-Item -ItemType "Directory" -Path "$directory" -Force
    return "$directory"
}

function Download([String] $url) {
    $path = Join-Path "$DOWNLOAD_PATH" (Split-Path "$url" -Leaf)
    Invoke-WebRequest "$url" -OutFile "$path"
    return "$path"
}

function 7zExtractTar([String] $from, [String] $to) {
    7z x -so "$from" | 7z x -si -aoa -ttar -o"$to"
}

function AppendToPSProfile([String[]] $commands) {
    $commands += ''
    $commands | ForEach { Add-Content -Path "$Profile" -Value "$_" }
}

function AddSemicolon([String] $str) {
    if (-not $str) {
        $str = ";"
    }
    if ($str[$str.Length - 1] -ne ";") {
        $str += ";"
    }
    return $str
}

function AddToEnvPath([String] $path) {
    $currentPaths = (
            Get-Item HKCU:\Environment
        ).getValue("PATH", $null, "DoNotExpandEnvironmentNames")

    if ("$current" -like "*$path*") {
        return
    }

    $newPaths = "$currentPaths"
    $newPaths = AddSemicolon "$newPaths"
    $newPaths += "$path;"

    # Update PATH globally
    Set-ItemProperty HKCU:\Environment PATH "$newPaths" -Type ExpandString

    # Update PATH for the current Terminal session
    $ENV:PATH = AddSemicolon "$ENV:PATH"
    $ENV:PATH += "$path;"
}
