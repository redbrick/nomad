job "dcusr-seafile" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain     = "drive.solarracing.ie"
    oods       = "oods.drive.solarracing.ie"
    redis_host = "127.0.0.1"
    redis_port = "6379"
  }

  group "seafile" {
    count = 1

    network {
      mode = "bridge"

      port "http" {
        to = 80
      }

      port "notification" {
        to = 8083
      }
    }

    restart {
      attempts = 20
      delay    = "10s"
      interval = "10m"
      mode     = "delay"
    }

    service {
      name = "seafile"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.seafile.entrypoints=web,websecure",
        "traefik.http.routers.seafile.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.seafile.tls=true",
        "traefik.http.routers.seafile.service=seafile",
      ]
    }

    service {
      name = "seafile-notification"
      port = "notification"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.seafile-notification.entrypoints=web,websecure",
        "traefik.http.routers.seafile-notification.rule=Host(`${NOMAD_META_domain}`) && PathPrefix(`/notification`)",
        "traefik.http.routers.seafile-notification.tls=true",
        "traefik.http.routers.seafile-notification.priority=100",
        "traefik.http.routers.seafile-notification.service=seafile-notification",
        "traefik.http.routers.seafile-notification.middlewares=seafile-notification-stripprefix",
        "traefik.http.middlewares.seafile-notification-stripprefix.stripprefix.prefixes=/notification",
      ]
    }

    task "db" {
      driver = "docker"

      config {
        image = "mariadb:10.11"

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/mysql",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
MYSQL_DATABASE={{ key "socs/dcusr/seafile/db/name" }}
MYSQL_USER={{ key "socs/dcusr/seafile/db/user" }}
MYSQL_PASSWORD={{ key "socs/dcusr/seafile/db/password" }}
MYSQL_ROOT_PASSWORD={{ key "socs/dcusr/seafile/db/root/password" }}
MYSQL_LOG_CONSOLE=true
MARIADB_AUTO_UPGRADE=1
EOH
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:7"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    task "seafile" {
      driver = "docker"

      config {
        image = "seafileltd/seafile-mc:13.0-latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/data:/shared",
        ]
      }

      template {
        destination = "local/seafile.env"
        env         = true
        data        = <<EOH
SEAFILE_MYSQL_DB_HOST=127.0.0.1
SEAFILE_MYSQL_DB_PORT=3306
SEAFILE_MYSQL_DB_USER={{ key "socs/dcusr/seafile/db/user" }}
SEAFILE_MYSQL_DB_PASSWORD={{ key "socs/dcusr/seafile/db/password" }}
INIT_SEAFILE_MYSQL_ROOT_PASSWORD={{ key "socs/dcusr/seafile/db/root/password" }}

SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db

TIME_ZONE=Europe/Dublin

INIT_SEAFILE_ADMIN_EMAIL={{ key "socs/dcusr/seafile/admin/email" }}
INIT_SEAFILE_ADMIN_PASSWORD={{ key "socs/dcusr/seafile/admin/password" }}

SEAFILE_SERVER_HOSTNAME={{ env "NOMAD_META_domain" }}
SEAFILE_SERVER_PROTOCOL=https

NON_ROOT=false
JWT_PRIVATE_KEY={{ key "socs/dcusr/seafile/jwt/key" }}

SEAFILE_LOG_TO_STDOUT=true

CACHE_PROVIDER=redis
REDIS_HOST={{ env "NOMAD_META_redis_host" }}
REDIS_PORT={{ env "NOMAD_META_redis_port" }}

ENABLE_NOTIFICATION_SERVER=true
INNER_NOTIFICATION_SERVER_URL=http://{{ env "NOMAD_META_redis_host" }}:8083
NOTIFICATION_SERVER_URL=https://{{ env "NOMAD_META_domain" }}/notification

ENABLE_SEADOC=false
SEADOC_SERVER_URL=https://{{ env "NOMAD_META_domain" }}/sdoc-server

ENABLE_SEAFILE_AI=false
MD_FILE_COUNT_LIMIT=100000
EOH
      }

      resources {
        cpu    = 1500
        memory = 4096
      }
    }

    task "seafile-email-config" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = false
      }

      config {
        image   = "alpine:3.20"
        command = "/bin/sh"
        args    = ["local/apply-email-settings.sh"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/data:/shared",
        ]
      }

      template {
        destination = "local/apply-email-settings.sh"
        perms       = "755"
        data        = <<EOH
#!/bin/sh
set -e
CONF=/shared/seafile/conf/seahub_settings.py
MARKER="# --- nomad-managed email settings ---"

# wait for the config file to exist (only matters on first-ever boot,
# since seafile-mc generates it during its own init on first start)
for i in $(seq 1 60); do
  [ -f "$CONF" ] && break
  sleep 2
done

if [ ! -f "$CONF" ]; then
  echo "seahub_settings.py never appeared, giving up" >&2
  exit 1
fi

# strip any block we previously added, then re-append current values
sed -i "/$MARKER/,\$d" "$CONF"

cat >> "$CONF" <<EOF
$MARKER
EMAIL_USE_TLS = {{ key "socs/dcusr/seafile/smtp/use_tls" }}
EMAIL_HOST = "{{ key "socs/dcusr/seafile/smtp/host" }}"
EMAIL_PORT = {{ key "socs/dcusr/seafile/smtp/port" }}
EMAIL_HOST_USER = "{{ key "socs/dcusr/seafile/smtp/user" }}"
EMAIL_HOST_PASSWORD = "{{ key "socs/dcusr/seafile/smtp/password" }}"
DEFAULT_FROM_EMAIL = "{{ key "socs/dcusr/seafile/smtp/from" }}"
SERVER_EMAIL = "{{ key "socs/dcusr/seafile/smtp/from" }}"

ENABLE_OAUTH = True
OAUTH_CREATE_UNKNOWN_USER = True
OAUTH_ACTIVATE_USER_AFTER_CREATION = True
OAUTH_ENABLE_INSECURE_TRANSPORT = False
OAUTH_CLIENT_ID = "{{ key "socs/dcusr/seafile/oauth/client/id" }}"
OAUTH_CLIENT_SECRET = "{{ key "socs/dcusr/seafile/oauth/client/secret" }}"
OAUTH_REDIRECT_URL = "https://{{ env "NOMAD_META_domain" }}/oauth/callback/"
OAUTH_PROVIDER_DOMAIN = "authentik"
OAUTH_PROVIDER = "authentik"
OAUTH_AUTHORIZATION_URL = "https://auth.solarracing.ie/application/o/authorize/"
OAUTH_TOKEN_URL = "https://auth.solarracing.ie/application/o/token/"
OAUTH_USER_INFO_URL = "https://auth.solarracing.ie/application/o/userinfo/"
OAUTH_SCOPE = ["openid", "profile", "email"]
LOGIN_URL = "https://{{ env "NOMAD_META_domain" }}/oauth/login/"
CLIENT_SSO_VIA_LOCAL_BROWSER = True

OAUTH_ATTRIBUTE_MAP = {
    "id": (False, "sub"),
    "email": (True, "email"),
    "name": (False, "name"),
}
EOF

echo "email settings applied"
EOH
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }

    task "notification-server" {
      driver = "docker"

      config {
        image = "seafileltd/notification-server:13.0-latest"
        ports = ["notification"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/data:/shared",
        ]
      }

      template {
        destination = "local/notification.env"
        env         = true
        data        = <<EOH
SEAFILE_MYSQL_DB_HOST=127.0.0.1
SEAFILE_MYSQL_DB_PORT=3306
SEAFILE_MYSQL_DB_USER={{ key "socs/dcusr/seafile/db/user" }}
SEAFILE_MYSQL_DB_PASSWORD={{ key "socs/dcusr/seafile/db/password" }}

SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db

JWT_PRIVATE_KEY={{ key "socs/dcusr/seafile/jwt/key" }}
SEAFILE_LOG_TO_STDOUT=false
NOTIFICATION_SERVER_LOG_LEVEL=info

REDIS_HOST={{ env "NOMAD_META_redis_host" }}
REDIS_PORT={{ env "NOMAD_META_redis_port" }}
EOH
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  group "onlyoffice" {
    count = 1

    network {
      mode = "bridge"

      port "oods" {
        to = 80
      }
    }

    restart {
      attempts = 10
      delay    = "15s"
      interval = "10m"
      mode     = "delay"
    }

    service {
      name = "seafile-oods"
      port = "oods"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.seafile-oods.entrypoints=web,websecure",
        "traefik.http.routers.seafile-oods.rule=Host(`${NOMAD_META_oods}`)",
        "traefik.http.routers.seafile-oods.tls=true",
        "traefik.http.routers.seafile-oods.service=seafile-oods",
      ]
    }

    task "onlyoffice" {
      driver = "docker"

      config {
        image = "onlyoffice/documentserver:latest"
        ports = ["oods"]
      }

      template {
        destination = "local/onlyoffice.env"
        env         = true
        data        = <<EOH
JWT_ENABLED=true
JWT_SECRET={{ key "socs/dcusr/seafile/onlyoffice/jwt/secret" }}
EOH
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }
}

