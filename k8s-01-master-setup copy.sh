#!/bin/bash
wget https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml

wget https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml

kubeadm init --pod-network-cdir=192.168.0.0/16

kubectl apply -f rbac-kdd.yaml
kubectl apply -f calico.yaml