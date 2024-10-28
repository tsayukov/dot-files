#!/usr/bin/env bash
set -e

if [ $(id -u) -ne 0 ]; then
    cat >&2 <<EOF
Running the script requires the superuser privilege.
You can type:

  sudo !!

EOF
    exit 1
fi

# Parse arguments

function linux_init_usage() {
    cat <<EOF
Usage: init.sh [--help | --wsl] [--]
Basic initialization of Linux.

  --help  display this help and exit
  --wsl   the current Linux system will be treated as a part of WSL

EOF
}

function get_windows_USERPROFILE() {
    read -p "Enter Windows' USERPROFILE: " WINDOWS_USERPROFILE
    WINDOWS_USERPROFILE_PATH="/mnt/c/users/$WINDOWS_USERPROFILE"
    if [ -d "$WINDOWS_USERPROFILE_PATH" ]; then
        echo "Found Windows' USERPROFILE: $WINDOWS_USERPROFILE"
    else
cat >&2 <<EOF
Windows' USERPROFILE '$WINDOWS_USERPROFILE' is not found.
It was searched in the following places:
  $WINDOWS_USERPROFILE_PATH

EOF
        exit 1
    fi
}

AS_WSL=false

while true; do
    case "$1" in
        (--help)
            linux_init_usage
            exit 0
        ;;
        (--wsl)
            get_windows_USERPROFILE
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
            echo "Unknown argument: $1" >&2
            exit 1
        ;;
    esac
done


sudo apt update && sudo apt upgrade

# Homebrew on Linux
# See: https://docs.brew.sh/Homebrew-on-Linux

if [ ! $(command -v brew) ]; then
    echo 'Installing requirements for homebrew...'
    sudo apt install build-essential procps curl file git
    echo 'Installing requirements for homebrew - done'

    echo 'Installing homebrew...'
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'Installing homebrew - done'

    echo 'Adding homebrew to the PATH and bash shell rcfile...'
    test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo -e '\n' >> ~/.bashrc
    echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc
    echo 'Adding homebrew to the PATH and bash shell rcfile - done'
fi

# Install libfuse2 for AppImages

sudo apt install libfuse2

# Install vim

if [ ! $(command -v vim) ]; then
    echo 'Install vim...'
    brew install vim
    echo 'Install vim - done'
fi

# Git configuration

if [ -z "$(git config --global user.name)" ]; then
    read -p 'Git config: enter your name: ' GIT_USER_NAME
    git config --global user.name "$GIT_USER_NAME"
    echo "Git config: set the user's name to '$(git config --global user.name)'"
    unset GIT_USER_NAME

    read -p 'Git config: enter your email: ' GIT_USER_EMAIL
    git config --global user.email "$GIT_USER_EMAIL"
    echo "Git config: set the user's email to '$(git config --global user.email)'"
    unset GIT_USER_EMAIL

    echo "Git config: append other common parameters to ~/.gitconfig..."
    cat ../common/.gitconfig >> ~/.gitconfig
    echo "Git config: append other common parameters to ~/.gitconfig - done"
fi

# SSH configuration

if [ ! -e ~/.ssh/id_ed25519 -o ! -e ~/.ssh/id_ed25519.pub ]
then
    echo "Copy ssh keys from Windows"
    mkdir ~/.ssh
    cp /mnt/c/users/$WINDOWS_USER/.ssh/id_ed25519 ~/.ssh/id_ed25519
    cp /mnt/c/users/$WINDOWS_USER/.ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub
fi

sudo chmod 600 ~/.ssh/id_ed25519
sudo chmod 600 ~/.ssh/id_ed25519.pub

ssh -T git@github.com

# See: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/working-with-ssh-key-passphrases#auto-launching-ssh-agent-on-git-for-windows
echo "Adding script for auto-launching ssh-agent to .bashrc"
cat >> ~/.bashrc <<EOL

# Auto-launching ssh-agent

env=~/.ssh/agent.env

agent_load_env () { test -f "$env" && . "$env" >| /dev/null ; }

agent_start () {
    (umask 077; ssh-agent >| "$env")
    . "$env" >| /dev/null ; }

agent_load_env

# agent_run_state: 0=agent running w/ key; 1=agent w/o key; 2=agent not running
agent_run_state=$(ssh-add -l >| /dev/null 2>&1; echo $?)

if [ ! "$SSH_AUTH_SOCK" ] || [ $agent_run_state = 2 ]; then
    agent_start
    ssh-add
elif [ "$SSH_AUTH_SOCK" ] && [ $agent_run_state = 1 ]; then
    ssh-add
fi

unset env
EOL

source ~/.bashrc
