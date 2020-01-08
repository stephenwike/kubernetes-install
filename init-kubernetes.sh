#!/bin/bash

if [ "$1" != "" ]; then 
    echo "Deploying Kubernetes - Master Node"
    
    apiserveraddr=$(hostname -I | cut -d' ' -f1)
    echo "APIServerAddress: $apiserveraddr"
    kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$apiserveraddr

    adduser $1 sudo --disabled-password

    if [ "$2" != "" ]; then
        echo "$1:$2" | chpasswd
    fi

    mkdir -p /home/$1/.kube
    cp -i /etc/kubernetes/admin.conf /home/$username/.kube/config
    chown $username:$username /home/$username/.kube/config

    runuser -l $username -c "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

else
    echo "Err: Missing username command line argument."
    exit 1
fi

 

    




