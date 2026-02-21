job "kylmc-stonks" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "kylmc-stonks.rb.dcu.ie"
    stonks = "stonks"
  }

  group "stonks" {
    network {
      mode = "bridge"
      port "http" {}
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    service {
      name = "kylmc-stonks"
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
        "traefik.http.routers.kylmc-stonks.entrypoints=web,websecure",
        "traefik.http.routers.kylmc-stonks.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.kylmc-stonks.tls=true",
        "traefik.http.routers.kylmc-stonks.tls.certresolver=rb",
      ]
    }

    task "app" {
      driver = "docker"

      config {
        image      = "ghcr.io/kylemc32532/stock-portfolio-tracker:latest"
        ports      = ["http"]
        force_pull = true
        auth {
          username = "${DOCKER_USER}"
          password = "${DOCKER_PASS}"
        }

        # volumes = [
        #   "/storage/nomad/${NOMAD_JOB_NAME}/uploads:/uploads",
        # ]
      }

      resources {
        cpu    = 1000
        memory = 500
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
DOCKER_USER = {{ key "user-projects/kylmc/stonks/ghcr/username" }}
DOCKER_PASS = {{ key "user-projects/kylmc/stonks/ghcr/password" }}


DB_USER         = {{ key "user-projects/kylmc/stonks/db/username" }}
DB_PASSWORD     = {{ key "user-projects/kylmc/stonks/db/password" }}
DB_NAME         = {{ key "user-projects/kylmc/stonks/db/name" }}
{{- range service "kylmc-stonks-db" }}
DB_HOST         = {{ .Address }}
DB_PORT         = {{ .Port }}
{{- end }}

PORT = {{ env "NOMAD_PORT_http" }}
PASSPHRASE_PEPPER = {{ key "user-projects/kylmc/stonks/passphrase_pepper" }}
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
{{- range service "kylmc-stonks-db" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{- end }}
DB_USER={{ key "user-projects/kylmc/stonks/db/username" }}
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
        name = "kylmc-stonks-db"
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
          "local/schema.sql:/docker-entrypoint-initdb.d/schema.sql"
        ]
      }

      template {
        destination = "local/db.env"
        env         = true
        data        = <<EOH
POSTGRES_DB       = "{{ key "user-projects/kylmc/stonks/db/name" }}"
POSTGRES_USER     = "{{ key "user-projects/kylmc/stonks/db/username" }}"
POSTGRES_PASSWORD = "{{ key "user-projects/kylmc/stonks/db/password" }}"
EOH
      }

      template {
        destination = "local/schema.sql"
        data        = <<EOH
CREATE TABLE IF NOT EXISTS portfolios (
  uuid            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  passphrase_hash TEXT NOT NULL,
  lookup_token    TEXT UNIQUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cash_balances (
  portfolio_uuid UUID NOT NULL REFERENCES portfolios(uuid) ON DELETE CASCADE,
  currency       TEXT NOT NULL,
  amount         NUMERIC NOT NULL CHECK (amount > 0),
  PRIMARY KEY (portfolio_uuid, currency)
);

CREATE TABLE IF NOT EXISTS holdings (
  portfolio_uuid UUID NOT NULL REFERENCES portfolios(uuid) ON DELETE CASCADE,
  symbol         TEXT NOT NULL,
  shares         NUMERIC NOT NULL CHECK (shares > 0),
  PRIMARY KEY (portfolio_uuid, symbol)
);

CREATE TABLE IF NOT EXISTS price_history (
  symbol  TEXT NOT NULL,
  date    DATE NOT NULL,
  close   NUMERIC NOT NULL,
  PRIMARY KEY (symbol, date)
);

CREATE TABLE IF NOT EXISTS watchlist (
  portfolio_uuid UUID NOT NULL REFERENCES portfolios(uuid) ON DELETE CASCADE,
  symbol         TEXT NOT NULL,
  PRIMARY KEY (portfolio_uuid, symbol)
);

CREATE TABLE IF NOT EXISTS fx_rates (
  base        TEXT NOT NULL,
  target      TEXT NOT NULL,
  rate        NUMERIC NOT NULL,
  fetched_at  TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (base, target)
);
EOH
      }
    }
  }
}
