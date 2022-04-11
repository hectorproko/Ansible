
# Project 9

``` bash
hector@hector-Laptop:~/Ansible/Project9$ tree
.
├── jenkins.yml
├── plays.sh
└── provisioning.yml
```

## plays.sh 
This bash script simply calls the **playbooks** one after the other
``` bash
sudo ansible-playbook provisioning.yml
sudo ansible-playbook jenkins.yml
```
## provisioning.yml
We are going to provision an Ubuntu instance very much like we did in Project 7 and 8

It has its own **Security Group** which opens port **8080**
``` bash
    - name: Create Security Group Jenkins Server
      ec2_group:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        name: "Project9_jenkins"
        description: "Security Group for Project 9 jenkins server"
        vpc_id: "{{ default_vpc.vpcs[0].vpc_id }}"
        rules:
          - proto: "tcp" 
            ports: "22" #remote using ssh
            cidr_ip: 0.0.0.0/0
          - proto: "tcp"
            ports: "8080" #http
            cidr_ip: 0.0.0.0/0 
      register: Project9_jenkins
```
Provisioning instance making sure tag name **Jenkins9** and attaching corresponding **Security Group**
``` bash
    - name: Ubuntu instance for Jenkins
      ec2:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        image: ami-04505e74c0741db8d # Ubuntu 64-bit x86
        instance_type: t2.micro
        key_name: "{{ ssh_keyname }}"
        count: 1 #number of instnaces to launch
        state: present
        group_id: "{{ Project9_jenkins.group_id }}" 
        wait: yes
        vpc_subnet_id: subnet-18872839 
        assign_public_ip: yes
        instance_tags:
          Name: Jenkins9 #9 for project 9
      register: ec2jenkins
```
We will allocate an **Elastic IP** to avoid having to use new Public IPs after each boot.
``` bash
    - name: allocate a new elastic IP 
      community.aws.ec2_eip:
        state: present
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        device_id: "{{ ec2jenkins.instances[0].id }}"
        allow_reassociation: true
        in_vpc: true
        reuse_existing_ip_allowed: true #If already exists use it
        tags: #reuse unallocated ips if tag reserved is nope
          reserved: nope 
      register: eip
```
Just outputting the Elastic IP to console
``` bash
    - name: output the Elastic IP
      ansible.builtin.debug:
        msg: "Allocated IP is {{ ec2jenkins.instances[0].id }}" 
```


## jenkins.yml


Our target host is **Jenkins9** and we are using user **ubuntu**
``` bash
- name: Start Configuring
  hosts: _Jenkins9
  gather_facts: false
  remote_user: ubuntu
```
Loading variables
```
  vars_files:
    - /etc/ansible/vars/info.yml
```

Here we are using 2 new modules **apt_key** (to add apt keys) and **apt_repository** (to add apt repository)
``` bash
    - name: ensure the jenkins apt repository key is installed
      apt_key: url=https://pkg.jenkins.io/debian-stable/jenkins.io.key state=present
      become: yes

    - name: ensure the repository is configured
      apt_repository: repo='deb https://pkg.jenkins.io/debian-stable binary/' state=present
      become: yes
```
Modules used in previous projects 7 and 8 to Install software **apt** and start service **systemd**
``` bash
    - name: Install jenkins
      apt:
        name: 
          - jenkins
          - default-jdk-headless
          - git
        state: latest
        
    - name: daemon-reload to pick up config changes
      ansible.builtin.systemd:
        daemon_reload: yes

    - name: Start jenkins
      ansible.builtin.systemd:
        name: jenkins
        state: started
        enabled: yes #start after boot
```