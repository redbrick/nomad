job "dcusr-openproject" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "projects.solarracing.ie"
  }

  group "openproject" {
    count = 1

    # Lets Traefik drop the instance before the container is killed.
    shutdown_delay = "10s"

    network {
      port "http" {
        to = 80
      }
    }

    consul {
      cluster = "default"
    }

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "30s"
      healthy_deadline  = "10m" # first boot runs migrations and asset setup
      progress_deadline = "15m"
      auto_revert       = true
    }

    restart {
      attempts = 20
      delay    = "10s"
      interval = "10m"
      mode     = "delay"
    }

    service {
      name = "dcusr-openproject"
      port = "http"

      check {
        name     = "openproject-health"
        type     = "http"
        path     = "/health_checks/default"
        interval = "15s"
        timeout  = "5s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.dcusr-openproject.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-openproject.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.dcusr-openproject.tls=true",
      ]
    }

    task "wait-for-db" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "postgres:17-alpine"
        command = "sh"
        args = [
          "-c",
          "until pg_isready -h \"$DB_HOST\" -p \"$DB_PORT\" -U \"$DB_USER\"; do echo 'Waiting for DB...'; sleep 2; done; echo 'DB is ready!'",
        ]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/wait.env"
        env         = true
        data        = <<EOH
{{- with service "dcusr-openproject-db" }}{{ with index . 0 }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{- end }}{{ else }}
DB_HOST=db-unavailable.invalid
DB_PORT=5432
{{- end }}
DB_USER={{ key "socs/dcusr/openproject/db/user" }}
EOH
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }

    task "openproject-aio" {
      driver = "docker"

      config {
        image      = "ghcr.io/aydenjahola/openproject:main"
        force_pull = true
        ports      = ["http"]

        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/assets:/var/openproject/assets",
        ]
      }

      # If the DB service is missing, DATABASE_URL must still be set: without
      # it the AIO image silently starts its own empty internal Postgres.
      # Pointing at an unresolvable host makes the container fail and retry.
      template {
        destination = "${NOMAD_SECRETS_DIR}/app.env"
        env         = true
        data        = <<EOH
DOCKER_USER={{ key "socs/dcusr/openproject/ghcr/username" }}
DOCKER_PASS={{ key "socs/dcusr/openproject/ghcr/password" }}

{{- with service "dcusr-openproject-db" }}{{ with index . 0 }}
DATABASE_URL=postgres://{{ key "socs/dcusr/openproject/db/user" }}:{{ key "socs/dcusr/openproject/db/password" }}@{{ .Address }}:{{ .Port }}/{{ key "socs/dcusr/openproject/db/name" }}
{{- end }}{{ else }}
DATABASE_URL=postgres://unavailable@db-unavailable.invalid:5432/openproject
{{- end }}

OPENPROJECT_HOST__NAME={{ env "NOMAD_META_domain" }}
OPENPROJECT_HTTPS=true

OPENPROJECT_SECRET_KEY_BASE={{ key "socs/dcusr/openproject/secret_key_base" }}
SECRET_KEY_BASE={{ key "socs/dcusr/openproject/secret_key_base" }}

EMAIL_DELIVERY_METHOD=smtp
SMTP_ADDRESS={{ key "socs/dcusr/openproject/smtp/address" }}
SMTP_PORT={{ key "socs/dcusr/openproject/smtp/port" }}
SMTP_DOMAIN={{ key "socs/dcusr/openproject/smtp/domain" }}
SMTP_AUTHENTICATION={{ key "socs/dcusr/openproject/smtp/auth" }}
SMTP_USER_NAME={{ key "socs/dcusr/openproject/smtp/username" }}
SMTP_PASSWORD={{ key "socs/dcusr/openproject/smtp/password" }}
SMTP_ENABLE_STARTTLS_AUTO=true

OPENPROJECT_DISABLE__PASSWORD__LOGIN=true

OPENPROJECT_OPENID__CONNECT_AUTHENTIK_DISPLAY__NAME="DCUSR Auth"
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_IDENTIFIER={{ key "socs/dcusr/openproject/oidc/client_id" }}
OPENPROJECT_OPENID__CONNECT_AUTHENTIK_SECRET={{ key "socs/dcusr/openproject/oidc/client_secret" }}
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

  group "database" {
    count = 1

    network {
      port "db" {
        to = 5432
      }
    }

    consul {
      cluster = "default"
    }

    update {
      max_parallel = 0 # never roll the database automatically
      auto_revert  = false
    }

    task "postgres" {
      driver         = "docker"
      kill_signal    = "SIGTERM" # smart shutdown instead of SIGKILL
      kill_timeout   = "30s"
      shutdown_delay = "5s"

      service {
        name = "dcusr-openproject-db"
        port = "db"

        check {
          name     = "postgres-ready"
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "pg_isready -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\""]
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/data",
        ]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/db.env"
        env         = true
        data        = <<EOH
POSTGRES_DB={{ key "socs/dcusr/openproject/db/name" }}
POSTGRES_USER={{ key "socs/dcusr/openproject/db/user" }}
POSTGRES_PASSWORD={{ key "socs/dcusr/openproject/db/password" }}
EOH
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }
}
