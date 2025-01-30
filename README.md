# Proxbox Kube

## Goal

The goal of this project is to automate standing up and tearing down a kubernetes cluster. 
- Nodes are provisioned from proxmox via Terraform 
- Cloud init configueres basics of the nodes like ports, swap, ssh keys, and preps to pass over to Ansible
- Ansible handles initializing, joining, and configuring the cluster.

## Resources 

[Example Cloud Init configs](https://cloudinit.readthedocs.io/en/latest/reference/examples.html)
[Cloud Init Users](https://www.linode.com/docs/guides/manage-users-with-cloud-init/)
[Kubernetes Ansible Guide](https://spacelift.io/blog/ansible-kubernetes)

## Automated Setup Steps

### Scripts

These scripts automate the setup process for a Proxmox environment, including creating a user with API access and preparing a QEMU cloud-init VM template. This ensures the environment is ready for Terraform provisioning. API token info is output to terraform/proxmox_token.tfvars for use with terraform later.

#### **1. `create_proxmox_user_and_get_key.sh`**
This script handles the creation of a Proxmox user with the necessary permissions and API token for Terraform.

- **Key Steps**:
  1. **User Creation**:
     - Creates a new Proxmox user (`terraform_user` or similar) with restricted permissions for secure access.
  2. **Role and Permission Assignment**:
     - Assigns the user a custom role (`TerraformRole`), granting only the permissions required for Terraform to interact with Proxmox.
  3. **API Token Generation**:
     - Creates an API token for the user, enabling Terraform to authenticate with Proxmox securely.
  4. **Output**:
     - Outputs the token ID and secret, which can be used in the Terraform provider configuration.

- **Purpose**:
  - Simplifies and secures the process of setting up a Terraform-compatible Proxmox user.
  - Eliminates the need to use root credentials directly in Terraform.

#### **2. `qemu_template_setup.sh`**
This script prepares a QEMU cloud-init template that serves as the base for creating virtual machines.

- **Key Steps**:
  1. **Cloud-Init Installation**:
     - Ensures that the cloud-init package is installed on the base image.
  2. **Base Image Preparation**:
     - Downloads a Linux distribution ISO (e.g., Ubuntu, Debian) or uses an existing base image.
     - Installs and configures essential tools.
  3. **Template Creation**:
     - Converts the base image into a Proxmox template after configuring it for cloud-init.
  4. **Storage and Networking**:
     - Configures storage (e.g., using `local-lvm`) and network settings to align with Proxmox defaults.
  5. **Cloud-Init Enablement**:
     - Sets up cloud-init support, including enabling relevant services and clearing machine-specific data (e.g., SSH keys) to ensure clean instantiation for VMs.

- **Purpose**:
  - Provides a reusable cloud-init-enabled template for Terraform provisioning.
  - Reduces the need for repetitive manual configuration when creating new VMs.

#### Workflow
1. **Run `create_proxmox_user_and_get_key.sh`**:
   - Sets up the required Proxmox user and outputs API credentials for Terraform.
2. **Run `qemu_template_setup.sh`**:
   - Prepares the cloud-init template for Terraform to clone.

### Terraform + Cloud Init

#### 1. **Terraform Provider**
The `telmate/proxmox` provider is used to interact with the Proxmox VE API. It manages the lifecycle of VMs, including cloning from templates, setting up networking, and configuring resources such as CPU, memory, and disks.

#### 2. **VM Provisioning**
- Terraform provisions two types of Kubernetes nodes:
  - **Control Nodes**: Includes one **prime control node** (for `kubeadm init`) and additional secondary control nodes.
  - **Worker Nodes**: Nodes designed to join the Kubernetes cluster as worker nodes.
- **Dynamic Hostnames**: Each VM is assigned a unique hostname (e.g., `k8s-control-node-1`, `k8s-worker-node-1`).

#### 3. **Networking**
- Each VM uses DHCP for IP assignment but requests specific IPs from predefined ranges:
  - Control nodes: `192.168.100.101+`
  - Worker nodes: `192.168.101.100+`
- These ranges ensure predictable IP addressing for easier cluster configuration.
- A **virtual IP** (192.168.100.100) is reserved for high-availability (HA) purposes.

#### 4. **Cloud-Init Integration**
Terraform integrates with Cloud-Init to handle base VM configurations:
- **Base Setup**:
  - Disables swap (required for Kubernetes).
  - Installs essential packages like `kubelet`, `kubectl`, and `containerd`.
  - Configures network settings.
- **SSH Keys**:
  - Injects SSH keys from the `tform_user` and `root` users on the Proxmox machine to allow Ansible configuration.
- **Dynamic Configuration**:
  - Cloud-Init YAML templates are dynamically generated using Terraform variables to include node-specific details, such as hostnames and IPs.

#### 5. **Ansible Inventory**
Terraform generates an **Ansible inventory file** dynamically:
- The file is created in the `../ansible/inventory/` directory.
- It groups nodes into:
  - `prime_control`: The primary control node. (this is the one we run kubeadm init with)
  - `secondary_control`: Additional control nodes.
  - `worker_nodes`: All worker nodes.

This inventory ensures that Ansible can seamlessly manage the cluster setup post-provisioning.

### Ansible

TBD: but the idea is kubernetes node configuration, cluster init, and joining



## Contributing

### Devbox

[Devbox docs](https://www.jetify.com/docs/devbox/installing_devbox/)

Devbox uses NIX to setup contained developer environments with all 
the packages you need

Install:
- `curl -fsSL https://get.jetify.com/devbox | bash`
- On Linux You may have to enable the nix daemon and add yourself to a nix group
    - sudo systemctl enable nix-daemon
    - sudo systemctl start nix-daemon
    - sudo usermod -aG nix-users $(whoami)
- after that, probably reboot just in case.

Enter the environment:
`devbox shell`

## Notes and Learnings

### Proxmox Output formats

By default, proxmox cli stuff tends to output things in "human readable text tables"
which look like this

┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                │
╞══════════════╪══════════════════════════════════════╡
│ full-tokenid │ tform_user@pve!test2                 │
├──────────────┼──────────────────────────────────────┤
│ info         │ {"privsep":1}                        │
├──────────────┼──────────────────────────────────────┤
│ value        │ 24e01abd-3421-4a83-aad1-b12a42c6fcb7 │
└──────────────┴──────────────────────────────────────┘

These aren't great for automating, but you can pass other formats!

example: pveum token add "tform_user@pve" token_name --output-format=json
    - easy to use with jq or something
example plain text but no borders: pveum token add "tform_user@pve" token_name --noborder=1 --noheader=1
    - this example is much easier to awk 

https://github.com/proxmox/pve-docs/blob/5b4f68560624dae0342e55816f51dc6b47b5a2a3/output-format-opts.adoc

