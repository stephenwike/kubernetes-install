# Setting Up Home Network - 8/16/2020

 - Uses Dynamic DNS for resolving dynamic IP
 - Assumed fresh installation of Ubuntu (Using 20.04.1 ServerLTS)

## Install SSH

On the home network maching Install SSH.

```
sudo apt update
sudo apt install -y openssh-server
```

Check SSH Status.

```
sudo systemctl status ssh
```

Enter `q` to quit.

Open ssh port on firewall.

```
sudo ufw allow ssh
```

## Get Machine Ip Address

Get the machine IP address.  Assuming using ISP (dynamic IP), do this whenever the ip address changes.

```
ip a
```




