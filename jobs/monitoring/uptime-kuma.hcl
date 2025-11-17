job "uptime-kuma" {
  datacenters = ["aperture"]
  type        = "service"

  group "web" {
    count = 1

    network {
      port "http" {
        to = 3001
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
        "traefik.http.routers.uptime-kuma.rule=Host(`status.redbrick.dcu.ie`)",
        "traefik.http.routers.uptime-kuma.entrypoints=web,websecure",
        "traefik.http.routers.uptime-kuma.tls.certresolver=lets-encrypt",
      ]
    }

    task "web" {
      driver = "docker"

      config {
        image = "louislam/uptime-kuma:2"
        ports = ["http"]
        volumes = [
          "/storage/nomad/uptime-kuma/data:/app/data"
        ]
      }
      resources {
        cpu    = 512
        memory = 800
      }
    }
  }
}
