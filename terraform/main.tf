variable "control_nodes_count" {
  default = 3
}

variable "worker_nodes_count" {
  default = 3
}

variable "base_control_ip" {
  default = "192.168.100.101"
  # default = "10.0.1.101"
}

variable "base_worker_ip" {
  default = "192.168.101.101"
  # default = "10.0.2.101"
}

variable "inventory_path" {
  default = "../ansible/inventory"
}

variable "ssh_key_path" {
  default = "/root/.ssh/id_rsa.pub"
}

data "local_file" "ssh_public_key" {
  filename = var.ssh_key_path
}

data "template_file" "cloud_init" {
  template = file("${path.module}/cloud-init.tftpl")

  vars = {
    ssh_public_key = chomp(data.local_file.ssh_public_key.content)
  }
}

resource "null_resource" "upload_cloudinit" {
  provisioner "local-exec" {
    command = <<EOT
    echo '${data.template_file.cloud_init.rendered}' > /var/lib/vz/snippets/cloud-init.yml
    EOT
  }
}

resource "proxmox_vm_qemu" "control_nodes" {

  depends_on = [null_resource.upload_cloudinit]


  count       = var.control_nodes_count
  name        = "k8s-control-node-${count.index + 1}"
  desc        = "Kubernetes Control Node ${count.index + 1}"
  target_node = "proxbox"
  clone       = "VM 9000"

  agent   = 1
  os_type = "cloud-init"
  cores   = 2
  sockets = 1
  memory  = 4096
  scsihw  = "virtio-scsi-pci"
  boot    = "order=scsi0"

  # citype = nocloud # this can't be set in terraform, BUT it absolutely has to on the VM template or cicustom doesn't work at all!
  cicustom   = "user=local:snippets/cloud-init.yml"
  ipconfig0  = "ip=192.168.100.${count.index + 101}/16,gw=192.168.1.1"
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
    model   = "virtio" # Use the VirtIO network driver.
    bridge  = "vmbr0"  # Connect to the Proxmox bridge.
    macaddr = format("DE:AD:BE:EF:%02X:%02X", count.index, count.index % 256)
  }


}

resource "proxmox_vm_qemu" "worker_nodes" {
  # Ensure worker nodes are created only after control nodes
  depends_on = [proxmox_vm_qemu.control_nodes]
  # depends_on = [proxmox_vm_qemu.control_nodes, time_sleep.wait_between_vms[count.index]] # Ensure Cloud-Init is ready before VM creation

  count       = var.worker_nodes_count
  name        = "k8s-worker-node-${count.index + 1}"
  desc        = "Kubernetes Worker Node ${count.index + 1}"
  target_node = "proxbox"
  clone       = "VM 9000"

  agent   = 1
  os_type = "cloud-init"
  cores   = 2             # Workers have 1 core
  sockets = 1
  memory  = 4096          
  scsihw  = "virtio-scsi-pci"
  boot    = "order=scsi0"

  # Cloud-init configuration
  cicustom   = "user=local:snippets/cloud-init.yml"
  ipconfig0  = "ip=192.168.101.${count.index + 101}/16,gw=192.168.1.1"
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
    model   = "virtio" # Use the VirtIO network driver.
    bridge  = "vmbr0"  # Connect to the Proxmox bridge.
      macaddr = format("DE:AD:BE:FF:%02X:%02X", count.index, count.index % 256)
	}
} 
variable "base_control_ip_octet" {
  default = 101  # Only define the last octet
}

variable "base_worker_ip_octet" {
  default = 101  # Only define the last octet
}
resource "null_resource" "inventory" {
  depends_on = [
    proxmox_vm_qemu.control_nodes,
    proxmox_vm_qemu.worker_nodes
  ]

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${var.inventory_path}

      # Prime control node (first control node)
      echo "[prime_control]" > ${var.inventory_path}/inventory.ini
      echo "192.168.100.${var.base_control_ip_octet}" >> ${var.inventory_path}/inventory.ini
      echo "" >> ${var.inventory_path}/inventory.ini

      # Secondary control nodes (all other control nodes)
      echo "[secondary_control]" >> ${var.inventory_path}/inventory.ini
      if [ ${var.control_nodes_count} -gt 1 ]; then
        echo "$(echo ${join("\n", formatlist("192.168.100.%d", range(var.base_control_ip_octet + 1, var.base_control_ip_octet + var.control_nodes_count + 1)))})" >> ${var.inventory_path}/inventory.ini
      fi
      echo "" >> ${var.inventory_path}/inventory.ini

      # Group all control nodes
      echo "[control_nodes:children]" >> ${var.inventory_path}/inventory.ini
      echo "prime_control" >> ${var.inventory_path}/inventory.ini
      if [ ${var.control_nodes_count} -gt 1 ]; then
        echo "secondary_control" >> ${var.inventory_path}/inventory.ini
      fi
      echo "" >> ${var.inventory_path}/inventory.ini

      # Worker nodes
      echo "[worker_nodes]" >> ${var.inventory_path}/inventory.ini
      if [ ${var.worker_nodes_count} -gt 0 ]; then
        echo "$(echo ${join("\n", formatlist("192.168.101.%d", range(var.base_worker_ip_octet, var.base_worker_ip_octet + var.worker_nodes_count +1)))})" >> ${var.inventory_path}/inventory.ini
      fi
    EOT
  }
}

