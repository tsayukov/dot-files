#!/usr/bin/env bash

WINDOWS_USER=tsayukov

sudo apt update && sudo apt upgrade

# Homebrew on Linux
# See: https://docs.brew.sh/Homebrew-on-Linux

if ! command -v brew &> /dev/null
then
    echo "Installing requirements for homebrew..."
    sudo apt install build-essential procps curl file git

    echo "Installing homebrew..."
    test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
    test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc
fi

# git configuration

cp ../common/.gitconfig ~/.gitconfig

# ssh configuration

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
