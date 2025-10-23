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
      resources {
        cpu    = 12000
        memory = 16384
      }

      artifact {
        source      = "http://vm-resources.service.consul:8000/bastion/bastion-vm-latest.qcow2"
        destination = "local/bastion-vm.qcow2"
        mode        = "file"
      }

      driver = "qemu"

      config {
        image_path      = "local/bastion-vm.qcow2"
        accelerator     = "kvm"
        drive_interface = "virtio"

        args = [
          "-netdev",
          "bridge,id=hn0",
          "-device",
          "virtio-net-pci,netdev=hn0,id=nic1,mac=52:54:84:ba:49:02",
          "-smbios",
          #"type=1,serial=ds=nocloud-net;s=http://10.10.0.5:8000/bastion-vm/",
          "type=1",
        ]
      }
    }
  }
}

