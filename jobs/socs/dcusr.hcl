job "dcusr" {
  datacenters = ["aperture"]

  type = "service"

  group "dcusr" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
    }

    service {
      name = "dcusr"
      port = "http"

      check {
        type = "http"
        path = "/"
        interval = "10s"
        timeout = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dcusr.rule=Host(`solarracing.rb.dcu.ie`) || Host(`solarracing.ie`) || Host(`www.solarracing.ie`)",
        "traefik.http.routers.dcusr.entrypoints=web,websecure",
        "traefik.http.routers.dcusr.tls.certresolver=lets-encrypt",
      ]
    }

    task "nextjs-website" {
      driver = "docker"

      config {
        image = "ghcr.io/dcu-solar-racing/nextjs-website:main"
        ports = ["http"]
        force_pull = true
        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }
      }
      template {
        destination = "secrets/secret.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
DOCKER_USER={{ key "dcusr/ghcr/username" }}
DOCKER_PASS={{ key "dcusr/ghcr/password" }}
TO_EMAIL={{ key "dcusr/nodemailer/to" }}
EMAIL={{ key "dcusr/nodemailer/from" }}
EMAIL_PASS={{ key "dcusr/nodemailer/password" }}
LISTMONK_ENDPOINT={{ key "dcusr/listmonk/endpoint" }}
LISTMONK_USERNAME={{ key "dcusr/listmonk/username" }}
LISTMONK_PASSWORD={{ key "dcusr/listmonk/password" }}
LISTMONK_LIST_IDS={{ key "dcusr/listmonk/list/id" }}
NEXT_PUBLIC_RECAPTCHA_SITE_KEY={{ key "dcusr/recaptcha/site/key" }}
RECAPTCHA_SECRET_KEY={{ key "dcusr/recaptcha/secret/key" }}
EOH
      }
    }
  }
}
