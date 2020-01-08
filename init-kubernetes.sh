#!/bin/bash
echo "Deploying Kubernetes - Master Node"

apiserveraddr=$(hostname -I | cut -d' ' -f1)
echo "APIServerAddress: $apiserveraddr"
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$apiserveraddr


adduser $username --gecos "$username,,," --disabled-password
echo "$username:$password" | chpasswd
    
mkdir -p /home/$username/.kube
cp -i /etc/kubernetes/admin.conf /home/$username/.kube/config
chown $username:$username /home/$username/.kube/config
runuser -l $username -c "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
