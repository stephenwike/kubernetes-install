#!/bin/bash

install_docker() {
    echo "Installing Docker"

    sudo apt update
    sudo apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common
    sudo systemctl enable docker   
}

install_docker