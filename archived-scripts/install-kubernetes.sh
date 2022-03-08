#!/bin/bash
echo "Installing Kubernetes"

apt update
apt install -y \
    apt-transport-https \
    curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    
apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

apt update
apt install -y \
    kubelet \
    kubeadm \
    kubectl
        
apt-mark hold kubelet kubeadm kubectl
