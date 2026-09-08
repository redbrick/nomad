job "open-webui" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "ai.rb.dcu.ie"
  }

  # =========================================================================
  # Database
  # =========================================================================
  group "openwebui-postgres" {
    count = 1

    network {
      port "pg" { to = 5432 }
    }

    service {
      name = "openwebui-postgres"
      port = "pg"
      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "openwebui-postgres" {
      driver = "docker"
      config {
        image   = "postgres:16-alpine"
        ports   = ["pg"]
        volumes = ["/storage/nomad/${NOMAD_JOB_NAME}/postgres_data:/var/lib/postgresql/data"]
      }

      template {
        data        = <<EOH
POSTGRES_DB="openwebui"
POSTGRES_USER="{{ key "openwebui/db/user" }}"
POSTGRES_PASSWORD="{{ key "openwebui/db/password" }}"
EOH
        destination = "secrets/db.env"
        env         = true
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }

  # =========================================================================
  # Vector Storage
  # =========================================================================
  group "openwebui-qdrant" {
    count = 1

    network {
      port "qdrant_grpc" { to = 6334 }
      port "qdrant_http" { to = 6333 }
    }

    service {
      name = "openwebui-qdrant"
      port = "qdrant_http"
      check {
        type     = "http"
        path     = "/readyz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "qdrant" {
      driver = "docker"
      config {
        image   = "qdrant/qdrant:v1.17.0"
        ports   = ["qdrant_grpc", "qdrant_http"]
        volumes = ["/storage/nomad/${NOMAD_JOB_NAME}/qdrant_data:/qdrant/storage"]
      }
      resources {
        cpu    = 1500
        memory = 3072
      }
    }
  }

  # =========================================================================
  # Redis for cache and stats
  # =========================================================================
  group "openwebui-redis" {
    count = 1  

    network {
      port "redis" { to = 6379 }
    }

    service {
      name = "openwebui-redis"
      port = "redis"
      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "redis" {
      driver = "docker"
      config {
        image   = "redis:7-alpine"
        ports   = ["redis"]
        command = "redis-server"
        args    = ["--timeout", "1800", "--save", "30", "1", "--maxclients", "10000"]
      }
      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }

  # =========================================================================
  # Web UI Service & Integrated Lifecycle Migration
  # =========================================================================
  group "openwebui-web" {
    count = 3

    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    network {
      port "http" { to = 8080 }
    }

    service {
      name = "open-webui"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.open-webui.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.open-webui.entrypoints=websecure",
        "traefik.http.routers.open-webui.tls=true",
        "traefik.http.services.open-webui.loadbalancer.sticky=true",
        "traefik.http.services.open-webui.loadbalancer.sticky.cookie.name=OPENWEBUI_STICKY_SESSION",
        "traefik.http.services.open-webui.loadbalancer.sticky.cookie.secure=true",
        "traefik.http.services.open-webui.loadbalancer.sticky.cookie.httpOnly=true"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # Runs and blocks the 'ui' task until the schema upgrade finishes cleanly
    task "db-migration" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "ghcr.io/open-webui/open-webui:main"
        command = "bash"
        args    = ["-c", "cd /app/backend/open_webui && export PYTHONPATH=/app && echo 'Running DB Migrations...' && alembic upgrade head"] 
      }

      template {
        data = <<EOH
DATABASE_URL="{{ range service "openwebui-postgres" }}postgresql://{{ key "openwebui/db/user" }}:{{ key "openwebui/db/password" }}@{{ .Address }}:{{ .Port }}/openwebui{{ end }}"
WEBUI_SECRET_KEY="{{ key "openwebui/secret_key" }}"
EOH
        destination = "secrets/migration.env"
        env         = true
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }

    task "ui" {
      driver = "docker"

      config {
        image = "ghcr.io/open-webui/open-webui:main"
        ports = ["http"]
        
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/app/backend/data"
        ]
      }

      template {
        destination = "secrets/file.env"
        env         = true
        data = <<EOH
# --- Core Backend Configurations ---
OLLAMA_BASE_URLS="{{ key "ollama/base_urls" }}"
ENABLE_OLLAMA_NODES="true;true;true;true"

# --- Disable OpenAI API Key Usage ---
ENABLE_OPENAI_API_KEY="false"

# --- Shared Cryptographic Token pulled from Consul ---
WEBUI_SECRET_KEY="{{ key "openwebui/secret_key" }}"

# --- Local Postgres Database Connection Strategy ---
DATABASE_URL="{{ range service "openwebui-postgres" }}postgresql://{{ key "openwebui/db/user" }}:{{ key "openwebui/db/password" }}@{{ .Address }}:{{ .Port }}/openwebui{{ end }}"
ENABLE_DB_MIGRATIONS="false" 

# --- Local Vector Database (Qdrant) Connection Strategy ---
VECTOR_DB="qdrant"
QDRANT_API_KEY=""
{{ range service "openwebui-qdrant" }}
QDRANT_URI="http://{{ .Address }}:{{ .Port }}"
{{ end }}

# --- Shared State Matrix (Redis Broker Alignment) ---
ENABLE_WEBSOCKET_SUPPORT=True
WEBSOCKET_MANAGER="redis"
REDIS_URL="{{ range service "openwebui-redis" }}redis://{{ .Address }}:{{ .Port }}/0{{ end }}"
WEBSOCKET_REDIS_URL="{{ range service "openwebui-redis" }}redis://{{ .Address }}:{{ .Port }}/1{{ end }}"
REDIS_HEALTH_CHECK_INTERVAL=60
REDIS_SOCKET_CONNECT_TIMEOUT=5

# --- SearXNG Live Search ---
ENABLE_WEB_SEARCH=True
WEB_SEARCH_ENGINE="searxng"
SEARXNG_QUERY_URL="https://search.redbrick.dcu.ie/search?q=<query>&format=json"
WEB_SEARCH_RESULT_COUNT=3
WEB_SEARCH_CONCURRENT_REQUESTS=1

# --- Performance Guardrails for Multi-User Deployment ---
ENABLE_REALTIME_CHAT_SAVE="false"
WEBUI_JWT_EXPIRATION_TIME="168h"
UVICORN_WORKERS=1 
DATABASE_USER_ACTIVE_STATUS_UPDATE_INTERVAL=300
ENABLE_PERSISTENT_CONFIG="false"
ENABLE_API_KEYS="true"
ENABLE_API_KEYS_ENDPOINT_RESTRICTIONS="false"
ENV="dev" # enables the swagger ui

# --- LDAP Core Server Settings ---
ENABLE_LDAP="true"
LDAP_SERVER_LABEL="Enterprise-Directory"
LDAP_SERVER_HOST="ldap://{{ range service "openldap-ldap" }}{{ .Address }}{{ end }}"
LDAP_SERVER_PORT="389"    
LDAP_USE_TLS="true"
LDAP_VALIDATE_CERT="false"

# --- Dynamic Bind Credentials from Consul ---
LDAP_APP_DN="{{ key "openwebui/ldap/binddn" }}"
LDAP_APP_PASSWORD="{{ key "openwebui/ldap/password" }}"
LDAP_SEARCH_BASE="{{ key "openwebui/ldap/basedn" }}"

# --- Directory Schema Mapping ---
LDAP_ATTRIBUTE_FOR_USERNAME="uid"
LDAP_ATTRIBUTE_FOR_MAIL="mail"

# --- Anti-Freeze Adjustments ---
GLOBAL_WORKER_TIMEOUT=300
AIOHTTP_CLIENT_TIMEOUT=1800
RAG_WEB_SEARCH_CONCURRENT_REQUESTS=4
THREAD_POOL_SIZE=2000

# --- User Provisioning Access Control ---
ENABLE_SIGNUP="false"
DEFAULT_USER_ROLE="user"
EOH
      }

      resources {
        cpu    = 2000
        memory = 4096
      }
    }
  }
}
