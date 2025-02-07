# **Homegrown Runners System: IT Documentation**

## **Project Overview**
### **Purpose**
The Homegrown Runners System is designed to automate the execution of student code within **ephemeral containers** on a **Kubernetes cluster**. The cluster provides **orchestration**, but not high availability or large-scale scaling. This approach ensures an efficient, reproducible, and isolated environment for running student submissions.

### **Key Components**
- **Proxmox**: Used to create virtual machines (VMs) that act as Kubernetes nodes.
- **Kubernetes**: Manages ephemeral containers for executing student code.
- **Load Balancing**: Utilizes **Keepalived** and **HAProxy** to distribute control plane traffic.
- **Web Application**: Runs externally and interfaces with the Kubernetes API for job submission and results retrieval.
- **Automation**: Kubernetes cluster deployment is automated using **Terraform, Cloud-init, Ansible, and shell scripts** via the **[Proxbox Kube](https://github.com/NLaundry/proxbox-kube)** repository.
- **Development Tools**: **Devbox** is used to standardize development environments by managing dependencies like Terraform and Ansible.

---

## **Infrastructure Setup**
### **Proxmox Virtualization**
- **Hardware Requirements**:
  - Minimum **14 CPU cores** and **32GB RAM**.
  - Sufficient storage for VM images and logs.
- **VMs and Networking**:
  - Proxmox provisions **VMs as Kubernetes nodes**.
  - Uses a **dedicated subnet/IP range** for the cluster.
  - A **virtual IP** is assigned for the control plane using Keepalived.
  - Nodes communicate **internally**, with external access limited to the Kubernetes API.

### **Kubernetes Cluster Deployment**
- **Provisioning Tools**:
  - **Terraform**: Automates VM creation on Proxmox.
  - **Cloud-init**: Configures new VMs at boot.
  - **Ansible**: Deploys and configures Kubernetes components.
  - **Shell scripts**: Handles additional system setup tasks.
- **Control Plane and Load Balancing**:
  - Control plane traffic is balanced using **Keepalived and HAProxy**.
  - The Kubernetes API is exposed via the **virtual IP (port 6443)**.
  - The web application communicates with the **Kubernetes control plane endpoint** only on **port 6443**.

### **Ansible Configuration & VM Access**
- **Ansible controls VMs via SSH** from the **Proxmox host**.
- **SSH keys are injected via Cloud-init**, ensuring automated access.
- **Firewall rules limit SSH access** to prevent unauthorized connections.

---

## **Containerization Strategy**
### **Preferred Approach: Rootless OCI-Compliant Containers**
While IT prefers **Apptainer/Singularity**, these tools are optimized for **high-performance computing (HPC)** and lack native **OCI compliance**, making them less suitable for Kubernetes integration.

Instead, we recommend:
- **Podman or another rootless OCI-compliant container runtime**:
  - **Security**: Containers run without root privileges.
  - **Lightweight**: Ideal for ephemeral container execution.
  - **Kubernetes Compatibility**: Fully supports OCI-compliant workflows.

---

## **Current Design Choices**
- **Cgroup Driver**: Using **systemd** for better integration with modern Linux systems.
- **Container Runtime**: **Containerd** is used as the container runtime environment for Kubernetes.

---

## **Networking & Security Considerations**
### **Firewall Rules & Access Control**
- **Internal network segmentation** ensures:
  - Kubernetes nodes communicate **only over necessary ports**.
  - The **web application host** can access **port 6443** on the Kubernetes API.
  - Proxmox has **restricted SSH access** to VMs via Cloud-init.

### **Required Open Ports on VMs**
The following ports should be open **only to other Kubernetes nodes**, except for **port 6443**, which needs to be accessible to the web application host:

- **6443** (TCP) - Kubernetes API Server (accessible from web application host)
- **2379-2380** (TCP) - etcd server client API (only between control plane nodes)
- **10250** (TCP) - Kubelet API (only between Kubernetes nodes)
- **10251** (TCP) - kube-scheduler (only control plane nodes)
- **10252** (TCP) - kube-controller-manager (only control plane nodes)
- **30000-32767** (TCP) - NodePort Services (only if used by workloads, internal to Kubernetes)

All other ports should be closed unless explicitly needed for internal Kubernetes functionality.



