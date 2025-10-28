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
        "traefik.http.routers.dcusr-openproject.tls.certresolver=lets-encrypt",
      ]
    }

    task "openproject-aio" {
      driver = "docker"

      config {
        image = "openproject/openproject:16"
        ports = ["http"]
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/pgdata:/var/openproject/pgdata",
          "/storage/nomad/${NOMAD_JOB_NAME}/assets:/var/openproject/assets",
        ]
      }

      template {
        destination = "local/app.env"
        env         = true
        data = <<EOH
OPENPROJECT_HOST__NAME={{ env "NOMAD_META_domain" }}
OPENPROJECT_HTTPS=true

OPENPROJECT_SECRET_KEY_BASE={{ key "dcusr/openproject/secret_key_base" }}

EMAIL_DELIVERY_METHOD=smtp
SMTP_ADDRESS={{ key "dcusr/openproject/smtp/address" }}
SMTP_PORT={{ key "dcusr/openproject/smtp/port" }}
SMTP_DOMAIN={{ key "dcusr/openproject/smtp/domain" }}
SMTP_AUTHENTICATION={{ key "dcusr/openproject/smtp/auth" }}
SMTP_USER_NAME={{ key "dcusr/openproject/smtp/username" }}
SMTP_PASSWORD={{ key "dcusr/openproject/smtp/password" }}
SMTP_ENABLE_STARTTLS_AUTO=true

EOH
      }

      resources {
        cpu    = 1500
        memory = 8192
      }
    }
  }
}

