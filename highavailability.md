# High Availability (HA) Setup for Kubernetes Control Plane

## Overview
This setup ensures high availability (HA) for the Kubernetes control plane using:
- **Keepalived** for Virtual IP (VIP) failover (ensures a single, always-available API endpoint).
- **HAProxy** for load balancing requests to control plane nodes.

### **HA Control Plane Architecture**
- **Virtual IP (VIP)**: `192.168.100.100`
- **DNS Name**: `k8s-control.local`
- **Control Plane Nodes**: `prime_control` + `secondary_control` nodes
- **Load Balancer**: HAProxy on all control nodes
- **Failover Manager**: Keepalived on all control nodes

## **Router & Network Configuration**
### **1️⃣ Add a DNS Entry for `k8s-control.local`**
To make it easier to reach the control plane, add a **DNS entry** for `k8s-control.local` pointing to `192.168.100.100`:
- If using **a local DNS server (e.g., Pi-hole, Unbound, dnsmasq)**:
  - Add a static DNS record:  
    ```
    k8s-control.local → 192.168.100.100
    ```
- If using a **home router** with custom DNS settings:
  - Look for "Static DNS" or "Host Mapping" settings and add:
    ```
    Hostname: k8s-control.local
    IP: 192.168.100.100
    ```
- If you **don’t have a local DNS**, you can edit your `/etc/hosts` (temporary solution):
  ```bash
  echo "192.168.100.100 k8s-control.local" | sudo tee -a /etc/hosts
  ```

### **2️⃣ Ensure Network Access & Firewall Rules**
- Ensure that **all control plane nodes** can reach each other and the VIP (`192.168.100.100`).
- If running a **firewall (UFW, iptables, or router-level firewall)**, ensure these ports are **open on all control nodes**:
  ```
  6443  (Kubernetes API server)
  2379-2380  (etcd server)
  10250  (Kubelet API)
  10257-10259  (Kubernetes control plane components)
  ```
  Example for UFW:
  ```bash
  sudo ufw allow 6443/tcp
  sudo ufw allow 2379:2380/tcp
  sudo ufw allow 10250/tcp
  sudo ufw allow 10257:10259/tcp
  ```

### **3️⃣ Configure Keepalived & HAProxy**
This is handled automatically by Ansible:
- **Keepalived** ensures the VIP `192.168.100.100` fails over if a control node goes down.
- **HAProxy** distributes API traffic among control nodes.

## **Verification**
### **Check Keepalived Virtual IP (VIP)**
Run this on any control plane node:
```bash
ip a show dev eth0 | grep 192.168.100.100
```
✅ Expected output:
```
inet 192.168.100.100/24 scope global secondary eth0
```

### **Check HAProxy is Load Balancing**
Run this on any node (or externally):
```bash
curl -k https://k8s-control.local:6443/version
```
✅ Expected output (shows Kubernetes API responding):
```json
{
  "major": "1",
  "minor": "32",
  "gitVersion": "v1.32.0",
  ...
}
```

---

## **🚀 Summary**
- The Kubernetes control plane **must use a Virtual IP (VIP)** to support failover and load balancing.
- The **VIP (`192.168.100.100`) is load balanced via HAProxy and managed by Keepalived**.
- **DNS configuration is required** so `k8s-control.local` resolves correctly.
- **Router & firewall settings must allow API server traffic** (`6443`, etc.).

With this setup, **Kubernetes will remain available even if a control plane node fails!** 🚀
```

---

## **✅ Conclusion**
- **Updated `kubeadm-config.yaml.j2`** to use `192.168.100.100` with `k8s-control.local`.  
- **Added a README section** explaining HAProxy, Keepalived, and **router-level configuration**.  
- This ensures a **stable, highly available control plane** with **proper DNS and networking setup**. 🚀
