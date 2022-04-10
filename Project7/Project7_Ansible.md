# Project 7


``` bash
hector@hector-Laptop:~/Ansible/Project7$ tree
.
├── NFS+WEB_configure.yml
└── provisioning.yml
```

## provisioning.yml
This playbook provisions resources from AWS
``` bash
- name: Start
  hosts: localhost #Target host is local 
  remote_user: Ansible #IAM created in AWS
  gather_facts: false
```
``` bash
  vars_files:
    - /etc/ansible/vars/info.yml #importing some variables ex aws credentials
```
``` bash
  tasks:
    - name: Choosing subnet 172.31.80.0/20 #A subnet I already had in aws 
      set_fact:
        subnet: subnet-18872839 #The subnet ID
```
Getting and saving info from an already existing VPC to use later
``` bash
    - name: Getting Default VPC
      amazon.aws.ec2_vpc_net_info:
        aws_access_key: "{{ aws_id }}" #<< variable from info.yml
        aws_secret_key: "{{ aws_key }}" #<<
        region: "{{ aws_region }}" #<<
        filters:
          "tag:Name": Default
      register: default_vpc #getting default VPC to reference later
```
Creating **Security Group** for instances acting as NFS and Database server
``` bash
    - name: Create Security Group NFS/DB
      ec2_group:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        name: "Project7_NFS"
        description: "Security Group for NFS/DB server"
        vpc_id: "{{ default_vpc.vpcs[0].vpc_id }}" #referencing vpc ID
        rules: # Opening ports
          - proto: "tcp" 
            ports: "22" #remote using ssh
            cidr_ip: 0.0.0.0/0
          - proto: "udp"
            ports: "111" #used with NFS
            cidr_ip: 172.31.80.0/20
          - proto: "tcp"
            ports: "111" #used with NFS
            cidr_ip: 172.31.80.0/20
          - proto: "tcp"
            ports: "2049" #NFS
            cidr_ip: 172.31.80.0/20
          - proto: "tcp"
            ports: "3306" #MYSQL
            cidr_ip: 172.31.80.0/20
      register: Project7_NFS #Saving security group info to reference for NFS
```
Creating **Security Group** for instances acting as Web Servers
``` bash
    - name: Create Security Group web
      ec2_group:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        name: "Project7_web"
        description: "Security Group for NFS/DB server"
        vpc_id: "{{ default_vpc.vpcs[0].vpc_id }}"
        rules:
          - proto: "tcp" 
            ports: "22" #remote using ssh
            cidr_ip: 0.0.0.0/0
          - proto: "tcp"
            ports: "80" #http
            cidr_ip: 0.0.0.0/0
      register: Project7_web #Saving security group info to reference for Web
```
Dynamically getting the AIM for Red Hat
``` bash
    - name: Find AMIs published by Red Hat (309956199498). Non-beta and x86
      ec2_ami_info:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        owners: 309956199498
        filters:
          architecture: x86_64
          name: RHEL-8*HVM-*
      register: amis

    - name: Get the latest one
      set_fact: #Getting latest Red Hat ami
        latest_ami: "{{ amis.images | sort(attribute='creation_date') | last }}"
```
Provisioning instance for NFS and Database server
``` bash
    - name: Provisioning NFS/DB Server
      ec2:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        image: "{{ latest_ami.image_id }}" #Referencing latest RedHat aim
        instance_type: t2.micro
        key_name: "{{ ssh_keyname }}" #Variable from info.yml
        count: 1
        state: present
        group_id: "{{ Project7_NFS.group_id }}" #Referencing the group id for NFS
        wait: yes
        vpc_subnet_id: "{{ subnet }}" #varible defined on top
        assign_public_ip: yes
        instance_tags:
          Name: NFS
      register: ec2nfs #NFS info variable
```
Creating EBS Volumes and attaching them to NFS Server
``` bash
    - name: Create EBS
      ec2_vol:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        volume_size: 10
        volume_type: gp2
        zone: us-east-1c
        delete_on_termination: true
        name: "{{ item.name }}" #< Looping
        device_name: "{{ item.mapping }}"#<
        instance: "{{ ec2nfs.instance_ids[0] }}" #Getting instance ID from NFS var
        state: present
      loop: #Dictionary loop
        - { name: 'Project7Ansible1', mapping: '/dev/xvdf' }
        - { name: 'Project7Ansible2', mapping: '/dev/xvdg' }
        - { name: 'Project7Ansible3', mapping: '/dev/xvdh' }
      register: ansibleEBS
```
``` bash
    - name: Output Private IP
      ansible.builtin.debug: #Outputing NFS private IP to console output
        msg: 'Trouble shooting IP string {{ ec2nfs.instances[0].private_ip }}'
```
Provisioning instance for Web Server
``` bash
    - name: WebServer
      ec2:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        image: "{{ latest_ami.image_id }}"
        instance_type: t2.micro
        key_name: "{{ ssh_keyname }}"
        count: 1 #number of instnaces to launch
        state: present
        group_id: "{{ Project7_web.group_id }}" #Security Group ID from web var
        wait: yes
        vpc_subnet_id: "{{ subnet }}" #var created on top for 172.31.80.0/20
        assign_public_ip: yes
        instance_tags:
          Name: web7 # 7 for project 7
      register: ec2web
 ```
