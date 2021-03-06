#!/bin/bash
usage() {
    cat << _EOF_

    usage: .\k8s.sh [variables value] [flags]

    Type                            Description                                     Default

    Variables
    -h | --host                     assigns host name to machine                    node-default
    -i | --ip                       tracks the host machine's up address.           -queried
    -u | --username                 assigns username for ubuntu account             default
    -p | --password                 uses this password for ubuntu account           default

    Flags                           
    -m | --master                   Initializes the cluster as master               False
    -d | --skip-docker              Skips installation of docker                    False
    -k | --skip-kubernetes          Skips installation of kubernetes                False
         --help                     Runs the usage command


    Recommend specifying all arguments for best results.  Use flags as needed
    (e.g.) ./k8s.sh --host master-node --username myUser --password myPass -m

_EOF_
}

parse_arguments() {
    echo "Parsing Arguments"
    echo "$# arguments provided"
    echo "$@"

    hostname=node-default
    username=default
    password=default

    isMaster=0
    
    while [ "$1" != "" ]; do
        case $1 in
            -h | --host )               shift
                                        hostname=$1
                                        ;;
            -u | --username )           shift
                                        username=$1
                                        ;;
            -p | --password )           shift
                                        password=$1
                                        ;;
            -m | --master )             isMaster=1
                                        ;;
            --help )                    usage
                                        exit
                                        ;;
            * )                         echo "Incorrect Usage:"
                                        usage
                                        exit 1
        esac
        shift
    done

    echo "Hostname: $hostname"
}

install_docker() {
    echo "Installing Docker"

    apt update
    apt install -y apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common
    
    # Docker's Official GPG Key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    
    add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"

    apt update
    apt install -y docker-ce \
        docker-ce-cli \
        containerd.io

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
    
    systemctl daemon-reload
    systemctl restart docker
}

install_kubernetes() {
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
    swapoff -a
    hostnamectl set-hostname $hostname
}

deploy_kubernetes() {
    echo "Deploying Kubernetes for master node"

    
    apiserveraddr=$(hostname -I | cut -d' ' -f1)
    echo "APIServerAddress: $apiserveraddr"
    kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$apiserveraddr

    adduser $username --gecos "$username,,," --disabled-password
    echo "$username:$password" | chpasswd
    
    mkdir -p /home/$username/.kube
    cp -i /etc/kubernetes/admin.conf /home/$username/.kube/config
    chown $username:$username /home/$username/.kube/config
    runuser -l $username -c "kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"

    ufw allow ssh
    ufw default deny outgoing
    ufw default deny incoming
    ufw --force enable
    ufw allow 6443
    ufw allow 2379/tcp
    ufw allow 2380/tcp
    ufw allow 10250/tcp
    ufw allow 10251/tcp
    ufw allow 10252/tcp
}

configure_pod() {
    ufw allow ssh
    ufw default deny outgoing
    ufw default deny incoming
    ufw --force enable
    ufw allow 10250/tcp
}

### MAIN ------------------------------------
parse_arguments $@

/bin/bash ./setup-host.sh $hostname

/bin/bash ./install-docker.sh

/bin/bash ./install-kubernetes.sh

if [ $isMaster -eq 1 ]
then 
    /bin/bash ./init-kubernetes.sh $username $password
fi
### END MAIN ----------------------------------
