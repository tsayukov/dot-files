#!/usr/bin/env bash

if [ $(id -u) -ne 0 ]; then
    cat >&2 <<EOF
Running the script requires the superuser privilege.
Enter the code below to re-run the script with the necessary privilege:

  sudo !!

EOF
    exit 1
fi

sudo apt update && sudo apt upgrade
sudo apt install build-essential procps curl file git libfuse2
