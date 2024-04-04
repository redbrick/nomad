job "admin-exams" {
  datacenters = ["aperture"]

  group "ayden-vm" {

    network {
      mode = "host"
    }

    service {
      name = "ayden-vm"
    }

    task "ayden-vm" {
      constraint {
        attribute = "${attr.unique.hostname}"
        value = "chell" # task must be scheduled on a host with the bridge device configured
      }

      resources {
        cpu = 12000
        memory = 4096
      }

      artifact {
        source = "http://136.206.16.5:8000/base-images/debian-12-genericcloud-amd64-30G.qcow2"
        destination = "local/ayden-vm.qcow2"
        mode = "file"
      }

      driver = "qemu"

      config {
        image_path = "local/ayden-vm.qcow2"
        accelerator = "kvm"
        drive_interface = "virtio"

        args = [
          "-netdev",
          "bridge,id=hn0",
          "-device",
          "virtio-net-pci,netdev=hn0,id=nic1,mac=52:54:84:ba:49:20", # mac address must be unique or else you will regret it
          "-smbios",
          "type=1,serial=ds=nocloud-net;s=http://136.206.16.5:8000/ayden-vm/",
        ]
      }
    }
  }

  group "hypnoant-vm" {

    network {
      mode = "host"
    }

    service {
      name = "hypnoant-vm"
    }

    task "hypnoant-vm" {
      constraint {
        attribute = "${attr.unique.hostname}"
        value = "wheatley"
      }

      resources {
        cpu = 12000
        memory = 4096
      }

      artifact {
        source = "http://136.206.16.5:8000/base-images/debian-12-genericcloud-amd64-30G.qcow2"
        destination = "local/hypnoant-vm.qcow2"
        mode = "file"
      }

      driver = "qemu"

      config {
        image_path = "local/hypnoant-vm.qcow2"
        accelerator = "kvm"
        drive_interface = "virtio"

        args = [
          "-netdev",
          "bridge,id=hn0",
          "-device",
          "virtio-net-pci,netdev=hn0,id=nic1,mac=52:54:84:ba:49:22",
          "-smbios",
          "type=1,serial=ds=nocloud-net;s=http://136.206.16.5:8000/hypnoant-vm/",
        ]
      }
    }
  }
}
