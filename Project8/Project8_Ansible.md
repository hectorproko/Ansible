# Project 8


``` bash
hector@hector-Laptop:~/Ansible/Project8$ tree
.
├── LBconfigure #Configuration file that gets generated
├── LBconfigure.yml
├── NFS+WEB_configure.yml
├── plays.sh
├── provisioning.yml
```

## plays.sh 
We are going to use bash script to coordinate the execution of **playbooks**  
  
Here we are putting the output of running playbook **provisioning.yml** in a variable

``` bash
output=$(sudo ansible-playbook provisioning.yml)
echo "$output" #Putting the contents of the variable on the console to see
```

Using **grep** to search IPs from variable **$output** and storing them in variables
``` bash
webIP=$(echo "$output" | grep "ec2web.instances\[0].private_ip" | cut -d '"' -f 4) 
webIP2=$(echo "$output" | grep "ec2web.instances\[1].private_ip" | cut -d '"' -f 4) 
nfsIP=$(echo "$output" | grep "ec2nfs.instances\[0].private_ip" | cut -d '"' -f 4) 

echo "IPs $webIP $webIP2 $nfsIP"
```
A variable **config** with the Load Balancer configuration using 2 variables containing IPs **$webIP**, **$webIP2**
``` bash
config=$(cat << EOF
<VirtualHost *:80>
    <Proxy "balancer://mycluster">
        BalancerMember http://$webIP:80 loadfactor=5 timeout=1
        BalancerMember http://$webIP2:80 loadfactor=5 timeout=1
        ProxySet lbmethod=bytraffic
        # ProxySet lbmethod=byrequests
    </Proxy>
    ProxyPreserveHost On
    ProxyPass / balancer://mycluster/
    ProxyPassReverse / balancer://mycluster/

    # ServerAdmin webmaster@localhost
    # DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
)
```
This generates a configuration file **LBconfigure** but with actual IPs address assuming the variables are not null
``` bash
echo "$config" > LBconfigure

Example:
        BalancerMember http://172.31.95.135:80 loadfactor=5 timeout=1
        BalancerMember http://172.31.90.78:80 loadfactor=5 timeout=1

```

Here we are calling the other two playbooks passing the NFS server's Private IP address as a parameter in the form of a variable **$nfsIP**. The playbook **NFS+WEB_configure.yml** will store the contents of that variable in a variable of its own also called **nfsIP**
``` bash
sudo ansible-playbook NFS+WEB_configure.yml --extra-vars "nfsIP=$nfsIP"
sudo ansible-playbook LBconfigure.yml
```

## provisioning.yml

This playbook provisions resources from AWS same as Project 7 with some additions

``` bash

```

## NFS+WEB_configure.yml
## LBconfigure.yml

