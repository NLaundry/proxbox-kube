variable "control_nodes_count" {
  default = 1
}

variable "worker_nodes_count" {
  default = 1
}

variable "base_control_ip" {
  default = "192.168.100.101"
}

variable "base_worker_ip" {
  default = "192.168.101.101"
}

variable "inventory_path" {
  default = "../ansible/inventory"
}

resource "proxmox_vm_qemu" "control_nodes" {
  count       = var.control_nodes_count
  name        = "k8s-control-node-${count.index + 1}"
  desc        = "Kubernetes Control Node ${count.index + 1}"
  target_node = "proxmoxnodename"
  clone       = "VM 9000"

  agent   = 1
  os_type = "cloud-init"
  cores   = 2
  sockets = 1
  memory  = 2048
  scsihw  = "virtio-scsi-pci"
  boot    = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size      = 50
          cache     = "writeback"
          storage   = "local-lvm"
          replicate = true
        }
      }
    }
  }

  network {
    model  = "virtio" # Use the VirtIO network driver.
    bridge = "vmbr0"  # Connect to the Proxmox bridge.
    # ip      = "dhcp"   # Request IP via DHCP.
    macaddr = format("DE:AD:BE:EF:%02X:%02X", count.index / 256, count.index % 256)
  }

  # ipconfig0 = format("ip=%s,gw=192.168.100.1", cidrhost(var.base_control_ip, count.index))

  # cloudinit {
  #   user_config = file("${path.module}/cloud-init.yaml")
  # }

  ciuser     = "tform_user"
  cipassword = "securepassword"

  user_data = templatefile("${path.module}/cloud-init.yml", {
    hostname = "k8s-control-node-${count.index + 1}"
  })

  # user_data = file("${path.module}/cloud-init.yaml")
}

resource "proxmox_vm_qemu" "worker_nodes" {
  count       = var.worker_nodes_count
  name        = "k8s-worker-node-${count.index + 1}"
  desc        = "Kubernetes Worker Node ${count.index + 1}"
  target_node = "proxmoxnodename"
  clone       = "VM 9000"

  agent   = 1
  os_type = "cloud-init"
  cores   = 1
  sockets = 1
  memory  = 2048
  scsihw  = "virtio-scsi-pci"
  boot    = "order=scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          size      = 50
          cache     = "writeback"
          storage   = "local-lvm"
          replicate = true
        }
      }
    }
  }

  network {
    model   = "virtio" # Use the VirtIO network driver.
    bridge  = "vmbr0"  # Connect to the Proxmox bridge.
    # ip      = "dhcp"   # Request IP via DHCP.
    macaddr = format("DE:AD:BE:EF:%02X:%02X", count.index / 256, count.index % 256)
  }

  user_data = templatefile("${path.module}/cloud-init.yml", {
    hostname = "k8s-control-node-${count.index + 1}"
  })
  ciuser     = "tform_user"
  cipassword = "securepassword"
}

# Generate inventory file for Ansible
resource "null_resource" "inventory" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${var.inventory_path}
      cat <<EOF > ${var.inventory_path}/inventory.ini
[prime_control]
${proxmox_vm_qemu.control_nodes[0].ipconfig0}

[secondary_control]
%{for idx in range(1, var.control_nodes_count)~}
${cidrhost(var.base_control_ip, idx)}
%{endfor~}

[worker_nodes]
%{for idx in range(0, var.worker_nodes_count)~}
${cidrhost(var.base_worker_ip, idx)}
%{endfor~}
EOF
EOT
  }
}

