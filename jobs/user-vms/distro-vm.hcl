job "distro-vm" {
  datacenters = ["aperture"]

  group "distro-vm" {

    network {
      mode = "host"
    }

    service {
      name = "distro-vm"
    }

    task "distro-vm" {

      resources {
        cpu = 12000
        memory = 4096
      }

      artifact {
        source = "http://vm-resources.service.consul:8000/res/base-images/debian-12-genericcloud-amd64-30G.qcow2"
        destination = "local/distro-vm.qcow2"
        mode = "file"
      }

      driver = "qemu"

      config {
        image_path = "local/distro-vm.qcow2"
        accelerator = "kvm"
        drive_interface = "virtio"

        args = [
          "-netdev",
          "bridge,id=hn0",
          "-device",
          "virtio-net-pci,netdev=hn0,id=nic1,mac=52:54:84:ba:49:01",
          "-smbios",
          "type=1,serial=ds=nocloud-net;s=http://136.206.16.5:8000/distro-vm/",
        ]
      }
    }
  }
}

