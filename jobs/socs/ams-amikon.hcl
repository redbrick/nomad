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
        to = 3000
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
        "traefik.http.routers.ams-amikon.rule=Host(`amikon.me`) || Host(`www.amikon.me`) || Host(`amikon.rb.dcu.ie`)",
        "traefik.http.routers.ams-amikon.entrypoints=web,websecure",
        "traefik.http.routers.ams-amikon.tls.certresolver=lets-encrypt",
        "traefik.http.routers.ams-amikon.middlewares=amikon-www-redirect",
        "traefik.http.middlewares.amikon-www-redirect.redirectregex.regex=^https?://www.amikon.me/(.*)",
        "traefik.http.middlewares.amikon-www-redirect.redirectregex.replacement=https://amikon.me/$${1}",
        "traefik.http.middlewares.amikon-www-redirect.redirectregex.permanent=true",
      ]
    }

    task "amikon-node" {
      driver = "docker"

      config {
        image      = "ghcr.io/dcuams/amikon-site-v2:latest"
        force_pull = true
        ports      = ["http"]
      }

      template {
        data        = <<EOF
      EMAIL={{ key "ams/amikon/email/user" }}
      EMAIL_PASS={{ key "ams/amikon/email/password" }}
      TO_EMAIL={{ key "ams/amikon/email/to" }}
      EOF
        destination = ".env"
        env         = true
      }

      resources {
        cpu    = 800
        memory = 500
      }
    }
  }
}
