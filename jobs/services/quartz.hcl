job "quartz" {
  datacenters = ["aperture"]
  type        = "service"

  group "quartz" {
    count = 1

    network {
      port "http" {
        to = 8080
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
        "traefik.http.routers.nginx-quartz.rule=Host(`open-governance.redbrick.dcu.ie`)",
        "traefik.http.routers.nginx-quartz.entrypoints=web,websecure",
        "traefik.http.routers.nginx-quartz.tls.certresolver=lets-encrypt",
      ]
    }

    task "web" {
      driver = "docker"

      config {
        image = "ghcr.io/jackyzha0/quartz:latest"
        ports = ["http"]
        volumes = [
          "local/open-governance/:/usr/src/app/content/",
        ]
      }
      artifact {
        source      = "git::https://github.com/redbrick/open-governance"
        destination = "local/open-governance"
      }

      resources {
        cpu    = 100
        memory = 500
      }
    }
  }
}
