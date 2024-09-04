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

      resources {
        cpu    = 12000
        memory = 4096
      }

      artifact {
        source      = "http://vm-resources.service.consul:8000/res/base-images/debian-12-genericcloud-amd64-30G.qcow2"
        destination = "local/ayden-vm.qcow2"
        mode        = "file"
      }

      driver = "qemu"

      config {
        image_path      = "local/ayden-vm.qcow2"
        accelerator     = "kvm"
        drive_interface = "virtio"

        args = [
          "-netdev",
          "bridge,id=hn0",
          "-device",
          "virtio-net-pci,netdev=hn0,id=nic1,mac=52:54:84:ba:49:20", # mac address must be unique or else you will regret it
          "-smbios",
          "type=1,serial=ds=nocloud-net;s=http://vm-resources.service.consul:8000/res/ayden-vm/",
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

      resources {
        cpu    = 12000
        memory = 4096
      }

      artifact {
        source      = "http://vm-resources.service.consul:8000/res/base-images/debian-12-genericcloud-amd64-30G.qcow2"
        destination = "local/hypnoant-vm.qcow2"
        mode        = "file"
      }

      driver = "qemu"

      config {
        image_path      = "local/hypnoant-vm.qcow2"
        accelerator     = "kvm"
        drive_interface = "virtio"

        args = [
          "-netdev",
          "bridge,id=hn0",
          "-device",
          "virtio-net-pci,netdev=hn0,id=nic1,mac=52:54:84:ba:49:22",
          "-smbios",
          "type=1,serial=ds=nocloud-net;s=http://vm-resources.service.consul:8000/res/hypnoant-vm/",
        ]
      }
    }
  }
}
