# Installing Kubernetes in Hetzner cloud storage

reference: https://community.hetzner.com/tutorials/install-kubernetes-cluster

## Install hcloud-cli

### 1. Create API Token -

reference: https://docs.hetzner.cloud/

Login to **hetzner.com** and in the project click *Security* then click *API Tokens*.  Save token in a safe place for later use.

### 2. Get started with hcloud-cli on local machine (Linux)

reference: https://github.com/hetznercloud/cli

```
apt update && apt install -y hcloud-cli

hcloud context create <my-project>

hcloud network create --name kubernetes --ip-range 10.98.0.0/16

hcloud network add-subnet kubernetes --network-zone eu-central --type server --ip-range 10.98.0.0/16

ssh-keygen
hcloud ssh-key create --name sshkey --public-key-from-file ~/.ssh/id_rsa.pub

hcloud server create --type cx11 --name master-1 --image ubuntu-18.04 --ssh-key sshkey --network kubernetes

hcloud server create --type cx21 --name worker-1 --image ubuntu-18.04 --ssh-key sshkey --network kubernetes

hcloud server create --type cx21 --name worker-2 --image ubuntu-18.04 --ssh-key sshkey --network kubernetes

hcloud floating-ip create --type ipv4 --home-location nbg1
```

### 3. Configure the network

Add this file to each worker node.


```
#/etc/network/interfaces.d/60-floating-ip.cfg

auto eth0:1
iface eth0:1 inet static
  address <your.floating.ip.address>
  netmask 32
```

Then restart networking service

```
systemctl restart networking.service
```

## Installing Docker
reference: https://kubernetes.io/docs/setup/production-environment/container-runtimes/

```
apt update && apt install -y \
  apt-transport-https ca-certificates curl software-properties-common gnupg2
  
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"
  
apt update && apt install -y \
  containerd.io=1.2.13-2 \
  docker-ce=5:19.03.11~3-0~ubuntu-$(lsb_release -cs) \
  docker-ce-cli=5:19.03.11~3-0~ubuntu-$(lsb_release -cs)

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

systemctl daemon-reload

systemctl restart docker
```

## Installing Kubernetes Package

reference: https://linuxconfig.org/how-to-install-kubernetes-on-ubuntu-18-04-bionic-beaver-linux

```
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add

apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

apt install -y kubeadm 

swapoff -a
```

## Prepare the Cloud Controller Manager (Hetzner)
reference: https://github.com/hetznercloud/hcloud-cloud-controller-manager

Add this file to each server.

```
cat <<EOF >>/etc/systemd/system/kubelet.service.d/20-hcloud.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--cloud-provider=external"
EOF
```

Then reload systemd unit files

```
systemctl daemon-reload
```

System needs to be able to forward traffic between nodes and pods.  On each server, run:

```
cat <<EOF >>/etc/sysctl.conf

# Allow IP forwarding for kubernetes
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.default.forwarding = 1
EOF

sysctl -p
```

## Setting Up Control Plane

On the master node only.

```
kubeadm config images pull

kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version=v1.19.0 \
  --ignore-preflight-errors=NumCPU \
  --apiserver-cert-extra-sans 10.98.0.0/16
```

From the `kubeadm init...` command output, save the `kubeadm join...` command for later use.

## Add Admin Users
reference: https://phoenixnap.com/kb/how-to-create-sudo-user-on-ubuntu

```
adduser <newuser>

usermod -aG sudo <newuser>

su - <newuser>
```

## Startup Kubernetes

### 1. Add configuration for admin

```
mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 2. Add hcloud secrets

```
kubectl -n kube-system create secret generic hcloud --from-literal=token=<hcloud API token> --from-literal=network=<hcloud Network_ID_or_Name>

# or...

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: hcloud
  namespace: kube-system
stringData:
  token: "<hetzner_api_token>"
  network: "<hetzner_network_id>"
---
apiVersion: v1
kind: Secret
metadata:
  name: hcloud-csi
  namespace: kube-system
stringData:
  token: "<hetzner_api_token>"
EOF
```

### 3. Setup Kubernetes Resources (Flannel CNI and hcloud)

```
kubectl apply -f  https://raw.githubusercontent.com/hetznercloud/hcloud-cloud-controller-manager/master/deploy/v1.7.0.yaml

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

kubectl -n kube-system patch ds kube-flannel-ds --type json -p '[{"op":"add","path":"/spec/template/spec/tolerations/-","value":{"key":"node.cloudprovider.kubernetes.io/uninitialized","value":"true","effect":"NoSchedule"}}]'

kubectl -n kube-system patch deployment coredns --type json -p '[{"op":"add","path":"/spec/template/spec/tolerations/-","value":{"key":"node.cloudprovider.kubernetes.io/uninitialized","value":"true","effect":"NoSchedule"}}]'

kubectl apply -f https://raw.githubusercontent.com/kubernetes/csi-api/release-1.14/pkg/crd/manifests/csidriver.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes/csi-api/release-1.14/pkg/crd/manifests/csinodeinfo.yaml

kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/master/deploy/kubernetes/hcloud-csi.yml
```

## Join Worker Nodes

```
kubeadm join 135.181.28.86:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<sha-here>
```

If this wasn't recorded when calling kubeadm init command, use this command on the master node to get join command

```
kubeadm token create --print-join-command
```

## Installing Helm 3.0+ (if wanted on server, would recommend locally instead)

```
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -

echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt update && sudo apt -y install helm
```

## Setup Load Balancing

```
kubectl create namespace metallb

helm install metallb -n metallb stable/metallb
```

Create and Apply the metallb configmap

```
cat <<EOF |kubectl apply -f-
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb
  name: metallb-config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - <your.floating.ip.address>/32
EOF
```

## Adding the Nginx Ingress Controller

```
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update

kubectl create namespace nginx-ingress
helm install nginx-ingress -n nginx-ingress nginx-stable/nginx-ingress
```
	  
## To Test Ingress Working

```
cat <<EOF |kubectl apply -f-
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minimal-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: "fireshellstudio.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: beanie-kiosk-service
            port:
              number: 3000
  - host: "www.fireshellstudio.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: beanie-kiosk-service
            port:
              number: 3000
  - host: "float.fireshellstudio.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: beanie-kiosk-service
            port:
              number: 3000
  - host: "master.fireshellstudio.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: beanie-kiosk-service
            port:
              number: 3000
  - host: "worker1.fireshellstudio.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: beanie-kiosk-service
            port:
              number: 3000
EOF
```