job "ams-amikon" {
  datacenters = ["aperture"]
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
        "traefik.http.routers.ams-amikon.rule=Host(`amikon.me`) || Host(`www.amikon.me`)",
        "traefik.http.routers.ams-amikon.entrypoints=web,websecure",
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
        destination = ".env"
        env         = true
        data        = <<EOF
EMAIL={{ key "ams/amikon/email/user" }}
EMAIL_PASS={{ key "ams/amikon/email/password" }}
TO_EMAIL={{ key "ams/amikon/email/to" }}
EOF
      }

      resources {
        cpu    = 800
        memory = 500
      }
    }
  }
}
