# How I installed Kubernetes in Ubuntu 19.04

## Intentions: A Note to the reader
This article is not to discuss Kubernetes and why you should use [Kubernetes](https://kubernetes.io/docs/concepts/overview/what-is-kubernetes/) for managing your containerized applications.

This is an explaination of the steps I made to install my Kubernetes Cluster and what I learned along the way.  I hope this allows others to learn from my work.  I've included a script to quickly install kubernetes.  You can bypass this section if you're only interested in getting Kubernetes running for a learning environment.

> Dislaimer: I maintain that I haven't covered all the necessary topics to encourage the release of a production kubernetes installation with only the information posted in this article.

## Obtaining and Setting Up Servers

I used servers on Vultr.com for my Kubernetes deployment and installation learning.  They charge fractions of a cent per hour per server and you can bring up and tear down however many servers you want as needed without accruing additional charges.

Kubernetes requires at least 2 cpus per server.  They run at $20 per month ($0.03 per hour).

I bought 3 servers, 1 server at 2 cpus for the master node and 2 servers with 1 cpu for the worker nodes.  (Mostly to see if they would still work.)

Once you created a Vultr account, Click "Deploy New Server" (It's now a blue plus near the upper right side of the site.)  Aqcuire the servers as needed.  (One master and however many preferred worker nodes).  In the Settings, Change to OS to Ubuntu 19.04.  You can locate the server ip address and root user password for each server in the server's details page.

## Install and Run Docker (On each server)

### Installing Docker

To [install Docker](https://docs.docker.com/v17.09/engine/installation/linux/docker-ce/ubuntu/) start by updating apt and installing the following packages.
```
apt update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
```

Get the docker gpg key and install the docker-ce package.  You can check the Add a daemon.json file to the etc/docker/ directory.  This will get setup docker on your target machine.

```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
apt update
apt install -y docker-ce

cat > /etc/docker/daemon.json << EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2"
}
EOF
```

> Tip: Verify the fingerprint is `9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88` using the following command.
> `sudo apt-key fingerprint 0EBFCD88`

It may be a good idea to restart docker.

```
systemctl daemon-reload
systemctl restart docker
```

> Ref: https://docs.docker.com/install/linux/docker-ce/ubuntu

## Installing and Deploying Kubernetes

Install apt-transport and curl to get the kubernetes gpg key.  Add the kubernetes repository.  Then install the kubelet, kubeadm, and kubectl packages.

```
apt update
apt install -y \
    apt-transport-https \
    curl
    
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    
apt-add-repository “deb http://apt.kubernetes.io/ kubernetes-xenial main”

apt update
apt install -y \
    kubelet \
    kubeadm \
    kubectl
```

Mark the kubelet, kubeadm and kubectl packages to hold their current version.

```
apt-mark hold kubelet kubeadm kubectl
```

[SWAP](https://wiki.archlinux.org/index.php/Swap) has to be disabled for kubernetes to route correctly.

```
swapoff -a
```

Give your server a unique hostname.

```
hostnamectl set-hostname [yourhostname]
```

> replace [yourhostname] with a unique hostname for this server.



### For Installing Kubernetes On Master -- Only

The following command will initialize the Kubernetes cluster.

```
apiserveraddr=$(hostname -I | cut -d' ' -f1)
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$apiserveraddr
```

**If successfully executed, there will be a `kubeadm join` command printed to the console.  Save this command for the "Joining Kubernetes Servers" section.**

After this is done, there are a few commands that require a sudo user.  [Create a new user](https://www.digitalocean.com/community/tutorials/how-to-add-and-delete-users-on-ubuntu-16-04) if you don't already have one.  Run the following commands from the sudo user account.

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Install [networking pods](https://kubernetes.io/docs/concepts/cluster-administration/addons/).  I used flannel for my installation.

```
 https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
```

Expose firewall ports [used by kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) and the kubelet API and the Kubernetes API server.

```
sudo ufw allow ssh
sudo ufw default deny outgoing
sudo ufw default deny incoming
sudo ufw --force enable
sudo ufw allow 6443
sudo ufw allow 2379/tcp
sudo ufw allow 2380/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 10251/tcp
sudo ufw allow 10252/tcp
```

### For Installing Kubernetes on Worker Nodes -- Only

Expose firewall ports for the kubelet API

```
sudo ufw allow ssh
sudo ufw default deny outgoing
sudo ufw default deny incoming
sudo ufw --force enable
sudo ufw allow 10250/tcp
```

[Optionally] Install the ports used by NodePort Services.  I personally use an ingress to direct traffic and don't expose NodePort services.

```
sudo ufw allow 30000:32767/tcp
```

> Ref: https://vitux.com/install-and-deploy-kubernetes-on-ubuntu/

## Joining Kubernetes Servers

By executing the `kubeadm join` command (saved from the previous step) on the worker nodes, we can add the worker nodes to our Kubernetes Cluster.

> If you missed the `kubeadm join` command, you can generate a new token and print the join command with this `kubeadm token create --print-join-command`

> Ref: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-token/

You can verify this worked by executing the following command as the sudo user in the master node.

```
kubectl get nodes
```

## Running the Setup Script

I created a script to help deploy my Kubernetes Cluster quicker.  There are variable and flags that can be provided to install Kubernetes for the correct node type.

### For Installing the Master Node

Here is the command to run the script with arguments for installing the master node.

```
curl -Ls https://raw.githubusercontent.com/stephenwike/kubernetes-install/master/k8s.sh | bash -s -- -m -h [hostname] -u [username] -p [password]
```

`-m` sets a flag to install Kubernetes for the master node.

`-h [hostname]` specifies the unique host name for this machine.  Replace [hostname] with your unique hostname

`-u [username]` specifies the user account used to deploy the kubernetes cluster.  A new user will be added if one doesn't exist. Replace [username] with the user account that will be used to deploy the kubernetes cluster.

`-p [password]` specifies the password the the user account listed above. Replace [password] with you users password

### Installing Worker Nodes

This is the installation script for installing a worker node.  The only variable supplied is the hostname which is required to be unique.

```
curl -Ls https://raw.githubusercontent.com/stephenwike/kubernetes-install/master/k8s.sh | bash -s -- -h [hostname]
```

> Make sure to run the `kubeadm install` command described above to join the new worker node into the Kubernetes cluster.

## Additional Reference

> Ref: https://kubernetes.io/docs/setup/production-environment/container-runtimes/

## Opportunities for Additional Coverage

// A missed step setting up docker ??
mkdir -p /etc/systemd/system/docker.service.d

// Used to permanently disable SWAP
sed 's/^UUID/#&/' /etc/fstab | tee /etc/fstab 

Ref: Example by Michael Hausenblas detailed and accessible guide.