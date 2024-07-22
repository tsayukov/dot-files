#Requires -Version 7
# Initialization after a fresh Windows installation

# Include helper functions and variables
. (Join-Path "$PSScriptRoot" "init_helpers.ps1")

AppendToPSProfile @(
    '#####################################################'
    '# The following commands are appended automatically #'
    '#####################################################'
)

# WSL2 init
# See: https://learn.microsoft.com/en-us/windows/wsl/install-manual
# See:
Invoke-Command -ScriptBlock {
    Print "Enabling optional features to make WSL2 works..."
    gsudo {
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    }

    #TODO: restart

    $downloadedFilePath = Download "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"

    Print "Installing the Linux kernel update package..."
    Start-Process "$downloadedFilePath" -Wait

    Print "Removing $downloadedFilePath..."
    Remove-Item "$downloadedFilePath" -Force

    Print "Setting up WSL2"
    wsl --set-default-version 2
    # TODO: install linux distro
}

# Update PATH variable after package installation via `winget`
# See: https://github.com/jazzdelightsme/WingetPathUpdater
winget install WingetPathUpdater

# A `sudo` equivalent for Windows
# See: https://github.com/gerardog/gsudo
FindCommandOr "gsudo" {
    Print "Installing gsudo..."
    winget install --exact --id gerardog.gsudo
}

# A file archiver
# See: https://www.7-zip.org/
FindCommandOr "7z" {
    Print "Installing 7-Zip..."
    winget install --exact --id 7zip.7zip
    AddToEnvPath (Join-Path "$ENV:ProgramFiles" "7-Zip")
}

# A text editor, mostly for git
FindCommandOr "vim" {
    Print "Installing vim..."
    Print "NOTE: check the box 'Create .bat files' for command line use."
    winget install --exact --id vim.vim --interactive
}

