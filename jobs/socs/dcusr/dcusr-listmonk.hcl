job "dcusr-listmonk" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "lists.solarracing.ie"
  }

  group "listmonk" {
    network {
      port "http" {
      }
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }


    service {
      name = "dcusr-listmonk"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.dcusr-listmonk.entrypoints=web,websecure",
        "traefik.http.routers.dcusr-listmonk.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.dcusr-listmonk.tls=true",
        "traefik.http.routers.dcusr-listmonk.tls.certresolver=lets-encrypt",
      ]
    }

    task "app" {
      driver = "docker"

      config {
        image = "listmonk/listmonk:latest"
        ports = ["http"]

        command = "sh"
        args    = ["-c", "./listmonk --install --idempotent --yes --config '' && ./listmonk --upgrade --yes --config '' && ./listmonk --config ''"] # empty config so envvars are used instead

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}/uploads:/uploads",
        ]
      }

      resources {
        cpu    = 1000
        memory = 500
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
LISTMONK_app__address     = 0.0.0.0:{{ env "NOMAD_PORT_http" }}
LISTMONK_app__public_url  = {{ env "NOMAD_META_domain" }}

LISTMONK_db__user         = {{ key "dcusr/listmonk/db/username" }}
LISTMONK_db__password     = {{ key "dcusr/listmonk/db/password" }}
LISTMONK_db__database     = {{ key "dcusr/listmonk/db/name" }}
{{- range service "dcusr-listmonk-db" }}
LISTMONK_db__host         = {{ .Address }}
LISTMONK_db__port         = {{ .Port }}
{{- end }}
LISTMONK_db__ssl_mode     = disable
LISTMONK_db__max_open     = 25
LISTMONK_db__max_idle     = 25
LISTMONK_db__max_lifetime = 300s
TZ                        = Etc/UTC
LISTMONK_ADMIN_USER       = {{ key "dcusr/listmonk/admin/username" }}
LISTMONK_ADMIN_PASSWORD   = {{ key "dcusr/listmonk/admin/password" }}
EOH
      }
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
          "while ! pg_isready -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER}; do echo 'Waiting for DB...'; sleep 1; done; echo 'DB is ready!'"
        ]
      }

      template {
        destination = "local/wait.env"
        env         = true
        data        = <<EOH
{{- range service "dcusr-listmonk-db" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{- end }}
DB_USER={{ key "dcusr/listmonk/db/username" }}
EOH
      }

      resources {
        memory = 128
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

    task "postgres" {
      driver         = "docker"
      kill_signal    = "SIGTERM" # SIGTERM instead of SIGKILL so database can shutdown safely
      kill_timeout   = "30s"
      shutdown_delay = "5s"

      service {
        name = "dcusr-listmonk-db"
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
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/data"
        ]
      }

      template {
        data        = <<EOH
POSTGRES_DB       = "{{ key "dcusr/listmonk/db/name" }}"
POSTGRES_USER     = "{{ key "dcusr/listmonk/db/username" }}"
POSTGRES_PASSWORD = "{{ key "dcusr/listmonk/db/password" }}"
EOH
        destination = "local/db.env"
        env         = true
      }
    }
  }
}
