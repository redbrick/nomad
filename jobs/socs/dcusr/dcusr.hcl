job "dcusr" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain  = "solarracing.ie"
    domain2 = "www.solarracing.ie"
  }

  group "web" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }


    service {
      name = "dcusr"
      port = "http"

      check {
        type     = "http"
        path     = "/api/health"
        interval = "30s"
        timeout  = "2s"
      }


      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dcusr-website.rule=Host(`${NOMAD_META_domain}`) || Host(`${NOMAD_META_domain2}`)",
        "traefik.http.routers.dcusr-website.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-website.tls=true"
      ]
    }

    task "nextjs-website" {
      driver = "docker"

      config {
        image      = "ghcr.io/dcu-solar-racing/website:latest"
        ports      = ["http"]
        force_pull = true

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/image-cache:/app/.next/cache/images",
        ]

        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }
      }
      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
DOCKER_USER={{ key "dcusr/ghcr/username" }}
DOCKER_PASS={{ key "dcusr/ghcr/password" }}

NEXT_PUBLIC_SITE_URL=https://{{ env "NOMAD_META_domain" }}

AUTH_URL=https://{{ env "NOMAD_META_domain" }}
AUTH_TRUST_HOST=true
AUTH_SECRET={{ key "socs/dcusr-dev/auth/secret" }}

AUTH_AUTHENTIK_ISSUER={{ key "dcusr/oidc/issuer" }}
AUTH_AUTHENTIK_ID={{ key "dcusr/oidc/client/id" }}
AUTH_AUTHENTIK_SECRET={{ key "dcusr/oidc/client/secret" }}

# Authentik group names mapped to app roles (defaults shown)
AUTHENTIK_ADMIN_GROUP={{ key "dcusr/oidc/admin" }}
AUTHENTIK_EDITOR_GROUP={{ key "dcusr/oidc/editor" }}
AUTHENTIK_VIEWER_GROUP={{ key "dcusr/oidc/viewer" }}

PREVIEW_SECRET={{ key "socs/dcusr-dev/preview/secret" }}

{{ range service "dcusr-db"  -}}
DATABASE_URL=postgresql://{{ key "socs/dcusr-dev/db/user" | urlquery }}:{{ key "socs/dcusr-dev/db/password" | urlquery }}@{{ .Address }}:{{ .Port }}/{{ key "socs/dcusr-dev/db/name" | urlquery }}?schema=public
{{- end }}

MINIO_ENDPOINT={{ key "socs/dcusr-dev/minio/url" }}
MINIO_PORT={{ key "socs/dcusr-dev/minio/port" }}
MINIO_ACCESS_KEY="{{ key "socs/dcusr-dev/minio/access/key" }}"
MINIO_SECRET_KEY="{{ key "socs/dcusr-dev/minio/secret/key" }}"
MINIO_BUCKET={{ key "socs/dcusr-dev/minio/bucket" }}
MINIO_USE_SSL=true
MINIO_PUBLIC_BASE_URL={{ key "socs/dcusr-dev/minio/base/url" }}
MINIO_REGION=ie-redbrick

SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_USER={{ key "socs/dcusr-dev/smtp/user" }}
SMTP_PASS={{ key "socs/dcusr-dev/smtp/password" }}
MAIL_FROM="{{ key "socs/dcusr-dev/mail/from" }}"
MAIL_TO={{ key "socs/dcusr-dev/mail/to" }}
SMTP_SECURE=true
SMTP_REJECT_UNAUTHORIZED=true

MAIL_BRAND="DCU Solar Racing"

PLAUSIBLE_BASE_URL={{ key "socs/dcusr-dev/plausible/url" }}

NEXT_PUBLIC_RECAPTCHA_SITE_KEY={{ key "socs/dcusr/captcha/site/key"}}
RECAPTCHA_SECRET={{ key "socs/dcusr/captcha/secret/key" }}
RECAPTCHA_MIN_SCORE=0.5

# Salt for hashing visitor IPs; empty falls back to AUTH_SECRET
ANALYTICS_SALT={{ keyOrDefault "socs/dcusr-dev/analytics/salt" "" }}

# Search engine pings on content changes; empty turns IndexNow off
INDEXNOW_KEY={{ keyOrDefault "socs/dcusr-dev/indexnow/key" "" }}

# Partner address search in admin; empty uses OpenStreetMap
GOOGLE_MAPS_API_KEY={{ keyOrDefault "socs/dcusr-dev/google/maps/key" "" }}

# Data retention in days
ANALYTICS_RETENTION_DAYS=425
CONTACT_RETENTION_DAYS=730
AUDIT_RETENTION_DAYS=395
EOH
      }

      # The image optimizer (sharp) decodes full camera files in this
      # container; a large photo needs about 1 GB while it decodes.
      resources {
        cpu    = 1000
        memory = 2048
      }
    }

    # The app runs as `node` (uid 1000) but Docker creates a missing bind
    # source as root, and Next skips caching silently when it can't write.
    task "image-cache-perms" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "alpine:3.19"
        command = "sh"
        args    = ["-c", "mkdir -p /cache && chown -R 1000:1000 /cache"]
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/image-cache:/cache",
        ]
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    task "wait-for-db" {
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
          "while ! nc -z \"$DB_HOST\" \"$DB_PORT\"; do echo 'Waiting for Postgres...'; sleep 1; done; echo 'DB is ready!'"
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
{{- range service "dcusr-db" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{- end }}
EOH
      }

      resources {
        cpu    = 50
        memory = 64
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
        name = "dcusr-db"
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
POSTGRES_DB={{ key "socs/dcusr-dev/db/name" }}
POSTGRES_USER={{ key "socs/dcusr-dev/db/user" }}
POSTGRES_PASSWORD={{ key "socs/dcusr-dev/db/password" }}
EOH
      }
    }
  }
}

