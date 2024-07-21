#Requires -Version 7
# TODO: add file description

############################### Helper functions ###############################

function FindCommandOr($command, $else) {
    Get-Command $command -ErrorAction "SilentlyContinue" | Out-Null
    if (-not $?) {
        $else.Invoke()
        Get-Command $command -ErrorAction "Stop"
    }
}

function FindFontOr($font, $else) {
    [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    $fonts = (
            New-Object System.Drawing.Text.InstalledFontCollection
        ).Families | ForEach { $_.Name }
    if (-not $fonts.contains("$font")) {
        $else.Invoke()
    }
}

function MakeDirIfDoesNotExist($directory) {
    New-Item -ItemType "Directory" -Path "$directory" -Force
    return "$directory"
}

function Download($url) {
    $path = Join-Path "$DOWNLOAD_PATH" (Split-Path "$url" -Leaf)
    Invoke-WebRequest "$url" -OutFile "$path"
    return "$path"
}

function 7zExtractTar($from, $to) {
    7z x -so "$from" | 7z x -si -aoa -ttar -o"$to"
}

function AppendToPSProfile([string[]] $commands) {
    $commands += ''
    $commands | ForEach { Add-Content -Path "$Profile" -Value "$_" }
}


############################### Helper variables ###############################

$DOWNLOAD_PATH = (
        New-Object -ComObject "Shell.Application"
    ).NameSpace("shell:Downloads").Self.Path


################################ Initialization ################################

AppendToPSProfile @(
    '#####################################################'
    '# The following commands are appended automatically #'
    '#####################################################'
)

# TODO: init WSL2

# Update PATH variable after package installation
# See: https://github.com/jazzdelightsme/WingetPathUpdater
winget install WingetPathUpdater

FindCommandOr "7z" {
    Write-Output "Install 7-Zip..."
    winget install --exact --id 7zip.7zip

    # TODO: add "$ENV:ProgramFiles\7-Zip" to PATH
}

FindCommandOr "vim" {
    Write-Output "Install vim..."
    Write-Output "NOTE: check the box 'Create .bat files' for command line use."
    winget install --exact --id vim.vim --interactive
}

FindCommandOr "git" {
    Write-Output "Install git..."
    winget install --exact --id Git.Git --interactive

    Write-Output "Setting up user git configuration..."
    Copy-Item -Path (Join-Path ".." "common" ".gitconfig") -Destination "$HOME"
    git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
    # TODO: ssh configuration
}

FindFontOr "JetBrainsMono NF" {
    $gitTag = "v3.2.1"
    $downloadedFilePath = Download "https://github.com/ryanoasis/nerd-fonts/releases/download/$gitTag/JetBrainsMono.tar.xz"
    $extractedDirPath = Join-Path "$DOWNLOAD_PATH" "JetBrainsMono"

    7zExtractTar "$downloadedFilePath" "$extractedDirPath"

    # TODO: install fonts

    Remove-Item "$downloadedFilePath" -Force
    Remove-Item "$extractedDirPath" -Force -Recurse
}

# Starship cross-shell prompt
# See: https://starship.rs/
FindCommandOr "starship" {
    Write-Output "Install starship..."
    winget install --exact --id Starship.Starship

    Write-Output "Setting up starship configuration..."
    $file = "starship.toml"
    $dir = ".config"
    $dirPath = MakeDirIfDoesNotExist (Join-Path "$HOME" "$dir")
    Copy-Item -Path (Join-Path ".." "common" "$file") -Destination "$filePath"

    Write-Output "Append starship runner to PowerShell user profile..."
    $sep = [IO.Path]::DirectorySeparatorChar
    AppendToPSProfile @(
        '# Starship cross-shell prompt runner',
        "`$ENV:STARSHIP_CONFIG = `"`$HOME$sep$dir$sep$file`"",
        'Invoke-Expression (&starship init powershell)',
    )
}

FindCommandOr "code" {
    Write-Output "Install Microsoft Visual Studio Code..."
    winget install --exact --id Microsoft.VisualStudioCode --interactive
}

Write-Output "Please, re-run Terminal!"
