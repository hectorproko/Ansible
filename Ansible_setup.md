# Dynamic Inventory

``` bash
hector@hector-Laptop:~/Ansible/Project10$ tree /etc/ansible/
/etc/ansible/
├── ansible.cfg #Configuration file
├── aws_ec2.yml
└── vars
    ├── daro.io.pem
    └── info.yml

2 directories, 8 files
hector@hector-Laptop:~/Ansible/Project10$
```
``` bash
hector@hector-Laptop:/etc/ansible$ bat ansible.cfg
───────┬───────────────────────────────────────────────────────────────────────────
       │ File: ansible.cfg
───────┼───────────────────────────────────────────────────────────────────────────
   1   │ [defaults]
   2   │ inventory = aws_ec2.yml #Dynamic inventory
   3   │ host_key_checking = False
   4   │
   5   │ [privilege_escalation]
   6   │ become=True
   7   │ become_method=sudo
   8   │ become_user=root
   9   │ become_ask_pass=False
  10   │
  11   │ [inventory]
  12   │ enable_plugins = aws_ec2
───────┴───────────────────────────────────────────────────────────────────────────
hector@hector-Laptop:/etc/ansible$
```

At first I did not put aws credentials inside dynamic inventory and it worked fine but then I started to have issues and having it inside fixed it.
``` bash
hector@hector-Laptop:/etc/ansible$ bat aws_ec2.yml
───────┬───────────────────────────────────────────────────────────────────────────
       │ File: aws_ec2.yml
───────┼───────────────────────────────────────────────────────────────────────────
   1   │ plugin: aws_ec2
   2   │ 
   3   │ remote_user: Ansible #IAM user with AmazonEC2FullAccess
   4   │ aws_access_key: XXXXXXXXXXXXXXXXXXXX 
   5   │ aws_secret_key: XXXXXXXXXXXXXXXXXXXXXXXXXX
   6   │  
   7   │  regions:
   8   │   - "us-east-1" 
   9   │
  10   │ keyed_groups: #Groups based on tag ex: LB, NFS, web7
  11   │     - key: tags.Name
  12   │
  13   │ hostnames: dns-name
───────┴───────────────────────────────────────────────────────────────────────────
hector@hector-Laptop:/etc/ansible$
```
Example dynamic inventory grouped with by tags
``` bash
hector@hector-Laptop:/etc/ansible$ sudo ansible-inventory --graph
@all:
  |--@_Jenkins9:
  |  |--ec2-3-220-20-204.compute-1.amazonaws.com
  |--@_LB:
  |  |--ec2-100-24-22-230.compute-1.amazonaws.com
  |--@_NFS:
  |  |--ec2-52-91-225-30.compute-1.amazonaws.com
  |--@_web7:
  |  |--ec2-52-207-235-80.compute-1.amazonaws.com
  |  |--ec2-54-89-100-125.compute-1.amazonaws.com
  |--@aws_ec2:
  |  |--ec2-100-24-22-230.compute-1.amazonaws.com
  |  |--ec2-3-220-20-204.compute-1.amazonaws.com
  |  |--ec2-52-207-235-80.compute-1.amazonaws.com
  |  |--ec2-52-91-225-30.compute-1.amazonaws.com
  |  |--ec2-54-89-100-125.compute-1.amazonaws.com
  |--@ungrouped:
  ```

  ``` bash
  hector@hector-Laptop:/etc/ansible$ bat vars/info.yml
───────┬───────────────────────────────────────────────────────────────────────────
       │ File: vars/info.yml
───────┼───────────────────────────────────────────────────────────────────────────
   1   │ aws_id: XXXXXXXXXXXXXXXXXXXX
   2   │ aws_key: XXXXXXXXXXXXXXXXXXXXXXXXXX
   3   │ aws_region: us-east-1
   4   │ ssh_keyname: daro.io #need for provisioning module ec2
   5   │ ansible_ssh_private_key_file: /etc/ansible/vars/daro.io.pem #used by the configuring part
───────┴───────────────────────────────────────────────────────────────────────────
hector@hector-Laptop:/etc/ansible$
```
