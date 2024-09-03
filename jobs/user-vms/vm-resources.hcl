job "vm-resources" {
  datacenters = ["aperture"]

  type = "service"

  group "vm-resources" {
    count = 1

    network {
      port "http" {
        static = "8000"
        to = "80"
      }
    }

    service {
      name = "vm-resources"
      port = "http"
    }

    task "resource-server" {
      driver = "docker"

      config {
        image = "nginx"
        ports = ["http"]
        volumes = [
          "/storage/nomad/vm-resources/:/usr/share/nginx/html/res",
          "/storage/backups/nomad/bastion-vm:/usr/share/nginx/html/bastion",
        ]
      }
    }
  }
}
