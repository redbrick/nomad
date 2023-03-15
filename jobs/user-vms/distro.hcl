job "distro-vm" {
  datacenters = ["aperture"]

  group "distro-vm" {

    network {
      port "ssh" {
        to = -1
      }

      mode = "host"
    }

    service {
      name = "distro-vm"
    }

    task "distro-vm" {
      resources {
        cpu = 1000
        memory = 1024
      }

      artifact {
        source = "https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
        destination = "local/debian.qcow2"
        mode = "file"
      }

      driver = "qemu"

      config {
        image_path = "local/debian.qcow2"

        accelerator = "kvm"

        drive_interface = "virtio"

        port_map {
          ssh = 22
        }
        
        args = [
          "-net",
          "nic,model=virtio",
          "-net",
          "user",
          "-smbios",
          "type=1,serial=ds=nocloud-net;s=http://10.10.0.4:8000/",
        ]
      }
    }
  }
}

