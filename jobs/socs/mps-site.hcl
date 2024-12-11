job "mps-site" {
  datacenters = ["aperture"]
  type        = "service"

  group "mps-django" {
    count = 1

    network {
      port "http" {
        to = 8000
      }
    }

    service {
      name = "mps-django"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "5s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.mps-django.rule=Host(`mps.rb.dcu.ie`) || Host(`dcumps.ie`) || Host(`www.dcumps.ie`) || Host(`dcumps.com`) || Host(`www.dcumps.com`)",
        "traefik.http.routers.mps-django.entrypoints=web,websecure",
        "traefik.http.routers.mps-django.tls.certresolver=lets-encrypt",
        "traefik.http.routers.mps-django.middlewares=mps-django-redirect-com",
        "traefik.http.middlewares.mps-django-redirect-com.redirectregex.regex=dcumps\\.com/(.*)",
        "traefik.http.middlewares.mps-django-redirect-com.redirectregex.replacement=dcumps.ie/$1",
      ]
    }

    task "django-web" {
      driver = "docker"

      config {
        image      = "ghcr.io/dcumps/dcumps-website-django:latest"
        ports      = ["http"]
        force_pull = true
        hostname   = "${NOMAD_TASK_NAME}"
        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }
      }

      template {
        data        = <<EOH
DOCKER_USER={{ key "mps/site/ghcr/username" }}
DOCKER_PASS={{ key "mps/site/ghcr/password" }}
EOH
        destination = "local/.env"
        env         = true
      }

      resources {
        cpu    = 300
        memory = 500
      }
    }
  }
}
