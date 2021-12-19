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
  gather_facts: false

  vars_files:
    - vars/info.yml

  tasks:
    - name: create a VPC
      ec2_vpc_net:
        aws_access_key: "{{ aws_id }}"
        aws_secret_key: "{{ aws_key }}"
        region: "{{ aws_region }}"
        name: test_vpc
        cidr_block: 10.10.0.0/16
        tags:
          module: ec2_vpc_net
        tenancy: default
        state: present
      register: ansibleVPC

    - name: debugVPC
      debug:
        var: ansibleVPC
```