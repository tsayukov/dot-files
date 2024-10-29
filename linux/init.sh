#!/usr/bin/env bash

############################### Helper variables ###############################

AS_WSL=false
RCFILE=~/.bashrc

# ROOT will be defined below

USER_TRUE_TYPE_FONTS_ROOT=~/.local/share/fonts/truetype
NERD_FONTS_NAME='JetBrainsMono'

############################### Helper functions ###############################

function bool() {
    case "$1" in
        (true)
            return 0
        ;;
        (false)
            return 1
        ;;
        (*)
            fail "Boolean value must be either 'true' or 'false', but got: '$1'"
        ;;
    esac
}

function print_color_text() {
    local color="$1"
    local text="$2"

    local no_color='\033[0m'
    printf "${color}${text}${no_color} "
}

function message_ongoing() {
    local blue='\033[0;34m'
    print_color_text $blue 
    echo "$@"
}

function message_success() {
    local green='\033[0;32m'
    print_color_text $green ✔
    echo "$@"
}

function message_fail() {
    local red='\033[0;31m'
    print_color_text $red ✘
    echo "$@" >&2
}

function do_logging() {
    LOG_MESSAGE="$1"
    message_ongoing "$LOG_MESSAGE"
}

function fail() {
    if [ ! -z "$LOG_MESSAGE" ]; then
        message_fail "$LOG_MESSAGE - fail"
    elif [ ! -z "$1" ]; then
        message_fail "$1"
    else
        message_fail "fail (no message was provided)"
    fi
    exit 1
}

function done_logging() {
    message_success "$LOG_MESSAGE - done"
    unset LOG_MESSAGE
}

function does_command_exist() {
    if [ $(command -v $1) ]; then
        return 0
    else
        return 1
    fi
}

function append_new_line_to() {
    echo -e '\n' >> $1
}

function init_windows_userprofile() {
    # TODO: figure out how to get %USERPROFILE% automatically
    read -p "Enter Windows USERPROFILE (a path of the '/mnt/c/users/<user_name>' form): " \
            WINDOWS_USERPROFILE \
            && test -d "$WINDOWS_USERPROFILE" \
            || fail "Windows USERPROFILE '$WINDOWS_USERPROFILE' is not found!"

    message_success "Found Windows USERPROFILE: '$WINDOWS_USERPROFILE'"
}

############################### Parse arguments ################################

function help_output() {
    cat <<EOF
Usage: init.sh [--help | --wsl] [--]
Basic initialization of Linux.

  --help  display this help and exit
  --wsl   the current Linux system will be treated as a part of WSL

EOF
}

while true; do
    case "$1" in
        (--help)
            help_output
            exit 0
        ;;
        (--wsl)
            init_windows_userprofile
            AS_WSL=true
            shift
            break
        ;;
        (--)
            shift
            break
        ;;
        ('')
            break
        ;;
        (*)
            fail "Unknown argument: $1"
        ;;
    esac
done

################## Installing and configuring basic packages ###################

# Create the user's directories
mkdir -p ~/Apps ~/Projects || fail

# Homebrew on Linux
# See: https://docs.brew.sh/Homebrew-on-Linux

if ! does_command_exist brew; then
    do_logging 'Installing homebrew'
    /usr/bin/env bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
            || fail
    done_logging

    do_logging 'Adding homebrew to the PATH and bash shell rcfile'
    test -d /home/linuxbrew/.linuxbrew \
            && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" \
            || fail
    append_new_line_to $RCFILE
    echo '# Add Homebrew to the PATH' \
            && echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> $RCFILE \
            && echo 'Adding homebrew to the PATH and bash shell rcfile - done' \
            || fail
    done_logging
fi

# Check if the script is running in the proper directory

ROOT="$(git rev-parse --show-toplevel)"
if [ "$(pwd)" != "$ROOT/linux" ]; then
    fail "This script must be run in the '<dot_files_repository>/linux' directory"
fi

# Install vim

if ! does_command_exist vim; then
    do_logging 'Install vim'
    brew install vim || fail
    done_logging
fi

# Git configuration

if [ -z "$(git config --global user.name)" ]; then
    read -p 'Git config: enter your name: ' GIT_USER_NAME \
            && git config --global user.name "$GIT_USER_NAME" \
            || fail
    message_success "Git config: set the user's name to '$(git config --global user.name)'"
    unset GIT_USER_NAME

    read -p 'Git config: enter your email: ' GIT_USER_EMAIL \
            && git config --global user.email "$GIT_USER_EMAIL" \
            || fail
    message_success "Git config: set the user's email to '$(git config --global user.email)'"
    unset GIT_USER_EMAIL

    do_logging "Git config: append other common parameters to ~/.gitconfig"
    cat $ROOT/common/.gitconfig >> ~/.gitconfig || fail
    done_logging
fi

# Install Bitwarden

if ! bool $AS_WSL && [ -z "$(ls ~/Apps | grep Bitwarden)" ]; then
    VERSION="$(\
            git ls-remote --tags --sort=-version:refname \
                    https://github.com/bitwarden/clients \
                    desktop-* \
                    | head --lines=1 \
                    | grep -oP '(?<=desktop-v).*$' \
                    || fail 'Cannot get the last Bitwarden version')"

    do_logging "Downloading Bitwarden-v$VERSION to ~/Apps"
    wget -P ~/Apps https://github.com/bitwarden/clients/releases/download/desktop-v$VERSION/Bitwarden-$VERSION-x86_64.AppImage \
            && chmod u+x ~/Apps/Bitwarden-$VERSION-x86_64.AppImage \
            || fail
    done_logging

    do_logging "Add Bitwarden-v$VERSION to startup programs"
    mkdir -p ~/.config/autostart || fail
    cat >> ~/.config/autostart/Bitwarden-$VERSION-x86_64.AppImage.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=$(realpath ~/Apps/Bitwarden-$VERSION-x86_64.AppImage)
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Bitwarden
Name=Bitwarden
Comment[en_US]=Password manager
Comment=Password manager
EOF
    test $? = 0 || fail
    done_logging

    unset VERSION
