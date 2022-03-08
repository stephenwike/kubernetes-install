#!/bin/bash

if [ "$1" != "" ]; then 
    echo "Deploying Kubernetes - Master Node"
    
    apiserveraddr=$(hostname -I | cut -d' ' -f1)
    echo "APIServerAddress: $apiserveraddr"
    kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$apiserveraddr

    adduser $1 -gecos "$1,,," --disabled-password
    usermod -aG sudo $1

    if [ "$2" != "" ]; then
        echo "$1:$2" | chpasswd
    fi

    mkdir -p /home/$1/.kube
    cp -i /etc/kubernetes/admin.conf /home/$1/.kube/config
    chown $1 /home/$1/.kube/config

    runuser -l $1 -c "kubectl apply -f https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

else
    echo "Err: Missing username command line argument."
    exit 1
fi

 

    




