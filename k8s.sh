#!/bin/bash

install_docker() {
    echo "Installing Docker"

    sudo apt update
    sudo apt install -y docker-ce
    sudo systemctl enable docker   
}

install_docker