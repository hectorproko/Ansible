

output=$(sudo ansible-playbook provisioning.yml)
echo "$output"
IP=$(echo $output | grep private_ip | cut -d '"' -f 4) #gets IP from output
sudo ansible-playbook NFSconfigure.yml
sudo ansible-playbook webConfigure.yml --extra-vars "privateIP=$IP" 

#IP=$(echo $output | grep private_ip | cut -d '"' -f 4)
#sudo ansible-playbook webConfigure.yml --extra-vars "privateIP=172.31.94.32" 
