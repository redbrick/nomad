job "atlas" {
  datacenters = ["aperture"]
  type = "service"

  group "nginx-atlas" {
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
        "traefik.http.routers.nginx-atlas.rule=Host(`redbrick.dcu.ie`) || Host(`rb.dcu.ie`)",
        "traefik.http.routers.nginx-atlas.entrypoints=web,websecure",
        "traefik.http.routers.nginx-atlas.tls.certresolver=lets-encrypt",
        "traefik.http.routers.nginx-atlas.middlewares=redirect-user-web",
        "traefik.http.middlewares.redirect-user-web.redirectregex.permanent=true",
        "traefik.http.middlewares.redirect-user-web.redirectregex.regex=https://redbrick\\.dcu\\.ie/~([^/]*)(/)?(.*)?",
        "traefik.http.middlewares.redirect-user-web.redirectregex.replacement=https://$1.redbrick.dcu.ie/$2",
      ]
    }

    task "web" {
      driver = "docker"

      config {
        image = "ghcr.io/redbrick/atlas:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 500
      }
    }
  }
}
