# Project 7


``` bash
hector@hector-Laptop:~/Ansible/Project7$ tree
.
├── NFS+WEB_configure.yml
└── provisioning.yml
```

## provisioning.yml
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
