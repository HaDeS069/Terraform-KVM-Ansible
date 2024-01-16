terraform {
  required_version = ">=0.12"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_volume" "vm_disk" {
  count  = 3  # Modifier ici pour le nombre de VMs
  name   = "vm-disk-${count.index}.qcow2"
  pool   = "default"
  format = "qcow2"
  source = "/home/hades/project/terraform/KVM/debian-11-genericcloud-amd64-20210814-734.qcow2"
}

resource "libvirt_network" "vm_network" {
  name      = "vm_network"
  addresses = ["10.0.1.0/24"]
  mode      = "nat"
  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "commoninit.iso"
  user_data = data.template_file.user_data.rendered
}

resource "libvirt_domain" "myvm" {
  count = 3  # Modifier ici pour le nombre de VMs

  name   = "myvm-${count.index}"
  memory = "1024"
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name = libvirt_network.vm_network.name
  }
  disk {
    volume_id = libvirt_volume.vm_disk[count.index].id
  }
  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}



