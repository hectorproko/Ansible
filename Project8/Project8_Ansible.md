# Project 8


``` bash
hector@hector-Laptop:~/Ansible/Project8$ tree
.
├── LBconfigure #Configuration file that gets generated by plays.sh
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

This playbook provisions resources from AWS same as Project 7 with some additions/changes  

First change is to the **Security Group** applied to **Web** servers. Name changed to reflect project 8 and HTTP connections are now restricted to a subnet since the servers only need communication from the Load Balancer
``` bash
   - name: Create Security Group Web Server
      ec2_group:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        name: "Project8_web" #<<
        description: "Security Group for Project 8 web servers"
        vpc_id: "{{ default_vpc.vpcs[0].vpc_id }}"
        rules:
          - proto: "tcp" 
            ports: "22"
            cidr_ip: 0.0.0.0/0
          - proto: "tcp"
            ports: "80" #<<
            cidr_ip: 172.31.80.0/20 #<<
      register: Project8_web
```

When provisioning our Web instances we are requesting **2 instead of 1** and reference to a new Security Group **Project8_web**
``` bash
    - name: WebServer
      ec2:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        image: "{{ latest_ami.image_id }}"
        instance_type: t2.micro
        key_name: "{{ ssh_keyname }}"
        count: 2 #number of instnaces to launch
        state: present
        group_id: "{{ Project8_web.group_id }}" #<<
        wait: yes
        vpc_subnet_id: "{{ subnet }}"
        assign_public_ip: yes
        instance_tags:
          Name: web7 #Name tag, 7 for project 7
      register: ec2web
```

Using module **set_fact:** to create variables to store IPs to later output them with module **debug**. They need to show in console output so **play.sh** can extract them. *Use of variables is not necessary to output IPs to console*

``` bash
    - name: Setting facts so that they will be persisted in the fact cache
      set_fact:
        webIP: ec2web.instances[0].private_ip
        
    - name: Setting facts so that they will be persisted in the fact cache
      set_fact:
        webIP2: ec2web.instances[1].private_ip
        
    - name: Output web1 Private IP
      debug:
        var: "{{ webIP }}"
        
    - name: Output web2 Private IP
      debug:
        var: "{{ webIP2 }}"
```
A **Security Group** for the **Load Balancer** named **Project8_LB**
``` bash
    - name: Create Security Group Apache LB
      ec2_group:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        name: "Project8_LB"
        description: "Security Group for Apache LB server"
        vpc_id: "{{ default_vpc.vpcs[0].vpc_id }}"
        rules:
          - proto: "tcp" 
            ports: "22" #remote using ssh
            cidr_ip: 0.0.0.0/0
          - proto: "tcp"
            ports: "80" #http
            cidr_ip: 0.0.0.0/0
      register: Project8_LB
```
Provisioning an instance for the role of **Load Balancer**. We are hardcoding the image id to use **Ubuntu** and reference the corresponding Security Group **Project8_LB**
``` bash
    - name: Ubuntu Apache LB
      ec2:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        image: ami-04505e74c0741db8d # Ubuntu 64-bit x86
        instance_type: t2.micro
        key_name: "{{ ssh_keyname }}"
        count: 1
        state: present
        group_id: "{{ Project8_LB.group_id }}"
        wait: yes
        vpc_subnet_id: "{{ subnet }}"
        assign_public_ip: yes
        instance_tags:
          Name: LB
      register: ec2nfs
```
## NFS+WEB_configure.yml
The playbook that configures NFS and Web servers also has few changes  

The variable that stores NFS server's IP is now **nfsIP** instead of PrivateIP.
```bash
        - name: Mount apps #fails if NFS server is not up
          ansible.posix.mount:
            path: /var/www
            src: "{{ nfsIP }}:/mnt/apps" #NFS server PrivateIP
            fstype: nfs
            opts: rw,nosuid
            state: mounted #this mounts it
```

We mount an additional directory for logs. All web servers log in one central place
```bash
        - name: Mount logs #fails if NFS server is not up
          ansible.posix.mount:
            path: /var/log/httpd/
            src: "{{ nfsIP }}:/mnt/logs" #NFS server PrivateIP
            fstype: nfs
            opts: rw,nosuid
            state: mounted #this mounts it
```

## LBconfigure.yml

We load our target **hosts:** with Load Balancer instance tagged **LB**. Remote user is now **ubuntu** because we are using **Ubuntu** OS
``` bash
- name: Start Configuring LB #Second Play
  hosts: _LB 
  gather_facts: false
  remote_user: ubuntu #we need user for Ubuntu OS
```
Importing some variables from **info.yml**
``` bash
  vars_files:
    - /etc/ansible/vars/info.yml
```

Installing software using module **apt**
``` bash
    - name: Install a list of packages
      apt:
        update_cache : yes
        pkg:
        - apache2
        - libxml2-dev
```

Enabling Apache2 modules with **apache2_module**
``` bash
    - name: Enable the Apache2 modules
      community.general.apache2_module:
        state: present
        name: "{{ item }}"
      loop: #List of modules to loop
        - rewrite
        - proxy
        - proxy_http
        - headers
        - lbmethod_bytraffic
      ignore_errors: yes  
```
Using module **copy** to create a backup of  **000-default.conf** before overwriting it with out configuration in **LBconfigure** 
``` bash
    - name: 000-default.conf Backup
      ansible.builtin.copy:
        src: /etc/apache2/sites-available/000-default.conf
        dest: /etc/apache2/sites-available/000-default.confBAK
        remote_src: yes
        owner: ubuntu
        group: ubuntu
        mode: '0644'

    - name: Input Config File
      ansible.builtin.copy:
        src: LBconfigure
        dest: /etc/apache2/sites-available/000-default.conf
        owner: ubuntu
        group: ubuntu
        mode: '0644'
```
Restarting apache2
``` bash
    - name: Restart apache2
      ansible.builtin.systemd:
        state: restarted
        name: apache2
      ignore_errors: yes  
```

