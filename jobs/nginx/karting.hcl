job "nginx-karting" {
  datacenters = ["aperture"]

  type = "service"

  group "karting-web" {
    count = 1

    network {
      port "http" {
        to = "80"
      }

      port "https" {
        to = "443"
      }
    }

    service {
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nginx-karting.rule=Host(`karting.rb.dcu.ie`)",
        "traefik.http.routers.nginx-karting.entrypoints=web,websecure",
        "traefik.http.routers.nginx-karting.tls.certresolver=rb"
      ]
    }

    task "webserver" {
      driver = "docker"

      config {
        image = "ghcr.io/redbrick/karting"
        ports = ["http", "https"]
      }
    }
  }
}
