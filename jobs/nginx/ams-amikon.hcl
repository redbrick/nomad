job "ams-amikon" {
  datacenters = ["aperture"]

  meta {
    run_uuid = "${uuidv4()}"
  }

  type = "service"

  group "ams-amikon" {
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
        "traefik.http.routers.ams-amikon.rule=Host(`amikon.me`,`www.amikon.me`)",
        "traefik.http.routers.ams-amikon.entrypoints=web,websecure",
        "traefik.http.routers.ams-amikon.tls.certresolver=lets-encrypt",
        "traefik.http.routers.ams-amikon.middlewares=www-redirect",
        "traefik.http.middlewares.www-redirect.redirectregex.regex=^https?://www.amikon.me/(.*)",
        "traefik.http.middlewares.www-redirect.redirectregex.replacement=https://amikon.me/$${1}",
        "traefik.http.middlewares.www-redirect.redirectregex.permanent=true",
      ]
    }

    task "amikon-nginx" {
      driver = "docker"

      config {
        image = "ghcr.io/dcuams/amikon-site-v2:latest"
        force_pull = true
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 50
      }
    }
  }
}
