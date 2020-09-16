# Installing Kubernetes

## Networking requirements

 * All Pods can communicate with each other on all nodes.
 * All Nodes can communicate with all Pods.
 * No Network Address Translation (NAT)

Reference for setting up kubernetes from scratch.
> https://kubernetes.io/docs/setup/scratch/
> https://github.com/kelseyhightower/kubernetes-the-hard-way/

## What kubeadm init does by defaul

### Creates a Certificate Autority 
 * Creates a self-signed CA - can specify an external PKI
 * Authenticates users and kubelets
 * Secures communication over https
 * Stores it here `/etc/kubernetes/pki`

### Generates kubeconfig files.

This generates a config file in `/etc/kubernetes/` for:
 * kubernetes-admin -> admin.conf
 * kubelet -> kubelet.conf
 * controller-manager -> controller-manager.conf
 * scheduler -> scheduler.conf

### Static Pod Manifest

The live in `/etc/kubernetes/manifests` and create pods:
* ectd
* API Server
* Controller Manager
* Scheduler

## What kubeadm join does by defaul

 * Downloads Cluster Information
 * Node submits a CSR
 * CA Signs the CSR automatically
 * Configures kubelet.conf
 
### Download