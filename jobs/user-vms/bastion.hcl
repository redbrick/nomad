job "bastion-vm" {
  datacenters = ["aperture"]

  group "bastion-vm" {

    network {
      mode = "host"
    }

    service {
      name = "bastion-vm"
    }

    task "bastion-vm" {
      constraint {
        attribute = "${attr.unique.hostname}"
        value = "chell"
      }

      resources {
        cpu = 12000
        memory = 4096
      }

      artifact {
        source = "http://10.10.0.5:8000/base-images/debian-12-genericcloud-amd64-30G.qcow2"
        destination = "local/bastion-vm.qcow2"
        mode = "file"
      }

      driver = "qemu"

      config {
        image_path = "local/bastion-vm.qcow2"
        accelerator = "kvm"
        drive_interface = "virtio"

        args = [
          "-netdev",
          "bridge,id=hn0",
          "-device",
          "virtio-net-pci,netdev=hn0,id=nic1,mac=52:54:84:ba:49:02",
          "-smbios",
          "type=1,serial=ds=nocloud-net;s=http://10.10.0.5:8000/bastion-vm/",
        ]
      }
    }
  }
}

