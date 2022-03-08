
clear
output=$(sudo ansible-playbook provisioning.yml)
IP=$(echo "$output" | grep "0].private_ip" | cut -d '"' -f 4) #gets IP from output
IP2=$(echo "$output" | grep "1].private_ip" | cut -d '"' -f 4) #gets IP from output

echo "IPs $IP $IP2"

config=$(cat << EOF
\<VirtualHost *:80>
    <Proxy "balancer://mycluster">
        BalancerMember http://$IP:80 loadfactor=5 timeout=1
        BalancerMember http://$IP2:80 loadfactor=5 timeout=1
        ProxySet lbmethod=bytraffic
        # ProxySet lbmethod=byrequests
    </Proxy>
                ProxyPreserveHost On
                ProxyPass / balancer://mycluster/
                ProxyPassReverse / balancer://mycluster/

        #ServerAdmin webmaster@localhost
        #DocumentRoot /var/www/html
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
)
#Creating the file  with configuration
echo "$config" > LBconfigure

sudo ansible-playbook LBconfigure.yml