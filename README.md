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

[Proxmox Community sources Configuration](https://pve.proxmox.com/pve-docs/chapter-sysadmin.html) #Necessary

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

This repository contains an **Ansible-based Kubernetes cluster deployment** using **Proxmox, Terraform, and kubeadm**. It automates the **setup of a high-availability Kubernetes cluster** with the following features:

- **HAProxy & Keepalived** for API server load balancing.
- **Systemd as the cgroup driver** for containerd.
- **Modular Ansible roles** for easy maintenance.
- **Kubernetes best practices** from the official documentation.

---

#### Directory Structure

```
k8s-cluster/
│── inventory.ini               # Inventory file (INI format)
│── roles/
│   ├── bootstrap/              # Base system prep (firewall, swap, sysctl)
│   ├── container_runtime/      # Installs and configures containerd
│   ├── kubernetes_install/     # Installs kubeadm, kubelet, kubectl
│   ├── kubeadm_init/           # Initializes the primary control node
│   ├── join_secondary_control/ # Joins secondary control nodes
│   ├── join_workers/           # Joins worker nodes
│   ├── haproxy/                # Configures HAProxy for API server load balancing
│   ├── keepalived/             # Sets up a Virtual IP (VIP) for high availability
│   ├── cni/                    # Deploys the Kubernetes network plugin
│── playbooks/
│   ├── common.yml              # Runs bootstrap, container_runtime, kubernetes_install
│   ├── prime_control.yml       # Runs kubeadm init + generates join tokens
│   ├── secondary_control.yml   # Runs join tasks for secondary control nodes
│   ├── worker_nodes.yml        # Runs join tasks for workers
│   ├── cni.yml                 # Runs after all nodes are joined
│── site.yml                    # Master playbook to orchestrate everything
```

---

#### Inventory Configuration

The **inventory file (`inventory.ini`)** defines the **control and worker nodes**, including a **meta-group for control nodes**:

```ini
[prime_control]
192.168.1.101

[secondary_control]
192.168.1.102
192.168.1.103

[control_nodes:children]
prime_control
secondary_control

[worker_nodes]
192.168.1.201
192.168.1.202
```

This allows Ansible to:
- **Run kubeadm init on the prime control node.**
- **Join secondary control nodes correctly.**
- **Apply firewall and networking configurations to all control nodes.**

---

#### Playbook Execution Order

The `site.yml` file ensures **roles run in the correct sequence**:

```yaml
- import_playbook: playbooks/common.yml
- import_playbook: playbooks/prime_control.yml
- import_playbook: playbooks/secondary_control.yml
- import_playbook: playbooks/worker_nodes.yml
- import_playbook: playbooks/cni.yml
```

Each playbook runs the **corresponding roles** based on node type.

---

#### `bootstrap` Role (Base System Setup)

The **`bootstrap` role** prepares all nodes for Kubernetes installation by:
- **Installing system dependencies** (curl, ca-certificates, etc.).
- **Configuring sysctl parameters** for networking & cgroup compatibility.
- **Disabling swap** (required by Kubernetes).
- **Configuring firewall rules** (specific to control & worker nodes).

##### Firewall Rules

To ensure proper **Kubernetes communication**, firewall rules are set based on **node type**.

**Control Nodes:**
```yaml
- name: Open required firewall ports for control nodes
  ansible.builtin.ufw:
    rule: allow
    port: "{{ item }}"
    proto: tcp
  loop:
    - 6443        # Kubernetes API server
    - 2379:2380   # etcd server client API
    - 10250       # Kubelet API
    - 10257       # kube-controller-manager
    - 10259       # kube-scheduler
  when: "'control_nodes' in group_names"
```

**Worker Nodes:**
```yaml
- name: Open required firewall ports for worker nodes
  ansible.builtin.ufw:
    rule: allow
    port: "{{ item }}"
    proto: tcp
  loop:
    - 10250       # Kubelet API
    - 30000:32767 # NodePort Services
  when: "'worker_nodes' in group_names"
```

##### Sysctl Configuration

This enables **IP forwarding** and **proper cgroup handling** for Kubernetes:

```yaml
- name: Configure sysctl parameters for Kubernetes networking and systemd cgroup driver
  ansible.builtin.sysctl:
    name: "{{ item.name }}"
    value: "{{ item.value }}"
    state: present
    reload: yes
  loop:
    - { name: 'net.bridge.bridge-nf-call-iptables', value: '1' }
    - { name: 'net.ipv4.ip_forward', value: '1' }
    - { name: 'net.bridge.bridge-nf-call-ip6tables', value: '1' }
    - { name: 'systemd.unified_cgroup_hierarchy', value: '0' }  # Ensure legacy cgroup hierarchy is enabled
```

---

#### `container_runtime` Role (Containerd Setup)

The **`container_runtime` role** installs and configures **containerd**, setting **systemd as the cgroup driver**.

##### Configure Containerd to Use `systemd`

```yaml
- name: Modify containerd configuration to use systemd cgroup driver
  ansible.builtin.replace:
    path: /etc/containerd/config.toml
    regexp: 'SystemdCgroup = false'
    replace: 'SystemdCgroup = true'
```

---

#### `kubernetes_install` Role (Kubeadm, Kubelet, Kubectl)

The **`kubernetes_install` role**:
- Adds the **Kubernetes APT repository**.
- Installs `kubeadm`, `kubelet`, and `kubectl`.
- Prevents **automatic upgrades** by holding package versions.

##### Prevent Upgrades

```yaml
- name: Hold Kubernetes packages to prevent unwanted upgrades
  ansible.builtin.dpkg_selections:
    name: "{{ item }}"
    selection: hold
  loop:
    - kubelet
    - kubeadm
    - kubectl
```

---

#### `kubeadm_init` Role (Prime Control Node Setup)
**TODO:** (Explain how kubeadm initializes the cluster, generates join commands, and sets up control plane components.)

---

#### `join_secondary_control` Role (Secondary Control Node Join)
**TODO:** (Explain how secondary control nodes join with the `--control-plane` flag and certificate key.)

---

#### `join_workers` Role (Worker Node Join)
**TODO:** (Explain how worker nodes join using `kubeadm join`.)

---

#### `haproxy` Role (Load Balancer for API Server)
**TODO:** (Explain how HAProxy distributes API traffic across control nodes.)

---

#### `keepalived` Role (Virtual IP for HA)
**TODO:** (Explain how Keepalived ensures failover of the API server endpoint.)

---

#### `cni` Role (Networking Plugin)
**TODO:** (Explain how a CNI like Calico or Flannel is applied after cluster initialization.)


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

### Ansible cmd can't handle pipes??

I think this is true. Need to look into. I tried 

```
- name: Download and dearmor Kubernetes repository key
  ansible.builtin.command:
    cmd: curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  changed_when: false
```

And got errors about curl not having a --dearmor flag

### Proxmox has parallelism issues

https://github.com/Telmate/terraform-provider-proxmox/issues/173

basically, you can't spin up multiple VMs based on the same template all at once

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

