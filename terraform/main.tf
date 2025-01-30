variable "control_nodes_count" {
  default = 1
}

variable "worker_nodes_count" {
  default = 1
}

variable "base_control_ip" {
  # default = "192.168.100.101"
	default = "10.0.1.101"
}

variable "base_worker_ip" {
  # default = "192.168.101.101"
	default = "10.0.2.101"
}

variable "inventory_path" {
  default = "../ansible/inventory"
}

resource "proxmox_vm_qemu" "control_nodes" {
  count       = var.control_nodes_count
  name        = "k8s-control-node-${count.index + 1}"
  desc        = "Kubernetes Control Node ${count.index + 1}"
  target_node = "proxbox"
  clone       = "VM 9000"

  agent   = 1
  os_type = "cloud-init"
  cores   = 2
  sockets = 1
  memory  = 2048
  scsihw  = "virtio-scsi-pci"
  boot    = "order=scsi0"

  # citype = nocloud
  cicustom = "user=local:snippets/proxbox-kube-ci.yml"
  # ciuser     = "tform_user"
  # cipassword = "password"
  ipconfig0 = "ip=10.0.1.${count.index + 100}/24,gw=10.0.0.1"
  nameserver = "1.1.1.1 8.8.8.8"

 disks {
    scsi {
      scsi0 {
        disk {
          size      = 32
          cache     = "writeback"
          storage   = "local-lvm"
          replicate = true
        }
      }
            scsi1 {
                cloudinit {
                    storage = "local-lvm"
                }
            }
    }
  }

  serial {
    id = 0
  }

  vga {
    type = "serial0"
  }

  network {
    model  = "virtio" # Use the VirtIO network driver.
    bridge = "vmbr0"  # Connect to the Proxmox bridge.
    # ip      = "dhcp"   # Request IP via DHCP.
    macaddr = format("DE:AD:BE:EF:%02X:%02X", count.index / 256, count.index % 256)
  }

  
}

# resource "proxmox_vm_qemu" "worker_nodes" {
#   # Ensure worker nodes are created only after control nodes
#   depends_on = [proxmox_vm_qemu.control_nodes]
# 
#   count       = var.worker_nodes_count
#   name        = "k8s-worker-node-${count.index + 1}"
#   desc        = "Kubernetes Worker Node ${count.index + 1}"
#   target_node = "proxbox"
#   clone       = "VM 9000"
# 
#   agent   = 1
#   os_type = "cloud-init"
#   cores   = 1
#   sockets = 1
#   memory  = 2048
#   scsihw  = "virtio-scsi-pci"
#   boot    = "order=scsi0"
#   
#   cicustom = "vendor=local:snippets/proxbox-kube-ci.yml"
#   ciuser     = "tform_user"
#   cipassword = "password"
#   ipconfig0 = "ip=10.0.1.${count.index + 100}/24,gw=10.0.0.1"
#   nameserver = "1.1.1.1 8.8.8.8"
# 
#   disks {
#     scsi {
#       scsi0 {
#         disk {
#           size      = 32
#           cache     = "writeback"
#           storage   = "local-lvm"
#           replicate = true
#         }
#       }
#     }
#   }
# 
#   serial {
#     id = 0
#   }
# 
#   vga {
#     type = "serial0"
#   }
# 
#   network {
#     model   = "virtio" # Use the VirtIO network driver.
#     bridge  = "vmbr0"  # Connect to the Proxmox bridge.
#     macaddr = format("DE:AD:BE:EF:%02X:%02X", count.index / 256, count.index % 256)
#   }
# 
# }
# 
# # Generate inventory file for Ansible
# resource "null_resource" "inventory" {
#   # Ensure this resource depends on both control and worker nodes
#   depends_on = [
#     proxmox_vm_qemu.control_nodes,
#     proxmox_vm_qemu.worker_nodes
#   ]
#   provisioner "local-exec" {
#     command = <<EOT
#       mkdir -p ${var.inventory_path}
#       cat <<EOF > ${var.inventory_path}/inventory.ini
# [prime_control]
# ${var.base_control_ip}
# 
# [secondary_control]
# %{for idx in range(var.base_control_ip, var.control_nodes_count+1) ~}
# 10.0.1.${idx + 100}
# %{endfor~}
# 
# [worker_nodes]
# %{for idx in range(var.base_worker_ip, var.worker_nodes_count+1) ~}
# 10.0.2.${idx + 100}
# %{endfor~}
# EOF
# EOT
#   }
# }