# A version control system
# See: https://git-scm.com/download/win
FindCommandOr "git" {
    Print "Installing git..."
    winget install --exact --id Git.Git --interactive

    Print "Setting up user git configuration..."
    Copy-Item -Path (Join-Path ".." "common" ".gitconfig") -Destination "$HOME"

    Print "Setting up the ssh-agent service..."
    $sshAgentService = Get-Service -Name "ssh-agent"
    Start-Service $sshAgentService
    gsudo {
        $sshAgentService | Set-Service -StartupType "Automatic"
    }
    AddToEnvPath (Split-Path $sshAgentService.BinaryPathName -Parent)

    Print "Setting up git ssh command..."
    $sshAgentUnixPath = $sshAgentService.BinaryPathName.Replace('\', '/').ToLower()
    git config --global core.sshCommand "$sshAgentUnixPath"

    Print "Generating ssh keys..."
    $sshConfigPath = MakeDirIfDoesNotExist (Join-Path "$HOME" ".ssh")
    $sshPrivateKeyPath = Join-Path "$sshConfigPath" "id_ed25519"
    ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$sshPrivateKeyPath"

    $sshPublicKeyPath = "$sshPrivateKeyPath.pub"
    Print "This is your public key: `"$(Get-Content "$sshPublicKeyPath")`""

    Print "Adding your ssh keys to the ssh-agent..."
    ssh-add "$sshKeyPath"
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

    Print "Removing $downloadedFilePath..."
    Remove-Item "$downloadedFilePath" -Force

    Print "Removing $extractedDirPath..."
    Remove-Item "$extractedDirPath" -Force -Recurse
}

# Starship cross-shell prompt
# See: https://starship.rs/
FindCommandOr "starship" {
    Print "Installing starship..."
    winget install --exact --id Starship.Starship

    Print "Setting up starship configuration..."
    $file = "starship.toml"
    $dir = ".config"
    $dirPath = MakeDirIfDoesNotExist (Join-Path "$HOME" "$dir")
    Copy-Item -Path (Join-Path ".." "common" "$file") -Destination "$filePath"

    Print "Appending starship runner to PowerShell user profile..."
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
    Print "Installing Microsoft Visual Studio Code..."
    winget install --exact --id Microsoft.VisualStudioCode --interactive
}

# The Rust toolchain installer
# See: https://www.rust-lang.org/
FindCommandOr "rustup" {
    Print "Installing rustup..."
    winget install --exact --id Rustlang.Rustup
}

# A line-oriented search tool
# See: https://github.com/BurntSushi/ripgrep
FindCommandOr "rg" {
    Print "Installing ripgrep..."
    winget install --exact --id BurntSushi.ripgrep.MSVC
}

# TODO: install Python 3

# TODO: install CMake

# TODO: install LLVM

################################## Netsurfing ##################################

# A web browser
# See: https://www.mozilla.org/
InteractiveInstall "Mozilla Firefox" "Mozilla.Firefox"

# A clien app for connecting to VPN server
# See: https://github.com/Jigsaw-Code/outline-apps
Invoke-Command -ScriptBlock {
    $gitTag = "v1.10.1"
    $downloadedFilePath = Download "https://github.com/Jigsaw-Code/outline-apps/releases/download/$gitTag/Outline-Client.exe"

    Print "Installing Outline Client..."
    Start-Process "$downloadedFilePath" -Wait

    Print "Removing $downloadedFilePath..."
    Remove-Item "$downloadedFilePath" -Force
}


################################## Encrypting ##################################

# A password manager
# See: https://bitwarden.com/
InteractiveInstall "Bitwarden" "Bitwarden.Bitwarden"

# A disk encryption app
# See: https://veracrypt.fr/
InteractiveInstall "VeraCrypt" "IDRIX.VeraCrypt"


################################ Virtualization ################################

# OS-level virtualization via using containers
# See: https://www.docker.com/
InteractiveInstall "Docker Desktop" "Docker.DockerDesktop"

# A hosted hypervisor for x86 virtualization
# See: https://www.virtualbox.org/
InteractiveInstall "Virtual Box" "Oracle.VirtualBox"


################################ Messaging apps ################################

# A messaging app
# See: https://desktop.telegram.org
InteractiveInstall "Telegram Desktop" "Telegram.TelegramDesktop"


############################### Graphic editors ################################

# An image and photo editor
# See: https://getpaint.net/
InteractiveInstall "paint.net" "dotPDNLLC.paintdotnet"

# Interface design editor
# See: https://www.figma.com/
InteractiveInstall "Figma" "Figma.Figma"

# A vector graphics editor
# See: https://inkscape.org/
InteractiveInstall "Inkscape" "Inkscape.Inkscape"


#################################### Video #####################################

# An audio and video player
# See: https://codecguide.com/
InteractiveInstall "K-Lite Full Codec Pack" "CodecGuide.K-LiteCodecPack.Full"

# Video recording and live streaming
# See: https://obsproject.com/
InteractiveInstall "OBS Studio" "OBSProject.OBSStudio"


################################### Viewers ####################################

# A PDF/eBook/XPS/DjVu/CHM/CBZ/CBR viewer
# See: https://www.sumatrapdfreader.org/free-pdf-reader
InteractiveInstall "SumatraPDF" "SumatraPDF.SumatraPDF"


################################### Writing ####################################

# Writing app based on the Markdown format
# See: https://obsidian.md/
InteractiveInstall "Obsidian" "Obsidian.Obsidian"


#################################### Files #####################################

# A BitTorrent client
# See: https://transmissionbt.com/
InteractiveInstall "Transmission" "Transmission.Transmission"

# A cloud storage
# See: https://disk.yandex.ru/
InteractiveInstall "Yandex.Disk" "Yandex.Disk"


#################################### Games #####################################

# A video game digital distribution service
# See: https://store.steampowered.com/
winget install --exact --id Valve.Steam --interactive
InteractiveInstall "Steam" "Valve.Steam"


################################# Miscellaneous ################################

# TODO: install Типографская раскладка Ильи Бирмана


############################# The end of the file ##############################

Print "Please, re-run Terminal!"
