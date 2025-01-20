# Proxbox Kube

## Goal

The goal of this project is to automate standing up and tearing down a kubernetes cluster. 
- Nodes are provisioned from proxmox via Terraform 
- Cloud init configueres basics of the nodes like ports, swap, ssh keys, and preps to pass over to Ansible
- Ansible handles initializing, joining, and configuring the cluster.
