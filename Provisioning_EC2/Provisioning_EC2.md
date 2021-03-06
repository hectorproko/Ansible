## Overview of the Deployment Process
* Creating the network:
    - Create an Amazon Virtual Private Cloud (VPC)
    - Create an internet gateway
    - Create a public subnet
    - Create a routing table
    - Create a security group
* Creating a Red Hat Enterprise Linux 8 - based cloud instance:
    - Locate the latest RHEL 8 AMI to use
    - Launch an EC2 instance using that AMI

## My Setup
On an Ubuntu machine I have **Ansible** installed
```
ansible [core 2.11.7]
```
My directory structure consists of directory **AWS** in the home directory or current user
``` bash
hector@hector-Laptop:~/AWS$ tree
.
├── allResources.yml #playbook
└── vars
    ├── daro.io.pem #key pair
    └── info.yml #variable file

1 directory, 3 files
```
## Create an AWS User and Its Access Key and Secret Key

You should create an individual IAM user for Ansible to use as per [Security best practices in IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html). 	This allows you to limit how much access Ansible has to your account and its resources.

Sign in to the AWS Management Console and open the [IAM Console](https://console.aws.amazon.com/iam/)
* In the navigation pane, choose Users and then choose **Add user**
1. In the Username field type **Ansible**
2. Choose **Programmatic access** to enable access and secret key
3. Click **Next: Permissions**

* Organizing the user into a new group is a good organizational feature to assist in user management.
* Add user to a new group:
    1. In the group name field type testgroup
    2. Choose boxes for **AmazonEC2FullAccess** and **AmazonVPCFullAccess** and click **create group**
    3. Click Next: Tags
* Tags enable you to add customizable key-value pairs to resources.
		Assign tags to user (this is optional):
    1. Click **Next: Review**
    2. Click **Create User**

* The AWS Access and Secret Access Keys
    - Download the **.csv file**. This is the only opportunity to save this file
    - The secret key will later be stored in a variables file called **info.yml**
    - If access to the secret key is not available, delete the key and create another one

* Providing Authentication Data to Ansible as Variables
- When you have the access keys, you can prepare a variable file to store them for your plays
- Some examples of data that is helpful to store as variables:
    - AWS user id
    - AWS secret key
    - AWS SSH key name
    - AWS region selection
* For better security, use [ansible-vault](https://github.com/hectorproko/Ansible/blob/main/ansible_vault) to encrypt the variable files containing your authentication secrets
    - ansible-vault encrypt vars/info.yml

## Creating a Variable File Containing Access Keys
* The following example outlines one way to provide access keys as variables to a play:
    1. Create a directory for this Ansible project. In our example, name is AWS
    2. Create a directory inside **AWS** called **vars**
    3. Create a file inside the **vars** directory called **info.yml**. This file will store the AWS keys, the region, and the ssh keyname used by the playbooks		
    4. In your play, load **vars/info.yml** to make those values available to the play

``` bash
────────────────────────────────────────
       │ File: vars/info.yml
─────────────────────────────────────────
   1   │ aws_id: <removed>
   2   │ aws_key: <removed>
   3   │ aws_region: us-east-1
   4   │ ssh_keyname: daro.io

```
## Provisioning a Virtual Private Cloud
* A VPC is primarily concerned with enabling the following capabilities:
    - Isolating your AWS resources from other accounts
    - Routing network traffic to and from your instances
    - Protecting your instances from network intrusion


``` bash
- name: Start #name of play
  hosts: localhost #Where EC2 cloud modules run on
  remote_user: Ansible #IAM user we created
  gather_facts: false #to save time it is disabled

  vars_files: #loading variables from file
    - vars/info.yml #contains access key, secret key, region, key name

  tasks:
    - name: create a VPC
      ec2_vpc_net: #module
        aws_access_key: "{{ aws_id }}" #variables
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        name: test_vpc #name of VPC
        cidr_block: 10.10.0.0/16
        tags:
          module: ec2_vpc_net
        tenancy: default #to run on shared hardware
        state: present #if you were to exclude state, present is default value
      register: ansibleVPC #variable to store result of task, contains resource ID

    - name: debugVPC #Using module debug to see contents of var AnsibleVPC
      debug:
        var: ansibleVPC
```

## Manage an AWS VPC Internet Gateway
* Using **ec2_vpc_igw** module to attach an internet gateway to the newly created VPC
* The **vpc_id** parameter is required to run this play
* If you use this after the above **ec2_vpc_net** tasks in the previous example, you can get the **vpc_id** from the registered variable ansibleVPC
``` bash
ansibleVPC['vpc']['id']
#Optional syntax
ansibleVPC.vpc.id
```
``` bash
    - name: Create Internet Gateway for test_vpc
      ec2_vpc_igw:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        state: present #controls whether the IGW should be present or absent from the VPC.
        vpc_id: "{{ ansibleVPC.vpc.id }}"
        tags:
          Name: test_vpc #tag name
      register: ansibleVPC_igw #saving results to later extract IGW's ID

    - name: Display test_vpc IGW details
      debug: #Displaying variable
        var: test_vpc_igw
```
## Manage Subnets in AWS Virtual Private Clouds

* Use the **ec2_vpc_subnet** module to add a subnet to an existing VPC	
* You must specify the **vpc_id** of the VPC the subnet is in

``` bash
    - name: Create Public Subnet in "{{ aws_region }}"
      ec2_vpc_subnet:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        state: present #specifies subnet should exist
        cidr: 10.10.0.0/16
        vpc_id: "{{ ansibleVPC.vpc.id }}" #using ansibleVPC variable from earlier play
        map_public: yes #to assign instances a public IP address by default
        tags:
          Name: Public Subnet
      register: public_subnet #saving results

    - name: Show Public Subnet Details
      debug:
        var: public_subnet
```

## Manage Routing Tables
- In order for you VPC to route the traffic for the new subnet, it needs a route table entry
- Use the **ec2_vpc_route_table** module to create a routing table. It can also manage routes in the table and associate them with an **IGW**
- You will need the **VPC's ID** and the **IGW's ID**

``` bash
    - name: Create New Route Table for Public Subnet
      ec2_vpc_route_table:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        state: present
        vpc_id: "{{ ansibleVPC.vpc.id }}" #vpc for which you are creating route table
        tags:
          Name: rt_testVPC_PublicSubnet
        subnets: #is a list of subnet IDs to attach to the route table
          - "{{ public_subnet.subnet.id }}"#public_subnet variable registered earlier in the play
        routes: # the list of routes
          - dest: 0.0.0.0/0 #the network being routed to, 0.0.0.0/0 its default
            gateway_id: "{{ ansibleVPC_igw.gateway_id }}" #s the ID of an IGW
      register: rt_ansibleVPC_PublicSubnet

    - name: Display Public Route table
      debug:
        var: rt_ansibleVPC_PublicSubnet
```

##  Maintain an EC2 VPC Security Group

- Security Groups help manage firewall rules for your VPCs.
- Although **vpc_id** is not a required parameter for creating a new group, it will be used to associate the group with the VPC.
- In order to launch an instance in AWS you need to assign it to a particular security group
- The security group must be in the same VPC as the resources you want to protect
- A security group blocks all traffic by default
- If you want to allow traffic to a port you need to add a rule specifying it

``` bash
    - name: Create Security Group
      ec2_group:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        name: "Test Security Group" #name for the new group
        description: "Test Security Group"
        vpc_id: "{{ ansibleVPC.vpc.id }}"
        tags:
          Name: Test Security Group
        rules: #defines firewall inbound rules to enforce
          - proto: "tcp"
            ports: "22"
            cidr_ip: 0.0.0.0/0
      register: my_vpc_sg

    - name: Set Security Group ID in variable
      set_fact:
        sg_id: "{{ my_vpc_sg.group_id }}"
```

## Provisioning Amazon EC2 Instances

### Finding an Existing AMI
- Before we use ec2 to create the instance, we need to know the ID of the AMI to use
- Use the **ec2_ami_info** module to find the AMI you want to use
	(before Ansible 2.9 called this module ec2_ami_facts)

``` bash
    - name: Find AMIs published by Red Hat (309956199498). Non-beta and x86
      ec2_ami_info:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        owners: 309956199498 #specifies Red Hat's code
        filters:
          architecture: x86_64 #filters the list of AMIs returned by the module
          name: RHEL-8*HVM-* #Using wildcards to match the name
      register: amis #storing all returned AMIs that match

    - name: Show AMI
      debug:
        var: amis

    - name: Get the latest one
      set_fact: #filters the images to most recent creation date saves it in latest_ami.
        latest_ami: "{{ amis.images | sort(attribute='creation_date') | last }} 
```

### Create, Terminate, Start or Stop an Instance in EC2
``` bash
    - name: Basic porvisioning of ec2 instance
      ec2:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        image: "{{ latest_ami.image_id }}"
        instance_type: t2.micro
        key_name: "{{ ssh_keyname }}"
        count: 1 #if you want to create multiple instances
        state: present
        group_id: "{{ my_vpc_sg.group_id }}"
        wait: yes
        vpc_subnet_id: "{{ public_subnet.subnet.id }}"
        assign_public_ip: yes
        instance_tags:
          Name: new_demo_template
      register: ec2info

    - name: Print the results
      debug:
        var: ec2info
```