#!/bin/bash

install_docker() {
    echo "Installing Docker"

    apt update
    apt-get install \
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

    apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
    apt install -y kubeadm
    swapoff -a
    hostnamectl set-hostname k8s-master
    kubeadm init --pod-network-cidr=10.244.0.0/16
}

# install_docker
install_kubernetes