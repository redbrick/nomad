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
        "traefik.http.routers.dcusr.rule=Host(`dcusr.aperture.redbrick.dcu.ie`)",
        "traefik.http.routers.dcusr.entrypoints=web,websecure",
        "traefik.http.routers.dcusr.tls.certresolver=lets-encrypt",
      ]
    }

    task "nextjs-website" {
      driver = "docker"

      config {
        image = "ghcr.io/dcu-solar-racing/nextjs-website:main"
        ports = ["http"]
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
EOH
      }
    }
  }
}
