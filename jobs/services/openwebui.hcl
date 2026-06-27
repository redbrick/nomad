job "open-webui" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "ai.rb.dcu.ie"
  }

  group "web" {
    count = 1

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "open-webui"
      port = "http"

      # Traefik routing configuration tags
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.open-webui.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.open-webui.entrypoints=websecure",
        "traefik.http.routers.open-webui.tls=true",
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "ui" {
      driver = "docker"

      config {
        image = "ghcr.io/open-webui/open-webui:main"
        ports = ["http"]

        # Dynamic local host bind-mount storage using task interpolation
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/app/backend/data"
        ]
      }

      template {
        data = <<EOH
# --- Core Backend Configurations ---
OLLAMA_BASE_URLS="{{ key "ollama/base_urls" }}"
ENABLE_OLLAMA_NODES="True;False;False;False"

# --- Force Config via File instead of internal DB ---
ENABLE_PERSISTENT_CONFIG="False"

# --- LDAP Core Server Settings ---
ENABLE_LDAP="true"
LDAP_SERVER_LABEL="Enterprise-Directory"
LDAP_SERVER_HOST="ldap://{{ range service "openldap-ldap" }}{{ .Address }}{{ end }}"
LDAP_SERVER_PORT="389"          # Use 636 for LDAPS, 389 for plain text
LDAP_USE_TLS="true"
LDAP_VALIDATE_CERT="false"

# --- Dynamic Bind Credentials from Consul ---
LDAP_APP_DN="{{ key "openwebui/ldap/binddn" }}"
LDAP_APP_PASSWORD="{{ key "openwebui/ldap/password" }}"

# --- Thread Pool & Anti-Freeze Adjustments ---
GLOBAL_WORKER_TIMEOUT=300
AIOHTTP_CLIENT_TIMEOUT=1800
RAG_WEB_SEARCH_CONCURRENT_REQUESTS=2

# --- Dynamic Directory Search Base from Consul ---
LDAP_SEARCH_BASE="{{ key "openwebui/ldap/basedn" }}"

# --- Directory Schema Mapping ---
LDAP_ATTRIBUTE_FOR_USERNAME="uid"
LDAP_ATTRIBUTE_FOR_MAIL="mail"

# --- Disable Signups---
ENABLE_SIGNUP=False

# --- Automatically allow LDAP users to use the system without manual approval ---
DEFAULT_USER_ROLE=user
EOH

        destination = "secrets/file.env"
        env         = true
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }
}
