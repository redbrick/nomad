job "intersocs-wiki" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain  = "wiki.netsocs.ie"
    domain2 = "wiki.intersocs.net"
  }

  group "web" {
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
      name = "intersocs-wiki"
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
        "traefik.http.routers.intersocs-wiki.entrypoints=web,websecure",
        "traefik.http.routers.intersocs-wiki.rule=Host(`${NOMAD_META_domain}`) || Host(`${NOMAD_META_domain2}`)",
        "traefik.http.routers.intersocs-wiki.tls=true",
        "traefik.http.routers.intersocs-wiki.tls.certresolver=lets-encrypt",
      ]
    }

    task "wiki" {
      driver = "docker"

      config {
        image = "requarks/wiki:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 1000
        memory = 500
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
DB_TYPE = postgres
{{- range service "intersocs-wiki-db" }}
DB_HOST = {{ .Address }}
DB_PORT = {{ .Port }}
{{- end }}

DB_USER = {{ key "intersocs/wiki/db/user" }}
DB_PASS = {{ key "intersocs/wiki/db/password" }}
DB_NAME = {{ key "intersocs/wiki/db/name" }}
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
{{- range service "intersocs-wiki-db" }}
DB_HOST = {{ .Address }}
DB_PORT = {{ .Port }}
{{- end }}
DB_USER = {{ key "intersocs/wiki/db/user" }}
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
        name = "intersocs-wiki-db"
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
        destination = "local/db.env"
        env         = true
        data        = <<EOH
POSTGRES_DB       = "{{ key "intersocs/wiki/db/name" }}"
POSTGRES_USER     = "{{ key "intersocs/wiki/db/user" }}"
POSTGRES_PASSWORD = "{{ key "intersocs/wiki/db/password" }}"
EOH
      }
    }
  }
}
