job "dcusr-openproject" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "projects.solarracing.ie"
  }

  group "openproject" {
    count = 1

    network {
      port "http" { 
        to = 80 
      }
    }
    consul { cluster = "default" }

    restart {
      attempts = 20
      delay    = "10s"
      interval = "10m"
      mode     = "delay"
    }

    service {
      name     = "openproject"
      port     = "http"

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.dcusr-openproject.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-openproject.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.dcusr-openproject.tls=true",
      ]
    }

    task "openproject-aio" {
      driver = "docker"

      config {
        image = "ghcr.io/aydenjahola/openproject:main"

        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }

        ports = ["http"]
        force_pull = true
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/pgdata:/var/openproject/pgdata",
          "/storage/nomad/${NOMAD_JOB_NAME}/assets:/var/openproject/assets",
        ]
      }

      template {
        destination = "local/app.env"
        env         = true
        data = <<EOH
DOCKER_USER={{ key "user-projects/ayden/ghcr/username" }}
DOCKER_PASS={{ key "user-projects/ayden/ghcr/password" }}

OPENPROJECT_HOST__NAME={{ env "NOMAD_META_domain" }}
OPENPROJECT_HTTPS=true

OPENPROJECT_SECRET_KEY_BASE={{ key "dcusr/openproject/secret_key_base" }}
SECRET_KEY_BASE={{ key "dcusr/openproject/secret_key_base" }}

EMAIL_DELIVERY_METHOD=smtp
SMTP_ADDRESS={{ key "dcusr/openproject/smtp/address" }}
SMTP_PORT={{ key "dcusr/openproject/smtp/port" }}
SMTP_DOMAIN={{ key "dcusr/openproject/smtp/domain" }}
SMTP_AUTHENTICATION={{ key "dcusr/openproject/smtp/auth" }}
SMTP_USER_NAME={{ key "dcusr/openproject/smtp/username" }}
SMTP_PASSWORD={{ key "dcusr/openproject/smtp/password" }}
SMTP_ENABLE_STARTTLS_AUTO=true

OPENPROJECT_DISABLE__PASSWORD__LOGIN=true

OPENPROJECT_OPENID__CONNECT_AUTHENTIK_DISPLAY__NAME="DCUSR Auth"
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_IDENTIFIER={{ key "dcusr/openproject/oidc/client_id" }}
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_SECRET={{ key "dcusr/openproject/oidc/client_secret" }}
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_ISSUER="https://auth.solarracing.ie/application/o/openproject/"
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_HOST="auth.solarracing.ie"
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_AUTHORIZATION__ENDPOINT="/application/o/authorize/"
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_TOKEN__ENDPOINT="/application/o/token/"
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_USERINFO__ENDPOINT="/application/o/userinfo/"
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_END__SESSION__ENDPOINT="/application/o/openproject/end-session/"
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_SYNC__GROUPS=true
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_GROUPS__CLAIM=groups
EOH
      }

      resources {
        cpu    = 1500
        memory = 8192
      }
    }
  }
}



