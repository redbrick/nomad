job "linkwarden" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain  = "bookmark.redbrick.dcu.ie"
  }

  group "linkwarden" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
      port "db" {
        to = 5432
      }
      port "search" {
        to = 7700
      }
    }

    service {
      name = "linkwarden"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.linkwarden.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.linkwarden.entrypoints=web,websecure",
        "traefik.http.routers.linkwarden.tls.certresolver=lets-encrypt",
      ]
    }

    task "linkwarden" {
      driver = "docker"

      config {
        image = "ghcr.io/linkwarden/linkwarden:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/data/data:rw",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data = <<EOH
NEXTAUTH_URL=http://{{ env "NOMAD_META_domain" }}/api/v1/auth
NEXTAUTH_SECRET={{ key "linkwarden/nextauth/secret" }}

DATABASE_URL=postgresql://{{ key "linkwarden/db/user" }}:{{ key "linkwarden/db/password" }}@{{ env "NOMAD_ADDR_db" }}/{{ key "linkwarden/db/name" }}

# Additional Optional Settings
NEXT_PUBLIC_DISABLE_REGISTRATION=true
NEXT_PUBLIC_CREDENTIALS_ENABLED=true
MAX_WORKERS=4

# MeiliSearch Settings
MEILI_HOST={{ env "NOMAD_ADDR_search" }}
MEILI_MASTER_KEY={{ key "linkwarden/search/key" }}
EOH
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }

    service {
      name = "linkwarden-db"
      port = "db"
    }

    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/data:rw",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data = <<EOH
POSTGRES_USER={{ key "linkwarden/db/user" }}
POSTGRES_PASSWORD={{ key "linkwarden/db/password" }}
POSTGRES_DB={{ key "linkwarden/db/name" }}
EOH
      }

      resources {
        cpu    = 500
        memory = 800
      }
    }
 
    task "meilisearch" {
      driver = "docker"

      config {
        image = "getmeili/meilisearch:v1.12.8"
        ports = ["search"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/meili_data:rw",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data = <<EOH
MEILI_MASTER_KEY={{ key "linkwarden/search/key" }}
MEILI_ENV=production

MEILI_MAX_INDEXING_THREADS=2
MEILI_MAX_INDEXING_MEMORY=4294967296
EOH
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }
}
