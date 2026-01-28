job "matrix" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "matrix.redbrick.dcu.ie"
    main   = "redbrick.dcu.ie"
  }

  group "synapse" {
    count = 1

    network {

      port "http" {
        to = 8008
      }

      port "federation" {
        to = 8448
      }
    }

    service {
      name = "matrix-synapse"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.synapse.rule=Host(`${NOMAD_META_domain}`) && (PathPrefix(`/_matrix`) || PathPrefix(`/_synapse`))",
        "traefik.http.routers.synapse.entrypoints=websecure",
        "traefik.http.routers.synapse.tls=true",
        "traefik.http.routers.synapse.tls.certresolver=rb",
        "traefik.http.routers.synapse.priority=200",
        "traefik.http.routers.synapse-client-wellknown.rule=Host(`${NOMAD_META_main}`) && Path(`/.well-known/matrix/client`)",
        "traefik.http.routers.synapse-client-wellknown.entrypoints=websecure",
        "traefik.http.routers.synapse-client-wellknown.tls=true",
        "traefik.http.routers.synapse-client-wellknown.priority=200",
        "traefik.http.routers.synapse-server-wellknown.rule=Host(`${NOMAD_META_main}`) && Path(`/.well-known/matrix/server`)",
        "traefik.http.routers.synapse-server-wellknown.entrypoints=websecure",
        "traefik.http.routers.synapse-server-wellknown.tls=true",
        "traefik.http.routers.synapse-server-wellknown.priority=200",
      ]

      check {
        type     = "http"
        path     = "/_matrix/client/versions"
        interval = "30s"
        timeout  = "5s"
      }
    }

    service {
      name = "matrix-federation"
      port = "federation"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.synapse-federation.rule=Host(`${NOMAD_META_main}`)",
        "traefik.http.routers.synapse-federation.entrypoints=matrix",
        "traefik.http.routers.synapse-federation.tls=true",
        "traefik.http.routers.synapse-federation.tls.certresolver=rb",
      ]
    }

    task "synapse" {
      driver = "docker"

      config {
        image = "matrixdotorg/synapse:latest"
        ports = ["http", "federation"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/data",
          "local/discord.yaml:/bridges/discord.yaml:ro",
          "local/homeserver.yaml:/data/homeserver.yaml:ro",
          "local/log.config:/data/log.config",
        ]
      }

      template {
        destination = "secrets/synapse.env"
        env         = true
        data        = <<EOH
SYNAPSE_CONFIG_PATH=/data/homeserver.yaml
SYNAPSE_DATA_DIR=/data
EOH
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      template {
        destination = "local/homeserver.yaml"
        change_mode = "restart"
        data        = <<EOH
server_name: "{{ env "NOMAD_META_main" }}"
pid_file: /data/homeserver.pid
web_client_location: https://{{ env "NOMAD_META_domain" }}/
public_baseurl: https://{{ env "NOMAD_META_domain" }}/

app_service_config_files:
  - /bridges/discord.yaml

listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [client, federation]
        compress: false

  - port: 8448
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [federation]
        compress: false

# Database
database:
  name: psycopg2
  args:
    user: {{ key "matrix/db/user" }}
    password: {{ key "matrix/db/password" }}
    database: {{ key "matrix/db/name" }}
    host: {{ range service "matrix-postgres" }}{{ .Address }}{{ end }}
    port: {{ range service "matrix-postgres" }}{{ .Port }}{{ end }}
    cp_min: 5
    cp_max: 10

# LDAP Authentication
modules:
  - module: "ldap_auth_provider.LdapAuthProviderModule"
    config:
      enabled: true
      uri: "ldap://{{ range service "openldap-ldap" }}{{ .Address }}:{{ .Port }}{{ end }}"
      start_tls: false
      base: "{{ key "matrix/ldap/basedn" }}"
      bind_dn: "{{ key "matrix/ldap/binddn" }}"
      bind_password: "{{ key "matrix/ldap/password" }}"

      attributes:
        uid: "uid"
        mail: "mail"
        name: "uid"

      # filter: "{ keyOrDefault "matrix/ldap_filter" "(objectClass=posixAccount)" }}"

# Registration
enable_registration: false
enable_registration_without_verification: false
registration_shared_secret: "{{ key "matrix/registration_secret" }}"
# enable_set_displayname: false
auto_join_rooms:
- '#redbrick:redbrick.dcu.ie'
- '#lobby:redbrick.dcu.ie'
- '#video-games:redbrick.dcu.ie'
- '#memes:redbrick.dcu.ie'
- '#food:redbrick.dcu.ie'
- '#music:redbrick.dcu.ie'
- '#hardware:redbrick.dcu.ie'
- '#security:redbrick.dcu.ie'
- '#sports:redbrick.dcu.ie'
- '#common-room-chat:redbrick.dcu.ie'
- '#pet-pics:redbrick.dcu.ie'
- '#bots:redbrick.dcu.ie'
- '#webgroup:redbrick.dcu.ie'
- '#webgroup-github:redbrick.dcu.ie'
- '#bot-dev:redbrick.dcu.ie'
- '#text-to-voice:redbrick.dcu.ie'


# Security
macaroon_secret_key: "{{ key "matrix/macaroon_secret" }}"
form_secret: "{{ key "matrix/form_secret" }}"
signing_key_path: "/data/signing.key"

# Report stats
report_stats: false

# Media
media_store_path: /data/media_store
max_upload_size: 100M
max_image_pixels: 32M

url_preview_enabled: true
url_preview_ip_range_blacklist:
  - '127.0.0.0/8'
  - '10.0.0.0/8'
  - '172.16.0.0/12'
  - '192.168.0.0/16'
  - '100.64.0.0/10'
  - '169.254.0.0/16'
  - '::1/128'
  - 'fe80::/64'
  - 'fc00::/7'

# Federation
federation_domain_whitelist: null
suppress_key_server_warning: true
trusted_key_servers:
  - server_name: "matrix.org"

# Ratelimiting
rc_message:
  per_second: 0.2
  burst_count: 10

rc_registration:
  per_second: 0.17
  burst_count: 3

rc_login:
  address:
    per_second: 0.17
    burst_count: 3
  account:
    per_second: 0.17
    burst_count: 3
  failed_attempts:
    per_second: 0.17
    burst_count: 3

# Retention
retention:
  enabled: false

# Presence
presence:
  enabled: true

# Logging
log_config: "/data/log.config"
EOH

      }

      template {
        destination = "local/log.config"
        change_mode = "restart"
        data        = <<EOH
version: 1

formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'

handlers:
  console:
    class: logging.StreamHandler
    formatter: precise
    stream: ext://sys.stdout

loggers:
  synapse.storage.SQL:
    level: WARNING

root:
  level: INFO
  handlers: [console]

disable_existing_loggers: false
EOH

      }
      template {
        destination = "local/discord.yaml"
        change_mode = "restart"
        data        = <<EOH
id: discord
url: http://{{ range service "matrix-discord-bridge" }}{{ .Address }}:{{ .Port }}{{ end }}
as_token: "{{ key "matrix/bridge/discord/as_token" }}"
hs_token: "{{ key "matrix/bridge/discord/hs_token" }}"
sender_localpart: discordbot
rate_limited: false
namespaces:
  users:
    - exclusive: true
      regex: '@.*_d:redbrick\.dcu\.ie'
  rooms: []
  aliases:
    - exclusive: false
      # regex: '#.*_d:redbrick\.dcu\.ie'
      regex: '#.*:redbrick\.dcu\.ie'
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
{{- range service "matrix-postgres" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{- end }}
DB_USER={{ key "matrix/db/user" }}
EOH
      }

      resources {
        memory = 128
      }
    }
  }

  group "element" {
    count = 1

    network {

      port "http" {
        to = 80
      }
    }

    service {
      name = "element-web"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.element.rule=Host(`matrix.redbrick.dcu.ie`)",
        "traefik.http.routers.element.entrypoints=websecure",
        "traefik.http.routers.element.tls=true",
        "traefik.http.routers.element.tls.certresolver=rb",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "element" {
      driver = "docker"

      config {
        image = "vectorim/element-web:latest"
        ports = ["http"]

        volumes = [
          "local/config.json:/app/config.json:ro"
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }

      template {
        destination = "local/config.json"
        change_mode = "restart"
        data        = <<EOH
{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "https://{{ env "NOMAD_META_domain" }}",
      "server_name": "{{ env "NOMAD_META_main" }}"
    },
    "m.identity_server": {
      "base_url": "https://vector.im"
    }
  },
  "brand": "Redbrick Matrix",
  "default_country_code": "IE",
  "show_labs_settings": true,
  "disable_custom_urls": false,
  "disable_guests": true,
  "disable_login_language_selector": false,
  "disable_3pid_login": false,
  "permalink_prefix": "https://{{ env "NOMAD_META_domain" }}",
  "room_directory": {
    "servers": [
      "redbrick.dcu.ie",
      "matrix.org",
      "fosdem.org"
    ]
  },
  "enable_presence_by_hs_url": {
    "https://{{ env "NOMAD_META_domain" }}": false
  },
  "setting_defaults": {
    "latex_maths": true,
    "pinning": true,
    "custom_themes": [
      {
    "name": "ThomCat black theme",
    "is_dark": true,
    "colors": {
        "accent-color": "#cc7b19",
        "primary-color": "#9F8652",
        "warning-color": "#f9c003",
        "sidebar-color": "#000000",
        "roomlist-background-color": "#191919",
        "roomlist-text-color": "#cc7b19",
        "roomlist-text-secondary-color": "#e5e5e5",
        "roomlist-highlights-color": "#323232",
        "roomlist-separator-color": "#4c4c4c",
        "timeline-background-color": "#000000",
        "timeline-text-color": "#e5e5e5",
        "secondary-content": "#e5e5e5",
        "tertiary-content": "#e5e5e5",
        "timeline-text-secondary-color": "#b2b2b2",
        "timeline-highlights-color": "#212121",
        "reaction-row-button-selected-bg-color": "#cc7b19"
    }
  },
  {
    "name": "Discord Dark",
    "is_dark": true,
    "colors": {
        "accent-color": "#747ff4",
        "accent": "#747ff4",
        "primary-color": "#00aff4",
        "warning-color": "#faa81ad9",
        "alert": "#faa81ad9",

        "sidebar-color": "#202225",
        "roomlist-background-color": "#2f3136",
        "roomlist-text-color": "#dcddde",
        "roomlist-text-secondary-color": "#8e9297",
        "roomlist-highlights-color": "#4f545c52",
        "roomlist-separator-color": "#40444b",

        "timeline-background-color": "#36393f",
        "timeline-text-color": "#dcddde",
        "secondary-content": "#dcddde",
        "tertiary-content": "#dcddde",
        "timeline-text-secondary-color": "#b9bbbe",
        "timeline-highlights-color": "#04040512",

        "reaction-row-button-selected-bg-color": "#4752c4",
        "menu-selected-color": "#4752c4",
        "focus-bg-color": "#4752c4",
        "room-highlight-color": "#4752c4",
        "other-user-pill-bg-color": "#4752c4",
        "togglesw-off-color": "#72767d"
    },
    "compound": {
        "--cpd-color-theme-bg": "#0019ff",
        "--cpd-color-bg-canvas-default": "#2f3136",
        "--cpd-color-bg-subtle-secondary": "#2f3136",
        "--cpd-color-bg-subtle-primary": "#4f545c52",
        "--cpd-color-bg-action-primary-rest": "#dcddde",
        "--cpd-color-bg-action-secondary-rest": "#2f3136",
        "--cpd-color-bg-critical-primary": "#fd3f3c",
        "--cpd-color-bg-critical-subtle": "#745862",
        "--cpd-color-bg-critical-hovered": "#fd3f3c",
        "--cpd-color-bg-accent-rest": "#4cb387",
        "--cpd-color-text-primary": "#dcddde",
        "--cpd-color-text-secondary": "#b9bbbe",
        "--cpd-color-text-action-accent": "#b9bbbe",
        "--cpd-color-text-critical-primary": "#fd3f3c",
        "--cpd-color-text-success-primary": "#4cb387",
        "--cpd-color-icon-primary": "#dcddde",
        "--cpd-color-icon-secondary": "#dcddde",
        "--cpd-color-icon-tertiary": "#a7a0a7",
        "--cpd-color-icon-accent-tertiary": "#4cb387",
        "--cpd-color-border-interactive-primary": "#5d6064",
        "--cpd-color-border-interactive-secondary": "#5d6064",
        "--cpd-color-border-critical-primary": "#fd3f3c",
        "--cpd-color-border-success-subtle": "#4cb387"
    }
  },
  {
    "name": "Discord Black",
    "is_dark": true,
    "colors": {
        "accent-color": "#747ff4",
        "accent": "#747ff4",
        "primary-color": "#00aff4",
        "warning-color": "#faa81ad9",
        "alert": "#faa81ad9",

        "sidebar-color": "#000000",
        "roomlist-background-color": "#191919",
        "roomlist-text-color": "#dcddde",
        "roomlist-text-secondary-color": "#8e9297",
        "roomlist-highlights-color": "#4f545c52",
        "roomlist-separator-color": "#40444b",

        "timeline-background-color": "#000000",
        "timeline-text-color": "#dcddde",
        "secondary-content": "#dcddde",
        "tertiary-content": "#dcddde",
        "timeline-text-secondary-color": "#b9bbbe",
        "timeline-highlights-color": "#04040512",

        "reaction-row-button-selected-bg-color": "#4752c4",
        "menu-selected-color": "#4752c4",
        "focus-bg-color": "#4752c4",
        "room-highlight-color": "#4752c4",
        "other-user-pill-bg-color": "#4752c4",
        "togglesw-off-color": "#72767d"
    }
}
        ]
    },
  "features": {
    "feature_pinning": "labs",
    "feature_custom_status": "labs",
    "feature_custom_tags": "labs",
    "feature_state_counters": "labs"
  }
}
EOH
      }
    }
  }

  group "postgres" {
    count = 1

    update {
      max_parallel = 0 # don't update this group automatically
      auto_revert  = false
    }

    network {
      port "db" {
        to = 5432
      }
    }

    service {
      name = "matrix-postgres"
      port = "db"

      check {
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "db" {
      driver = "docker"

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/data"
        ]
      }

      template {
        destination = "secrets/postgres.env"
        env         = true
        data        = <<-EOH
POSTGRES_DB           = {{ key "matrix/db/name" }}
POSTGRES_USER         = {{ key "matrix/db/user" }}
POSTGRES_PASSWORD     = {{ key "matrix/db/password" }}
POSTGRES_INITDB_ARGS  =--encoding=UTF8 --lc-collate=C --lc-ctype=C
EOH
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
