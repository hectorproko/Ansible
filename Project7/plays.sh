output=$(sudo ansible-playbook provisioning.yml)
IP=$(echo $output | grep private_ip | cut -d '"' -f 4) #gets IP from output
sudo ansible-playbook NFSconfigure.yml
sudo ansible-playbook webConfigure.yml --extra-vars "privateIP=$IP" 

IP=$(echo $output | grep private_ip | cut -d '"' -f 4)

#ansible-playbook partest.yml --extra-vars "privateIP='$IP'” #works
#ansible-playbook partest.yml --extra-vars "privateIP=$IP” #works
#ansible-playbook partest.yml --extra-vars 'privateIP=$IP' #doesnt work
#ansible-playbook partest.yml --extra-vars 'privateIP="$IP"' #doesnt work

#cat output.txt | grep private_ip | cut -d '"' -f 4