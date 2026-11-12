job "authentik" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "auth.solarracing.ie"
  }

  group "web" {
    count = 1

    network {
      port "http" {
        to = 9000
      }
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    service {
      name = "authentik"
      port = "http"

      check {
        type     = "http"
        path     = "/-/health/live/"
        interval = "30s"
        timeout  = "5s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.authentik-website.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.authentik-website.entrypoints=web,websecure",
        "traefik.http.routers.authentik-website.tls=true"
      ]
    }

    task "wait-for-deps" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "alpine:3.19"
        command = "sh"
        args = [
          "-c",
          "while ! nc -z \"$DB_HOST\" \"$DB_PORT\"; do echo 'Waiting for Postgres...'; sleep 1; done; while ! nc -z \"$REDIS_HOST\" \"$REDIS_PORT\"; do echo 'Waiting for Redis...'; sleep 1; done; echo 'Dependencies ready!'"
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
{{- range service "authentik-db" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{- end }}
{{- range service "authentik-redis" }}
REDIS_HOST={{ .Address }}
REDIS_PORT={{ .Port }}
{{- end }}
EOH
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }

    task "init-authentik-permissions" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image   = "busybox:latest"
        command = "sh"

        args = [
          "-c",
          "mkdir -p /media /certs /templates /blueprints/custom && chown -R 1000:1000 /media /certs /templates /blueprints",
        ]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/media:/media:rw",
          "/storage/nomad/${NOMAD_JOB_NAME}/certs:/certs:rw",
          "/storage/nomad/${NOMAD_JOB_NAME}/templates:/templates:rw",
          "/storage/nomad/${NOMAD_JOB_NAME}/blueprints:/blueprints:rw",
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    task "authentik-server" {
      driver = "docker"

      config {
        image      = "authentik/server:2026.8"
        ports      = ["http"]
        force_pull = true
        args       = ["server"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/media:/media",
          "/storage/nomad/${NOMAD_JOB_NAME}/templates:/templates",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
AUTHENTIK_SECRET_KEY={{ key "socs/authentik/secret/key" }}

AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS=136.206.16.0/24,10.10.10.0/24,172.17.0.0/16

AUTHENTIK_ERROR_REPORTING__ENABLED=false
AUTHENTIK_DISABLE_UPDATE_CHECK=false
AUTHENTIK_AVATARS=initials

AUTHENTIK_BOOTSTRAP_EMAIL={{ key "socs/authentik/bootstrap/email" }}
AUTHENTIK_BOOTSTRAP_PASSWORD={{ key "socs/authentik/bootstrap/password" }}
AUTHENTIK_BOOTSTRAP_TOKEN={{ key "socs/authentik/bootstrap/token" }}

{{ range service "authentik-db" -}}
AUTHENTIK_POSTGRESQL__HOST={{ .Address }}
AUTHENTIK_POSTGRESQL__PORT={{ .Port }}
{{- end }}
AUTHENTIK_POSTGRESQL__NAME={{ key "socs/authentik/db/name" }}
AUTHENTIK_POSTGRESQL__USER={{ key "socs/authentik/db/user" }}
AUTHENTIK_POSTGRESQL__PASSWORD={{ key "socs/authentik/db/password" }}

{{ range service "authentik-redis" -}}
AUTHENTIK_REDIS__HOST={{ .Address }}
AUTHENTIK_REDIS__PORT={{ .Port }}
{{- end }}

SMTP_HOST={{ key "socs/dcusr/authentik/smtp/host" }}
AUTHENTIK_EMAIL__HOST={{ key "socs/dcusr/authentik/smtp/host" }}
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USERNAME={{ key "socs/dcusr/authentik/smtp/user" }}
AUTHENTIK_EMAIL__PASSWORD={{ key "socs/dcusr/authentik/smtp/password" }}
AUTHENTIK_EMAIL__USE_TLS=true
AUTHENTIK_EMAIL__FROM={{ key "socs/dcusr/authentik/mail/from" }}
EOH
      }

      resources {
        cpu    = 500
        memory = 2048
      }
    }

    task "authentik-worker" {
      driver = "docker"

      config {
        image      = "authentik/server:2026.8"
        force_pull = true
        args       = ["worker"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/certs:/certs",
          "/storage/nomad/${NOMAD_JOB_NAME}/media:/media",
          "/storage/nomad/${NOMAD_JOB_NAME}/templates:/templates",
          "/storage/nomad/${NOMAD_JOB_NAME}/blueprints:/blueprints/custom",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
AUTHENTIK_SECRET_KEY={{ key "socs/authentik/secret/key" }}

AUTHENTIK_ERROR_REPORTING__ENABLED=false
AUTHENTIK_DISABLE_UPDATE_CHECK=true

{{ range service "authentik-db" -}}
AUTHENTIK_POSTGRESQL__HOST={{ .Address }}
AUTHENTIK_POSTGRESQL__PORT={{ .Port }}
{{- end }}
AUTHENTIK_POSTGRESQL__NAME={{ key "socs/authentik/db/name" }}
AUTHENTIK_POSTGRESQL__USER={{ key "socs/authentik/db/user" }}
AUTHENTIK_POSTGRESQL__PASSWORD={{ key "socs/authentik/db/password" }}

{{ range service "authentik-redis" -}}
AUTHENTIK_REDIS__HOST={{ .Address }}
AUTHENTIK_REDIS__PORT={{ .Port }}
{{- end }}

SMTP_HOST={{ key "socs/dcusr/authentik/smtp/host" }}
AUTHENTIK_EMAIL__HOST={{ key "socs/dcusr/authentik/smtp/host" }}
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USERNAME={{ key "socs/dcusr/authentik/smtp/user" }}
AUTHENTIK_EMAIL__PASSWORD={{ key "socs/dcusr/authentik/smtp/password" }}
AUTHENTIK_EMAIL__USE_TLS=true
AUTHENTIK_EMAIL__FROM={{ key "socs/dcusr/authentik/mail/from" }}
EOH
      }

      resources {
        cpu    = 500
        memory = 1024
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

    update {
      max_parallel = 0 # don't update this group automatically
      auto_revert  = false
    }

    task "db" {
      driver         = "docker"
      kill_signal    = "SIGTERM" # SIGTERM instead of SIGKILL so database can shutdown safely
      kill_timeout   = "30s"
      shutdown_delay = "5s"

      service {
        name = "authentik-db"
        port = "db"

        check {
          type     = "script"
          name     = "postgres-ready"
          command  = "/bin/sh"
          args     = ["-c", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
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
        destination = "local/.env"
        env         = true
        data        = <<EOH
POSTGRES_DB={{ key "socs/authentik/db/name" }}
POSTGRES_USER={{ key "socs/authentik/db/user" }}
POSTGRES_PASSWORD={{ key "socs/authentik/db/password" }}
EOH
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  group "redis" {
    count = 1

    network {
      port "redis" {
        to = 6379
      }
    }

    update {
      max_parallel = 0 # don't update this group automatically
      auto_revert  = false
    }

    task "redis" {
      driver         = "docker"
      kill_signal    = "SIGTERM"
      kill_timeout   = "10s"
      shutdown_delay = "5s"

      service {
        name = "authentik-redis"
        port = "redis"

        check {
          type     = "script"
          name     = "redis-ready"
          command  = "/bin/sh"
          args     = ["-c", "redis-cli ping | grep -q PONG"]
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image = "redis:7-alpine"
        ports = ["redis"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/data",
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}

