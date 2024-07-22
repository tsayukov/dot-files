#Requires -Version 7
# Initialization after a fresh Windows installation

. .\init_helpers.ps1

AppendToPSProfile @(
    '#####################################################'
    '# The following commands are appended automatically #'
    '#####################################################'
)

# TODO: init WSL2

# Update PATH variable after package installation via `winget`
# See: https://github.com/jazzdelightsme/WingetPathUpdater
winget install WingetPathUpdater

# A `sudo` equivalent for Windows
# See: https://github.com/gerardog/gsudo
FindCommandOr "gsudo" {
    Write-Output "Install gsudo..."
    winget install --exact --id gerardog.gsudo
}

# A file archiver
# See: https://www.7-zip.org/
FindCommandOr "7z" {
    Write-Output "Install 7-Zip..."
    winget install --exact --id 7zip.7zip
    AddToEnvPath (Join-Path "$ENV:ProgramFiles" "7-Zip")
}

# A text editor, mostly for git
FindCommandOr "vim" {
    Write-Output "Install vim..."
    Write-Output "NOTE: check the box 'Create .bat files' for command line use."
    winget install --exact --id vim.vim --interactive
}

# A version control system
# See: https://git-scm.com/download/win
FindCommandOr "git" {
    Write-Output "Install git..."
    winget install --exact --id Git.Git --interactive

    Write-Output "Setting up user git configuration..."
    Copy-Item -Path (Join-Path ".." "common" ".gitconfig") -Destination "$HOME"
    git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
    # TODO: ssh configuration
}

# Nerd fonts
# See patched fonts: https://www.nerdfonts.com/
# See original fonts: https://www.jetbrains.com/lp/mono/
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

# A code editor
# See: https://code.visualstudio.com/
FindCommandOr "code" {
    Write-Output "Install Microsoft Visual Studio Code..."
    winget install --exact --id Microsoft.VisualStudioCode --interactive
}

Write-Output "Please, re-run Terminal!"
