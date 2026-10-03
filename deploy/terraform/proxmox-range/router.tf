# The range router VM: one WAN NIC on the node bridge, one NIC per VLAN. Debian 12 cloud
# image, configured by router-cloud-init. It is the gateway, NAT, DHCP/DNS and firewall for
# the whole range, and the SSH entry point for "Open shell".

locals {
  # Predictable interface names inside the router: net0 -> ens18, net1 -> ens19, ...
  # (Debian cloud images use the ens18+ scheme on q35/virtio.)
  wan_ifname = "ens18"
  vlan_ifaces = {
    for idx, vlan in local.vlans : tostring(vlan) => {
      vlan    = vlan
      gateway = local.subnets[tostring(vlan)].gateway
      ifname  = "ens${19 + idx}"
      vnet    = local.subnets[tostring(vlan)].vnet
    }
  }
  # Default rule: let the attacker VLAN reach the others. The lab can add more later.
  forward_rules = [
    for vlan in local.vlans : "iifname \"${local.vlan_ifaces[tostring(var.attacker_vlan)].ifname}\" oifname \"${local.vlan_ifaces[tostring(vlan)].ifname}\" accept"
    if vlan != var.attacker_vlan && contains(local.vlans, var.attacker_vlan)
  ]
}

resource "proxmox_download_file" "debian" {
  node_name    = var.proxmox_node
  datastore_id = var.proxmox_image_storage
  content_type = "iso"
  url          = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
  file_name    = "cyberctf-debian-12-genericcloud-amd64.img"
  overwrite    = false
}

resource "proxmox_virtual_environment_file" "router_user_data" {
  node_name    = var.proxmox_node
  datastore_id = var.proxmox_snippet_storage
  content_type = "snippets"
  source_raw {
    file_name = "ctf${var.range_number}-router.yaml"
    data = templatefile("${path.module}/router-cloud-init.yaml.tftpl", {
      range_number   = var.range_number
      wan_ifname     = local.wan_ifname
      ssh_public_key = var.ssh_public_key
      subnets        = values(local.vlan_ifaces)
      forward_rules  = local.forward_rules
    })
  }
}

resource "proxmox_virtual_environment_vm" "router" {
  name      = "ctf${var.range_number}-router"
  node_name = var.proxmox_node
  tags      = ["cyberctf", var.lab_slug, "router"]
  on_boot   = false

  agent { enabled = true }
  cpu {
    cores = 1
    type  = "host"
  }
  memory { dedicated = 1024 }

  disk {
    datastore_id = var.proxmox_storage
    file_id      = proxmox_download_file.debian.id
    interface    = "virtio0"
    size         = 8
    discard      = "on"
  }

  # net0 = WAN, then one NIC per VLAN VNet, in the same order as local.vlans.
  network_device {
    bridge = var.proxmox_uplink_bridge
  }
  dynamic "network_device" {
    for_each = local.vlans
    content {
      bridge = proxmox_sdn_vnet.vlan[tostring(network_device.value)].id
    }
  }

  operating_system { type = "l26" }
  serial_device {}

  initialization {
    datastore_id      = var.proxmox_storage
    user_data_file_id = proxmox_virtual_environment_file.router_user_data.id
    # WAN; VLAN NICs are set in cloud-init.
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  depends_on = [proxmox_sdn_applier.range]
}
