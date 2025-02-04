#!/bin/bash
# Credits to House of Logic original author: [Original Source](https://github.com/HouseOfLogicGH/ProxmoxPVE/blob/main/TerraformOpenTofuCloudInit/cloudinitsetuporacular.sh)
# Also their youtube videos were SUPER helpful: [Proxmox cloud init terraform tutorial](https://www.youtube.com/watch?v=HbBblJOZs-c)

# run these commands on the proxmox host as root
# Note to self: cd $(dirname $(find / -name 'debian-12.9.0-amd64-netinst.iso'))
# was useful for finding where the heck isos are stored

# download the image: we're going to use 24.04 (the most recent LTS as of this commit)
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
echo "URL: $IMG_URL"
IMG_FILE=$(basename "$IMG_URL")
echo "FILE: $IMG_FILE"
ISO_DIR="/var/lib/vz/template/iso"
echo "DIR: $ISO_DIR"
IMG_PATH="$ISO_DIR/$IMG_FILE"
echo "FULL PATH: $IMG_PATH"

# Check if the file already exists before downloading
if [[ -f "$IMG_PATH" ]]; then
    echo "Image already exists at $IMG_PATH, skipping download."
else
    echo "Downloading image..."
    wget "$IMG_URL" -O "$IMG_PATH"
fi

# install libguestfs package for the virt-customise tool 
apt update -y && apt install libguestfs-tools -y

# configure the image with qemu-guest-agent using virt customise
# Virt customize comes with libguestfs-tools and lets us install packages directly into images (COOL!!)
virt-customize -a $IMG_PATH --install qemu-guest-agent

# create a new VM with VirtIO SCSI controller
qm create 9000 --memory 2048 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci

# import the downloaded disk to the local-lvm storage, attaching it as a SCSI drive
# note that import path must be a full path, not relative
qm set 9000 --scsi0 local-lvm:0,import-from=$IMG_PATH

# set boot and display options
# An ide2 is basically emulating an old CD Drive. Cloud Init needs some way to get 
# Configuration data
# qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --scsi1 local-lvm:cloudinit
qm set 9000 --serial0 socket --vga serial0

# very important - had to be updated in the image
qm set 9000 --boot c --bootdisk scsi0

qm set 9000 --citype nocloud # for linux

qm cloudinit update 9000 # necessary for some reason

# turn the VM into a template
qm template 9000
