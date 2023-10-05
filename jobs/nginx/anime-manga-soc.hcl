job "nginx-ams" {
  datacenters = ["aperture"]

  type = "service"

  group "ams-web" {
    count = 1

    network {
      port "http" {
        to = 3000
      }

      port "https" {
        to = 3000
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
        "traefik.http.routers.nginx-ams.rule=Host(`amikon.me`,`www.amikon.me`)",
        "traefik.http.routers.nginx-ams.entrypoints=web,websecure",
        "traefik.http.routers.nginx-ams.tls.certresolver=lets-encrypt",
        "traefik.http.routers.nginx-ams.loadbalancer.server.port=${NOMAD_PORT_http}"
      ]
    }

    task "webserver" {
      driver = "docker"

      config {
        image = "ghcr.io/dcuams/amikon-website-v2"
        ports = ["http", "https"]
      }
    }
  }
}
