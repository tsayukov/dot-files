#!/usr/bin/env bash

sudo apt update && sudo apt upgrade

# Homebrew on Linux
# See: https://docs.brew.sh/Homebrew-on-Linux

echo "Installing requirements for homebrew..."
sudo apt install build-essential procps curl file git

echo "Installing homebrew..."
test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc
