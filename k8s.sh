#!/bin/bash

install_docker() {
    echo "Installing Docker"

    apt update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    # TODO: Validate fingerprint - https://docs.docker.com/v17.09/engine/installation/linux/docker-ce/ubuntu/#set-up-the-repository
    add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
    apt update
    apt install -y docker-ce
}

install_kubernetes() {
    echo "Installing Kubernetes"

    apt update
    apt install -y \
        apt-transport-https \
        curl
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
        deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF    
    apt update
    apt install -y \
        kubelet \
        kubeadm \
        kubectl
    apt-mark hold kubelet kubeadm kubectl
    swapoff -a
    hostnamectl set-hostname k8s-master
    kubeadm init --pod-network-cidr=10.244.0.0/16
}

# install_docker
install_kubernetes