job "grafana" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "grafana.redbrick.dcu.ie"
  }

  group "database" {
    count = 1

    network {
      port "db" {
        to = 5432
      }
    }

    service {
      name = "grafana-db"
      port = "db"

      check {
        name     = "postgres-tcp"
        type     = "tcp"
        port     = "db"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "db" {
      driver         = "docker"
      kill_signal    = "SIGTERM" # SIGTERM instead of SIGKILL so database can shutdown safely
      kill_timeout   = "30s"
      shutdown_delay = "5s"

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/data"
        ]
      }

      template {
        data        = <<EOH
POSTGRES_DB={{ key "grafana/db/name" }}
POSTGRES_USER={{ key "grafana/db/user" }}
POSTGRES_PASSWORD={{ key "grafana/db/password" }}
EOH
        destination = "local/db.env"
        env         = true
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }

  group "web" {
    count = 1
    network {
      port "http" {
        to = 3000
      }
    }

    service {
      name = "grafana-rb"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafanarb.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.grafanarb.entrypoints=web,websecure",
        "traefik.http.routers.grafanarb.tls.certresolver=rb",
        "traefik.http.routers.grafanarb.tls=true",
      ]
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
          "while ! nc -z $DB_HOST $DB_PORT; do echo 'Waiting for DB...'; sleep 1; done; echo 'DB is ready!'"
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
{{- range service "grafana-db" }}
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

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/grafana",
          "local/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml"
        ]
      }

      template {
        data        = <<EOH
GF_DATABASE_TYPE=postgres
GF_DATABASE_HOST={{ range service "grafana-db" }}{{ .Address }}:{{ .Port }}{{ end }}
GF_DATABASE_NAME={{ key "grafana/db/name" }}
GF_DATABASE_USER={{ key "grafana/db/user" }}
GF_DATABASE_PASSWORD={{ key "grafana/db/password" }}
# GF_FEATURE_TOGGLES_ENABLE=publicDashboards
GF_LOG_LEVEL=info
GF_AUTH_BASIC_ENABLED=true
GF_USERS_ALLOW_SIGN_UP=false
GF_SERVER_ROOT_URL=https://{{ env "NOMAD_META_domain" }}

EOH
        destination = "local/.env"
        env         = true
      }
      template {
        data        = <<EOH
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    {{- range service "prometheus" }}
    url: http://prometheus.service.consul:{{ .Port }}{{ end }}
    isDefault: true
    editable: false
EOH
        destination = "local/datasources.yml"
      }
      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }
}