Calling a playbook and passing it the private IP of NFS server
 ``` bash
    - name: Calling NFS/WEB configuration 
      command: sudo ansible-playbook NFS+WEB_configure.yml --extra-vars "privateIP={{ ec2nfs.instances[0].private_ip }}" 
```

## NFS+WEB_configure.yml
This playbook configures the instances previously provisioned with their respective roles

``` bash
- name: Start Configuring NFS & Web #Second Play
  hosts: _NFS, _web7 #Loading target hosts, identified with instance tag
  gather_facts: false
  remote_user: ec2-user #User to used with Red Hat
```

``` bash
  vars_files:
    - /etc/ansible/vars/info.yml
```
Simple ping test
``` bash
  tasks:
    - name: NFS Configure
      block:
        - name: Pinging NFS
          ping:
```
Partitioning drives using module **parted**
``` bash
        - name: Partitioning
          parted:
            device: "{{ item }}" #loop var
            number: 1
            state: present
            fs_type: ext4
          loop: #loop list
            - /dev/xvdf
            - /dev/xvdg
            - /dev/xvdh
``` 
Installing some packages
```bash
        - name: Install lvm2 dependency, nfs-utils
          package:
            name: 
              - lvm2
              - nfs-utils
              - git
            state: present

        - name: Start NFS on boot
          ansible.builtin.service:
            name: nfs-server
            enabled: yes
```

Creating **Volume Groups**,**Logical Volumes** and formating them. Using modules **lvg**, **lvol** and **filesystem**
``` bash
        - name: Create VG #Creating Volume Groups
          lvg:
            vg: "{{ item.vg }}"
            pvs: "{{ item.pvs }}"
          loop: #loop dictionary
            - { vg: 'vg-apps', pvs: '/dev/xvdf1'}
            - { vg: 'vg-logs', pvs: '/dev/xvdg1'}
            - { vg: 'vg-opt', pvs: '/dev/xvdh1'}

        - name: Create LV
          lvol:
            vg: "{{ item.vg }}"
            lv: "{{ item.lv }}"
            size: 100%FREE
            shrink: no
          loop:
            - { vg: 'vg-apps', lv: 'lv-apps'}
            - { vg: 'vg-logs', lv: 'lv-logs'}
            - { vg: 'vg-opt', lv: 'lv-opt'}
          ignore_errors: yes #for testing purposes, prevents the playbook run from stopping when an error occurs in this section
      
        - name: Format 
          filesystem:
            fstype: xfs #format the logical volumes as xfs 
            dev: "{{ item }}" #looping var
          loop:
            - /dev/vg-apps/lv-apps
            - /dev/vg-logs/lv-logs
            - /dev/vg-opt/lv-opt
```
Creating directories that we need to **mount**. Using modules **file** and **mount**
``` bash
        - name: Creating mounting directories
          file:
            path: "{{ item }}"
            state: directory
            owner: nobody
            group: nobody
            mode: '0777'
          loop:
            - /mnt/apps
            - /mnt/logs
            - /mnt/opt

        - name: Mount
          mount:
            path: "{{ item.dir}}"
            src: "{{ item.lv }}"
            fstype: xfs
            state: mounted
          loop:
            -  { dir: '/mnt/apps', lv: '/dev/vg-apps/lv-apps' }
            -  { dir: '/mnt/logs', lv: '/dev/vg-logs/lv-logs' }
            -  { dir: '/mnt/opt', lv: '/dev/vg-opt/lv-opt' }
```
``` bash
        # Restart to reload config
        - name: daemon-reload
          systemd:
            name: nfs-server
            state: restarted
            daemon_reload: yes
```