fi

# SSH configuration

if [ ! -f ~/.ssh/id_ed25519 -o ! -f ~/.ssh/id_ed25519.pub ]; then
    # Copying/generating SSH keys

    if bool $AS_WSL; then
        do_logging 'Copying the ssh keys from Windows'
        mkdir ~/.ssh \
                && cp $WINDOWS_USERPROFILE/.ssh/id_ed25519 ~/.ssh/id_ed25519 \
                && chmod 600 ~/.ssh/id_ed25519 \
                && cp $WINDOWS_USERPROFILE/.ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub \
                && chmod 600 ~/.ssh/id_ed25519.pub \
                || fail
        done_logging
    else
        do_logging 'Generating SSH keys'
        ssh-keygen -t ed25519 -C "$(git config --global user.email)" -f ~/.ssh/id_ed25519 || fail
        done_logging

        cat >&1 <<EOF
Associate your public SSH key with your Github account.
Go to https://github.com/settings/keys (Settings - SSH and GPG keys) and add the new SSH key:

$(cat ~/.ssh/id_ed25519.pub)

EOF
        read -p 'Press ENTER when your public SSH key is associated with your Github account...'
    fi
fi

# Connecting to GitHub with SSH

if [ -z "$(grep 'github.com' ~/.ssh/known_hosts)" ]; then
    do_logging 'Adding github.com to ~/.ssh/known_hosts'
    cat >> ~/.ssh/known_hosts <<EOF
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
EOF
    test $? = 0 || fail
    done_logging
fi

ssh -T git@github.com

if [ -z "$(grep '# Auto-launching ssh-agent' $RCFILE)" ]; then
    # See: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/working-with-ssh-key-passphrases#auto-launching-ssh-agent-on-git-for-windows
    do_logging 'Adding script for auto-launching ssh-agent to the rcfile'
    cat >> $RCFILE <<EOF

# Auto-launching ssh-agent

env=~/.ssh/agent.env

function agent_load_env() {
    test -f "\$env" && . "\$env" >| /dev/null
}

function agent_start() {
    (umask 077; ssh-agent >| "\$env")
    . "\$env" >| /dev/null
}

agent_load_env

# agent_run_state: 0=agent running w/ key; 1=agent w/o key; 2=agent not running
agent_run_state=\$(ssh-add -l >| /dev/null 2>&1; echo \$?)

if [ ! "\$SSH_AUTH_SOCK" ] || [ \$agent_run_state = 2 ]; then
    agent_start
    ssh-add
elif [ "\$SSH_AUTH_SOCK" ] && [ \$agent_run_state = 1 ]; then
    ssh-add
fi

unset agent_run_state
unset env
EOF
    test $? = 0 && source $RCFILE || fail
    done_logging
fi

# Nerd fonts
# See the patched fonts: https://www.nerdfonts.com/
# See the original fonts: https://www.jetbrains.com/lp/mono/
if [ -z "$(fc-list | grep $NERD_FONTS_NAME)" ]; then
    NERD_FONTS_VERSION="$(\
            git ls-remote --tags --sort=-version:refname \
                    https://github.com/ryanoasis/nerd-fonts \
                    | head --lines=1 \
                    | grep -oE 'v[0-9]+(\.[0-9]+(\.[0-9]+)?)?' \
                    || fail)"

    do_logging "Downloading $NERD_FONTS_NAME Nerd Fonts $NERD_FONTS_VERSION "\
               "from https://github.com/ryanoasis/nerd-fonts"
    wget https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONTS_VERSION/$NERD_FONTS_NAME.tar.xz \
            || fail
    done_logging
    unset NERD_FONTS_VERSION

    echo "Extracting $NERD_FONTS_NAME.tar.xz to $USER_TRUE_TYPE_FONTS_ROOT/$NERD_FONTS_NAME"
    mkdir -p $USER_TRUE_TYPE_FONTS_ROOT/$NERD_FONTS_NAME \
            && tar -Jxf $NERD_FONTS_NAME.tar.xz \
                   --directory $USER_TRUE_TYPE_FONTS_ROOT/$NERD_FONTS_NAME/ \
            && rm $NERD_FONTS_NAME.tar.xz \
            || fail
    done_logging

    do_logging "Installing $NERD_FONTS_NAME Nerd Fonts"
    fc-cache -f -v || fail
    done_logging

    if [ -z "$(fc-list | grep $NERD_FONTS_NAME)" ]; then
        fail "Fatal error: $NERD_FONTS_NAME Nerd Fonts is not found after the installation!"
    fi
fi

# Starship Cross-Shell Prompt
# See: https://starship.rs
if ! does_command_exist starship; then
    do_logging 'Installing Starship cross-shell prompt'
    brew install starship || fail
    done_logging

    do_logging 'Copying Starship config to ~/.config/starship.toml'
    mkdir -p ~/.config \
            && cp $ROOT/common/starship.toml ~/.config/ \
            || fail
    done_logging

    do_logging 'Add Starship runner to the rcfile'
    append_new_line_to $RCFILE \
            && echo '# Starship cross-shell prompt runner' >> $RCFILE \
            && echo 'eval "$(starship init bash)"' >> $RCFILE \
            && source $RCFILE \
            || fail
    done_logging
fi
