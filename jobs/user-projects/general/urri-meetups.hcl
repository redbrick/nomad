job "urri-meetups" {
  datacenters = ["aperture"]
  type        = "service"

  group "urri-meetups" {
    count = 1

    network {
      port "http" {
        to = 8000
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
        "traefik.http.routers.urri-meetups.rule=Host(`urri-meetups.rb.dcu.ie`)",
        "traefik.http.routers.urri-meetups.entrypoints=web,websecure",
        "traefik.http.routers.urri-meetups.tls.certresolver=lets-encrypt",
      ]
    }

    task "web" {
      driver = "docker"

      config {
        image      = "ghcr.io/haefae222/pizza_app:latest"
        ports      = ["http"]
        force_pull = true
      }

      resources {
        cpu    = 1000
        memory = 800
      }
    }
  }
}