``` bash
        - name: exports 
          lineinfile:
            path: /etc/exports
            line: "{{ item }}"
          loop:         #subnet
            - /mnt/apps 172.31.80.0/20(rw,sync,no_all_squash,no_root_squash)
            - /mnt/logs 172.31.80.0/20(rw,sync,no_all_squash,no_root_squash)
            - /mnt/opt 172.31.80.0/20(rw,sync,no_all_squash,no_root_squash)

        - name: exportfs -arv
          shell:
            cmd: exportfs -arv
    
        - name: Changing dir owner/permission #running it once doesnt change owner/permission
          file:
            path: "{{ item }}"
            state: directory
            owner: nobody
            group: nobody
            mode: '0777'
          loop:
            - /mnt/apps
            - /mnt/logs
            - /mnt/opt
        
        - name: Git
          ansible.builtin.git:
            repo: 'https://github.com/hectorproko/tooling.git'
            dest: /home/ec2-user/tooling 

        - name: Copydir #This turns apps back to root
          command: cp -R /home/ec2-user/tooling/html /mnt/apps   
      
        #Database Configuration
        - name: Install MySQL
          package:
            name: 
              - mysql #do we need it? #this is client, will remove later after testing
              - mysql-server
            state: present

        - name: Start msyql
          ansible.builtin.service:
            name: mysqld
            state: started
            enabled: yes

        - name: Make sure pymysql is present
          pip:
            name: pymysql
            state: present

        - name: Create a new database with name 'tooling'
          mysql_db:
            name: tooling
            state: present
        
        #Name Runnign script
        - name: Running script to insert in tooling
          raw: mysql tooling < /home/ec2-user/tooling/tooling-db.sql
      
        - name: Inserting a user to test
          community.mysql.mysql_query:
            login_db: tooling
            query: INSERT INTO `users` (`id`, `username`, `password`, `email`, `user_type`, `status`) VALUES (2, 'myuser', '12345', 'user@mail.com', 'admin', '1');   
     
        - name: Create database user with name 'webaccess' and password '12345' with all database privileges
          mysql_user:
            name: webaccess
            password: 12345
            priv: '*.*:ALL' #all database privileges
            host: 172.31.80.0/20 #the host part of the username, subnet
            state: present
        
        #This is not working    
        - name: Input tooling credentials
          ansible.builtin.replace:
            path: /mnt/apps/html/functions.php
            regexp: "{{ item.regexp }}"
            replace: "{{ item.line }}"
          loop:
            - { regexp: '^admin', line: "webaccess" }
            - { regexp: '^admin', line: "12345" }
        - name: bypass, replace module not having desired effect
          raw: sed -i '5 s/admin/{{ item }}/' /mnt/apps/html/functions.php
          loop:
            - webaccess
            - 123456        
      when: inventory_hostname in groups['_NFS']
      remote_user: ec2-user   
      #when: inventory_hostname in groups['_web7'] #loop: "{{ groups['_web8'] }}"




    - name: web7 Configure
      block:
        - name: Pinging _web7
          ping:
          
        - name: Install NFS client, mysql client
          package: #yum: 
            name: #nfs4-acl-tools giving error [Errno 12] Cannot allocate memory
              - nfs4-acl-tools
              - mysql
              - nfs-utils
            state: present
            
        - name: Installing php
          yum:
            enablerepo: "remi,remi-php80" 
            name:
             - php
             - php-gd
             - php-curl 
             - php-mysqlnd
             - php-mysqli
            state: latest

        - name: Create www dir, mount NFS
          file:
            path: /var/www
            state: directory
            owner: nobody
            group: nobody
            mode: '0777'

        - name: Mount #fails if NFS server is not up
          ansible.posix.mount:
            path: /var/www
            src: "{{ privateIP }}:/mnt/apps" #NFS server PrivateIP
            fstype: nfs
            opts: rw,nosuid
            state: mounted #this mounts it
        
        - name: Install Apache
          package:
            name: httpd
            state: present  
        
        - name: Start Apache on boot
          ansible.builtin.service:
            name: httpd
            enabled: yes
        
        - name: Disable default site
          command: mv /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.backup
      
        - name: daemon-reload
          systemd:
            name: httpd
            state: started
            daemon_reload: yes
        
        #sudo setenforce 0 need to fstab this
        - name: Disable SELinux #need to check if it remains after boot
          ansible.posix.selinux:
            state: disabled
          when: inventory_hostname in groups['_web7'] #loop: "{{ groups['_web8'] }}"
          remote_user: ec2-user   