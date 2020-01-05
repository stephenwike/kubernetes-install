# How I installed Kubernetes in Ubuntu 19.04

> https://docs.docker.com/install/linux/docker-ce/ubuntu

## Obtaining and Setting Up Servers

TODO: ...

## Install and Run Docker (On each server)

> https://docs.docker.com/v17.09/engine/installation/linux/docker-ce/ubuntu/

sudo apt update
    sudo apt-get install \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    # TODO: Validate fingerprint - https://docs.docker.com/v17.09/engine/installation/linux/docker-ce/ubuntu/#set-up-the-repository
    sudo add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
    sudo apt update
    sudo apt install -y docker-ce

##




```
apt update

apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
    
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt update

apt install docker-ce docker-ce-cli containerd.io

## https://kubernetes.io/docs/setup/production-environment/container-runtimes/
## Setup daemon.
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

mkdir -p /etc/systemd/system/docker.service.d

## Restart docker.

systemctl daemon-reload
systemctl restart docker

## Install and Run CRI-O

apt update
add-apt-repository ppa:projectatomic/ppa -y

apt update
apt install -y cri-o-1.15

systemctl daemon-reload
systemctl start crio

# Add the Kubernetes source packages

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

# Perform a packages update

echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" \
  | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
apt update 

# Install kubeadm

apt install kubeadm -y

## Disable SWAP

sudo swapoff -a

## Give unique hostnames

hostnamectl set-hostname $nodename


# Master

kubeadm init --pod-network-cidr=10.244.0.0/16

### Open Ports
sudo ufw allow ssh
sudo ufw default deny outgoing
sudo ufw default deny incoming
sudo ufw enable
sudo ufw allow 6443
sudo ufw allow out on weave to 10.32.0.0/12
sudo ufw allow in on weave from 10.32.0.0/12
sudo ufw allow 6783/udp
sudo ufw allow 6784/udp
sudo ufw allow 6783/tcp
sudo ufw allow 2379/tcp
sudo ufw allow 2380/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 10251/tcp
sudo ufw allow 10252/tcp

# Nodes
sudo ufw allow ssh
sudo ufw default deny outgoing
sudo ufw default deny incoming
sudo ufw enable
sudo ufw allow 10250/tcp

--------------------
--------------------- ARCHIVE
---------------------


# Install kubelet, kubeadm and kubernetes-cni

sudo apt-get update \
  && sudo apt-get install -yq \
  kubelet \
  kubeadm \
  kubernetes-cni
  
# Hold Kubernetes packages

sudo apt-mark hold kubelet kubeadm kubectl

# Disable SWAP

sed 's/^UUID/#&/' /etc/fstab | tee /etc/fstab 


# Master only steps

# Weave net

# apt install net-tools (do I need this command?)

apiserveraddr=$(hostname -I)
sudo kubeadm init --apiserver-advertise-address=$apiserveraddr

You'll get output like this if everything went to plan, if not, then check the steps above.

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.80.0.133:6443 --token xyzz.abcb494cnfj \
    --discovery-token-ca-cert-hash sha256:bf0108833a2cf083b5069e9dff1d502337c0538508975b039cba7d477c278c72 
Configure an unprivileged user-account
Packet's Ubuntu installation ships without an unprivileged user-account, so let's add one.

$ sudo useradd packet -G sudo -m -s /bin/bash
$ sudo passwd packet
Configure environmental variables as the new user
You can now configure your environment with the instructions at the end of the init message above.

Switch into the new user account and configure the KUBECONFIG

sudo su packet

cd $HOME
sudo cp /etc/kubernetes/admin.conf $HOME/
sudo chown $(id -u):$(id -g) $HOME/admin.conf
Now try out the KUBECONFIG file:

echo "export KUBECONFIG=$HOME/admin.conf" | tee -a ~/.bashrc
source ~/.bashrc
Try a kubectl command to see if the master node is now listed, note it will be in a NotReady status for the time being

$ kubectl get node
NAME               STATUS     ROLES    AGE     VERSION
k8s-bare-metal-1   NotReady   master   3m32s   v1.16.3
Apply your Pod networking (Weave net)
We will now apply configuration to the cluster using kubectl and our new KUBECONFIG file. This will enable networking and our master node will become Ready, at that point we'll move onto the other worker hosts.

sudo mkdir -p /var/lib/weave
head -c 16 /dev/urandom | shasum -a 256 | cut -d" " -f1 | sudo tee /var/lib/weave/weave-passwd

kubectl create secret -n kube-system generic weave-passwd --from-file=/var/lib/weave/weave-passwd
Since we are using the default Pod network for host networking, we need to use a different private subnet for Weave net to avoid conflicts. Fortunately the 192.168.0.0/24 space is available for use.

$ kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&password-secret=weave-passwd&env.IPALLOC_RANGE=192.168.0.0/24"
We've now configured networking for pods.

Optional step - taint the master
Kubernetes aims to be a highly available clustering container orchestrator where workloads are spread out over multiple hosts with redundancy. We can however force a single master node to run workloads for development by removing its "taint":

This is only recommended if you are running with a single host, do not run this step if you are adding other hosts into the cluster.

$ kubectl taint nodes --all node-role.kubernetes.io/master-
Join the other hosts
When we ran kubeadm init on the master node, it outputted a token which is valid for 24-hours. We now need to use that to join other hosts.

kubeadm join 10.80.0.133:6443 --token xyzz.abcb494cnfj  --discovery-token-ca-cert-hash sha256:bf0108833a2cf083b5069e9dff1d502337c0538508975b039cba7d477c278c72
If you receive an error at this point, it's likely because you forgot a step above. Rememebr that you need to turn off swap memory for every host, not just the master.

Perform the join step on every host.

Move back to the ssh session for the master node where you are logged in as the packet unprivileged user.

You should see all your nodes in the Ready status now.

$ kubectl get node
NAME                STATUS   ROLES    AGE    VERSION
k8s-bare-metal-02   Ready    <none>   113s   v1.16.3
k8s-bare-metal-03   Ready    <none>   10s    v1.16.3
k8s-bare-metal-1    Ready    master   15m    v1.16.3
Test the cluster
Check it's working
Many of the Kubernetes components run as containers on your cluster in a hidden namespace called kube-system. You can see whether they are working like this:

NAME                                           READY   STATUS    RESTARTS   AGE
pod/coredns-5644d7b6d9-vwhvb                   1/1     Running   0          16m
pod/coredns-5644d7b6d9-xgn4b                   1/1     Running   0          16m
pod/etcd-k8s-bare-metal-1                      1/1     Running   0          15m
pod/kube-apiserver-k8s-bare-metal-1            1/1     Running   0          15m
pod/kube-controller-manager-k8s-bare-metal-1   1/1     Running   0          15m
pod/kube-proxy-29j7n                           1/1     Running   0          67s
pod/kube-proxy-j5bzn                           1/1     Running   0          2m50s
pod/kube-proxy-p444z                           1/1     Running   0          16m
pod/kube-scheduler-k8s-bare-metal-1            1/1     Running   0          15m
pod/weave-net-bgkwp                            2/2     Running   0          67s
pod/weave-net-gmr88                            2/2     Running   0          2m50s
pod/weave-net-td9hm                            2/2     Running   0          7m40s

NAME               TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
service/kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   16m

NAME                        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                 AGE
daemonset.apps/kube-proxy   3         3         3       3            3           beta.kubernetes.io/os=linux   16m
daemonset.apps/weave-net    3         3         3       3            3           <none>                        7m40s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coredns   2/2     2            2           16m

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/coredns-5644d7b6d9   2         2         2       16m
As you can see all of the services are in a state of Running which indicates a healthy cluster. If these components are still being downloaded from the Internet they may appear as not started.

You can also run kubectl get all --all-namespaces. A shortcut for --all-namespaces is -A.

$ kubectl get svc -A
NAMESPACE     NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
default       kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP                  17m
kube-system   kube-dns     ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   17m
Run a container
You can now run a container on your cluster. Kubernetes organises containers into Pods which share a common IP address, are always scheduled on the same node (host) and can share storage volumes.

First check you have no pods (containers) running with:

$ kubectl get pods
I wrote a sample application to show developers how to package a Node.js and Express.js microservice. It's called alexellis/expressjs-k8s and you can star or fork it on GitHub.

Let's install it using its helm chart which uses the new Helm 3 release. Helm is used to package Kubernetes manifest YAML files. These YAML files offer a way of packaging an application using a declarative approach.

If you're using MacOS or Linux simply run the below:

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
If you're a Windows user, then install Git Bash and then run the above in a new terminal.

As of Helm 3, each project manages its own repository for charts published either to S3 or GitHub Pages. Let's add the repo for expressjs-k8s and then perform a sync.

# First add the helm repo
helm repo add expressjs-k8s https://alexellis.github.io/expressjs-k8s/

# Then run an update
helm repo update

# And finally install
helm install test-app expressjs-k8s/expressjs-k8s
You can now view the events from the Kubernetes API and see the container image for the microservice being pulled in from the Internet and scheduled on one of the nodes.

$ kubectl get events --sort-by=.metadata.creationTimestamp -w

11s         Normal    Scheduled                 pod/test-app-expressjs-k8s-75667c6649-6hjft    Successfully assigned default/test-app-expressjs-k8s-75667c6649-6hjft to k8s-bare-metal-02
11s         Normal    ScalingReplicaSet         deployment/test-app-expressjs-k8s              Scaled up replica set test-app-expressjs-k8s-75667c6649 to 1
11s         Normal    SuccessfulCreate          replicaset/test-app-expressjs-k8s-75667c6649   Created pod: test-app-expressjs-k8s-75667c6649-6hjft
10s         Normal    Pulling                   pod/test-app-expressjs-k8s-75667c6649-6hjft    Pulling image "alexellis2/service:0.3.5"
5s          Normal    Pulled                    pod/test-app-expressjs-k8s-75667c6649-6hjft    Successfully pulled image "alexellis2/service:0.3.5"
5s          Normal    Created                   pod/test-app-expressjs-k8s-75667c6649-6hjft    Created container expressjs-k8s
4s          Normal    Started                   pod/test-app-expressjs-k8s-75667c6649-6hjft    Started container expressjs-k8s

# Hit Control + C when done
The helm chart outputs some information on how to access the service:

Check the deployment status:

  kubectl rollout status -n default deploy/test-app-expressjs-k8s

Now port-forward the service to test it out:

  kubectl port-forward -n default deploy/test-app-expressjs-k8s 8088:8080 &

Try to connect with a browser:

  http://127.0.0.1:8088
Run the port-forward command and then access the service via curl:

curl   http://127.0.0.1:8088
curl   http://127.0.0.1:8088/api/links
You can find out which node the Pod is running on like this:

$ kubectl get pod -o wide
NAME                                      READY   STATUS    RESTARTS   AGE   IP              NODE             
test-app-expressjs-k8s-75667c6649-6hjft   1/1     Running   0          83s   192.168.0.193   k8s-bare-metal-02
If you like, you can scale the amount of Pods available, at this point, running the previous command should spread the pods across the two worker nodes that I created.

$ kubectl get deploy
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
test-app-expressjs-k8s   1/1     1            1           2m30s

$ kubectl scale deploy/test-app-expressjs-k8s --replicas=2 
deployment.apps/test-app-expressjs-k8s scaled
Now we have high-availability for our microservice:

$ kubectl get pod -o wide
NAME                                      READY   STATUS    RESTARTS   AGE   IP              NODE             
NAME                                      READY   STATUS    RESTARTS   AGE     IP              NODE             
test-app-expressjs-k8s-75667c6649-6hjft   1/1     Running   0          3m16s   192.168.0.193   k8s-bare-metal-02
test-app-expressjs-k8s-75667c6649-v28wl   1/1     Running   0          26s     192.168.0.241   k8s-bare-metal-03
View the Dashboard UI
The Kubernetes dashboard offers a visual representation of the resources in the cluster and it can be accessed from your local computer too.

When we initialized the clsuter earlier we chose to advertise only on the local network, so we'll need to connect over ssh with port-forwarding to view the dashboard after deploying it.

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml
Check its status:

$ kubectl get deploy/kubernetes-dashboard -n kubernetes-dashboard
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
kubernetes-dashboard   1/1     1            1           25s
Reconnect to the master with a tunnel to our local computer:

export IP="master-node-ip"

$ ssh -L 8001:127.0.0.1:8001 root@$IP
$ # sudo su packet

$ kubectl proxy &
Since the dashboard shows us resources across our whole cluster, we will need to create an admin account for it.

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF
Then run:

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
Now we need to find token we can use to log in. Execute following command:

kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
Now copy the token and paste it into Enter token field on login screen.

Now navigate to http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#!/login/ in a web-browser.

The dashboard can show objects in any namespace, but starts off by presenting the default namepsace where we deployed our microservice earlier using helm.

Here are the two replicas of the Node.js microservice running on our two worker nodes:

pods

And here we can see our three nodes in the cluster:

nodes

Find out more on GitHub: kubernetes/dashboard.

For alternatives to the Kubernetes dashboard see also:

Weave Cloud - an insightful SaaS monitoring product from Weaveworks which has long-term storage and can be accessed from anywhere.
Octant - from VMware and designed from the ground up, you can run this on your local computer
Wrapping up
You've now created a Kubernetes cluster and run your first microservice in Node.js using helm. From here you can start to learn all the components that make up a cluster and explore tutorials using the kubectl CLI.

Add more nodes

Now that you've provisioned your single-node cluster with Packet - you can go ahead and add more nodes with the join token you got from kubeadm.

Learn by example

I found Kubernetes by Example by Michael Hausenblas to be a detailed and accessible guide.

Read my highlights from KubeCon, San Diego - OpenFaaS Cloud, Flux, Linkerd, k3s goes GA and more!

Our KubeCon San Diego Highlights

Deploy the Cloud Native PLONK Stack

You may have heard of the LAMP stack for Linux, Apache, MySQL and PHP? The PLONK Stack is designed to power application deployments on Kubernetes by using several of the most popular cloud native projects together - Prometheus Linux/Linkerd OpenFaaS NATS and Kubernetes.

Read the article: Introducing the PLONK Stack

## Running the Setup Script

bash <(curl -Ls https://raw.githubusercontent.com/stephenwike/kubernetes-install/master/k8s.sh)