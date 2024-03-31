job "api" {
  datacenters = ["aperture"]

  type = "service"

  group "api" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "api"
      port = "http"

      check {
        type = "http"
        path = "/"
        interval = "10s"
        timeout = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.api.rule=Host(`api.redbrick.dcu.ie`)",
        "traefik.http.routers.api.entrypoints=web,websecure",
        "traefik.http.routers.api.tls.certresolver=lets-encrypt",
      ]
    }

    task "api" {
      driver = "docker"

      config {
        image = "ghcr.io/redbrick/api:latest"
        ports = ["http"]
        volumes = [
          "/oldstorage:/storage",
          "/oldstorage/home:/home",
          "local/ldap.secret:/etc/ldap.secret",
        ]
        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }
      }
      template {
        destination = "local/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
DOCKER_USER={{ key "api/ghcr/username" }}
DOCKER_PASS={{ key "api/ghcr/password" }}
AUTH_USERNAME={{ key "api/auth/username" }}
AUTH_PASSWORD={{ key "api/auth/password" }}
LDAP_URI={{ key "api/ldap/uri" }}
LDAP_ROOTBINDDN={{ key "api/ldap/rootbinddn" }}
LDAP_SEARCHBASE={{ key "api/ldap/searchbase" }}
EMAIL_DOMAIN=redbrick.dcu.ie
EMAIL_SERVER={{ key "api/smtp/server" }}
EMAIL_PORT=587
EMAIL_USERNAME={{ key "api/smtp/username" }}
EMAIL_PASSWORD={{ key "api/smtp/password" }}
EMAIL_SENDER={{ key "api/smtp/sender" }}
EOH
      }

    template {
        destination = "local/ldap.secret"
        data = "{{ key \"api/ldap/secret\" }}"
      }

      resources {
        cpu = 300
        memory = 1024
      }
    }
  }
}
