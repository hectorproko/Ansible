
clear
output=$(sudo ansible-playbook provisioning.yml)
echo "$output"
webIP=$(echo "$output" | grep "ec2web.instances\[0].private_ip" | cut -d '"' -f 4) #gets IP from output \ to escape
webIP2=$(echo "$output" | grep "ec2web.instances\[1].private_ip" | cut -d '"' -f 4) #gets IP from output
nfsIP=$(echo "$output" | grep "ec2nfs.instances\[0].private_ip" | cut -d '"' -f 4) #gets IP from output

echo "IPs $webIP $webIP2 $nfsIP"

# Need to escape variable inside with backslash
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
# Creating the file  with configuration
echo "$config" > LBconfigure

# sudo ansible-playbook webConfigure.yml --extra-vars "nfsIP=$nfsIP"
# sudo ansible-playbook NFS+WEB+LB_configure.yml --extra-vars "nfsIP=$nfsIP"
sudo ansible-playbook NFS+WEB_configure.yml --extra-vars "nfsIP=$nfsIP"
sudo ansible-playbook LBconfigure.yml
