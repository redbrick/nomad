job "11ty-website" {
  datacenters = ["aperture"]
  type = "service"

  group "nginx-11ty-website" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    service {
      port = "http"

      check {
        type = "http"
        path = "/"
        interval = "10s"
        timeout = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nginx-11ty-website.rule=Host(`canary.redbrick.dcu.ie`)",
        "traefik.http.routers.nginx-11ty-website.entrypoints=web,websecure",
        "traefik.http.routers.nginx-11ty-website.tls.certresolver=lets-encrypt",
      ]
    }

    task "webserver" {
      driver = "docker"

      config {
        image = "ghcr.io/redbrick/11ty-website:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 500
      }
    }
  }
}
