job "atlas" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    git-sha = ""
  }

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
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nginx-atlas.rule=Host(`redbrick.dcu.ie`) || Host(`www.redbrick.dcu.ie`) || Host(`www.rb.dcu.ie`) || Host(`rb.dcu.ie`)",
        "traefik.http.routers.nginx-atlas.entrypoints=web,websecure",
        "traefik.http.routers.nginx-atlas.tls.certresolver=rb",
        "traefik.http.routers.nginx-atlas.middlewares=atlas-www-redirect,redirect-user-web",
        # redirect redbrick.dcu.ie/~user to user.redbrick.dcu.ie
        "traefik.http.middlewares.redirect-user-web.redirectregex.regex=https://redbrick\\.dcu\\.ie/~([^/]*)/?([^/].*)?",
        "traefik.http.middlewares.redirect-user-web.redirectregex.replacement=https://$1.redbrick.dcu.ie/$2",
        "traefik.http.middlewares.redirect-user-web.redirectregex.permanent=true",
        # redirect www.redbrick.dcu.ie to redbrick.dcu.ie
        "traefik.http.middlewares.atlas-www-redirect.redirectregex.regex=^https?://www.redbrick.dcu.ie/(.*)",
        "traefik.http.middlewares.atlas-www-redirect.redirectregex.replacement=https://redbrick.dcu.ie/$${1}",
        "traefik.http.middlewares.atlas-www-redirect.redirectregex.permanent=true",
      ]
    }

    task "web" {
      driver = "docker"

      config {
        image      = "ghcr.io/redbrick/atlas:latest"
        ports      = ["http"]
        force_pull = true
      }

      resources {
        cpu    = 100
        memory = 50
      }
    }
  }
}
