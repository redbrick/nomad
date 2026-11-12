job "inventree" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "inventree.solarracing.ie"
  }

  group "web" {
    count = 1

    network {
      port "http" {
        to = 8080
      }

      port "app" {
        to = 8000
      }
    }

    service {
      name = "inventree-nginx"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.inventree.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.inventree.entrypoints=web,websecure",
      ]
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
          "while ! pg_isready -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER}; do echo 'Waiting for InvenTree DB...'; sleep 2; done; echo 'DB is ready!'",
        ]
      }

      template {
        destination = "local/db.env"
        env         = true
        data        = <<EOH
{{ range service "inventree-db" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{ end }}

DB_USER={{ key "dcusr/inventree/db/user" }}
EOH
      }

      resources {
        cpu    = 50
        memory = 128
      }
    }

    task "wait-for-cache" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "redis:7-alpine"
        command = "sh"
        args = [
          "-c",
          "until redis-cli -h ${CACHE_HOST} -p ${CACHE_PORT} ping | grep -q PONG; do echo 'Waiting for Redis...'; sleep 2; done; echo 'Redis is ready!'",
        ]
      }

      template {
        destination = "local/redis.env"
        env         = true
        data        = <<EOH
{{ range service "inventree-cache" }}
CACHE_HOST={{ .Address }}
CACHE_PORT={{ .Port }}
{{ end }}
EOH
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }

    task "inventree-init" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image = "inventree/inventree:stable"

        command = "invoke"
        args    = ["update"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/data:/home/inventree/data",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
INVENTREE_DB_ENGINE   = postgresql
INVENTREE_DB_NAME     = {{ key "dcusr/inventree/db/name" }}
INVENTREE_DB_USER     = {{ key "dcusr/inventree/db/user" }}
INVENTREE_DB_PASSWORD = {{ key "dcusr/inventree/db/password" }}

{{ range service "inventree-db" }}
INVENTREE_DB_HOST={{ .Address }}
INVENTREE_DB_PORT={{ .Port }}
{{ end }}

INVENTREE_CACHE_ENABLED=True
{{ range service "inventree-cache" }}
INVENTREE_CACHE_HOST={{ .Address }}
INVENTREE_CACHE_PORT={{ .Port }}
{{ end }}

INVENTREE_SITE_URL        = https://{{ env "NOMAD_META_domain" }}
INVENTREE_DEBUG           = False
INVENTREE_LOG_LEVEL       = WARNING
INVENTREE_PLUGINS_ENABLED = True

INVENTREE_ADMIN_USER      = {{ key "dcusr/inventree/admin/user" }}
INVENTREE_ADMIN_PASSWORD  = {{ key "dcusr/inventree/admin/password" }}
INVENTREE_ADMIN_EMAIL     = {{ key "dcusr/inventree/admin/email" }}

INVENTREE_EMAIL_HOST      = {{ key "dcusr/inventree/smtp/host" }}
INVENTREE_EMAIL_PORT      = {{ key "dcusr/inventree/smtp/port" }}
INVENTREE_EMAIL_USERNAME  = {{ key "dcusr/inventree/smtp/user" }}
INVENTREE_EMAIL_PASSWORD  = {{ key "dcusr/inventree/smtp/password" }}
INVENTREE_EMAIL_TLS       = True
INVENTREE_EMAIL_SENDER    = {{ key "dcusr/inventree/smtp/from" }}

INVENTREE_USE_X_FORWARDED_HOST=True
INVENTREE_USE_X_FORWARDED_PORT=True
INVENTREE_USE_X_FORWARDED_PROTO=True

INVENTREE_COOKIE_SAMESITE = Lax
INVENTREE_SESSION_COOKIE_SECURE = True

INVENTREE_SOCIAL_BACKENDS = allauth.socialaccount.providers.openid_connect
INVENTREE_SOCIAL_PROVIDERS = '{"openid_connect":{"EMAIL_AUTHENTICATION":true,"VERIFIED_EMAIL":true,"OAUTH_PKCE_ENABLED":true,"APPS":[{"provider_id":"authentik","name":"Authentik","client_id":"{{ key "dcusr/inventree/sso/client_id" }}","secret":"{{ key "dcusr/inventree/sso/client_secret" }}","settings":{"server_url":"{{ key "dcusr/inventree/sso/server_url" }}","OAUTH_PKCE_ENABLED":true}}],"SCOPE":["openid","profile","email","groups"]}}'

INVENTREE_GLOBAL_SETTINGS = '{"LOGIN_ENABLE_SSO":true,"LOGIN_ENABLE_SSO_REG":true,"LOGIN_ENABLE_REG":false,"LOGIN_ENABLE_PWD_FORGOT":false,"LOGIN_ENABLE_SSO_GROUP_SYNC":true,"SSO_GROUP_KEY":"groups","SSO_GROUP_MAP":"{\"dcusr-software\":\"Software\",\"dcusr-mech\":\"Mechanical\",\"dcusr-elec\":\"Electrical\",\"dcusr-business\":\"Business\",\"all access - website read-only\":\"Read Only\"}","SSO_REMOVE_GROUPS":true}'
EOH
      }

      resources {
        cpu    = 300
        memory = 1024
      }
    }

    task "inventree-nginx" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/data:/home/inventree/data",
          "local/nginx.conf:/etc/nginx/conf.d/default.conf",
        ]
      }

      template {
        destination = "local/nginx.conf"
        data        = <<EOH
upstream inventree {
  server {{ env "NOMAD_ADDR_app" }};
}

map $http_upgrade $connection_upgrade {
  default upgrade;
  ''      close;
}

server {
  listen 8080;
  server_name _;

  client_max_body_size 100M;

  location /static/ {
    alias /home/inventree/data/static/;
    autoindex off;
    expires 30d;
    add_header Cache-Control "public";
  }
  
  location /media/ {
    alias /home/inventree/data/media/;
    auth_request /auth;
    add_header Content-disposition "attachment";
  }

  location = /auth {
    internal;

    proxy_pass http://{{ env "NOMAD_ADDR_app" }}/auth/;

    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
    proxy_set_header X-Original-URI $request_uri;

    proxy_set_header Host              $http_host;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
    proxy_set_header X-Real-IP         $remote_addr;
  }

  location / {
    proxy_set_header Host                $http_host;
    proxy_set_header X-Forwarded-By      $server_addr:$server_port;
    proxy_set_header X-Forwarded-For     $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto   $http_x_forwarded_proto;
    proxy_set_header X-Real-IP           $remote_addr;
    proxy_set_header CLIENT_IP           $remote_addr;

    proxy_http_version 1.1;
    proxy_set_header Upgrade             $http_upgrade;
    proxy_set_header Connection          $connection_upgrade;

    proxy_redirect off;
    proxy_buffering off;
    proxy_request_buffering off;

    proxy_pass http://{{ env "NOMAD_ADDR_app" }};
  }
}
EOH
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    task "inventree-server" {
      driver = "docker"

      config {
        image = "inventree/inventree:stable"
        ports = ["app"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/data:/home/inventree/data",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
INVENTREE_DB_ENGINE   = postgresql
INVENTREE_DB_NAME     = {{ key "dcusr/inventree/db/name" }}
INVENTREE_DB_USER     = {{ key "dcusr/inventree/db/user" }}
INVENTREE_DB_PASSWORD = {{ key "dcusr/inventree/db/password" }}

{{ range service "inventree-db" }}
INVENTREE_DB_HOST={{ .Address }}
INVENTREE_DB_PORT={{ .Port }}
{{ end }}

INVENTREE_CACHE_ENABLED=True
{{ range service "inventree-cache" }}
INVENTREE_CACHE_HOST={{ .Address }}
INVENTREE_CACHE_PORT={{ .Port }}
{{ end }}

INVENTREE_SITE_URL        = https://{{ env "NOMAD_META_domain" }}
INVENTREE_DEBUG           = False
INVENTREE_LOG_LEVEL       = WARNING
INVENTREE_PLUGINS_ENABLED = True

INVENTREE_EMAIL_HOST      = {{ key "dcusr/inventree/smtp/host" }}
INVENTREE_EMAIL_PORT      = {{ key "dcusr/inventree/smtp/port" }}
INVENTREE_EMAIL_USERNAME  = {{ key "dcusr/inventree/smtp/user" }}
INVENTREE_EMAIL_PASSWORD  = {{ key "dcusr/inventree/smtp/password" }}
INVENTREE_EMAIL_TLS       = True
INVENTREE_EMAIL_SENDER    = {{ key "dcusr/inventree/smtp/from" }}

INVENTREE_USE_X_FORWARDED_HOST=True
INVENTREE_USE_X_FORWARDED_PORT=True
INVENTREE_USE_X_FORWARDED_PROTO=True

INVENTREE_COOKIE_SAMESITE = Lax
INVENTREE_SESSION_COOKIE_SECURE = True

INVENTREE_SOCIAL_BACKENDS = allauth.socialaccount.providers.openid_connect
INVENTREE_SOCIAL_PROVIDERS = '{"openid_connect":{"EMAIL_AUTHENTICATION":true,"VERIFIED_EMAIL":true,"OAUTH_PKCE_ENABLED":true,"APPS":[{"provider_id":"authentik","name":"Authentik","client_id":"{{ key "dcusr/inventree/sso/client_id" }}","secret":"{{ key "dcusr/inventree/sso/client_secret" }}","settings":{"server_url":"{{ key "dcusr/inventree/sso/server_url" }}","OAUTH_PKCE_ENABLED":true}}],"SCOPE":["openid","profile","email","groups"]}}'

INVENTREE_GLOBAL_SETTINGS = '{"LOGIN_ENABLE_SSO":true,"LOGIN_ENABLE_SSO_REG":true,"LOGIN_ENABLE_REG":false,"LOGIN_ENABLE_PWD_FORGOT":false,"LOGIN_ENABLE_SSO_GROUP_SYNC":true,"SSO_GROUP_KEY":"groups","SSO_GROUP_MAP":"{\"dcusr-software\":\"Software\",\"dcusr-mech\":\"Mechanical\",\"dcusr-elec\":\"Electrical\",\"dcusr-business\":\"Business\",\"all access - website read-only\":\"Read Only\"}","SSO_REMOVE_GROUPS":true}'
EOH
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }

    task "inventree-worker" {
      driver = "docker"

      config {
        image   = "inventree/inventree:stable"

        command = "invoke"
        args    = ["worker"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/data:/home/inventree/data",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
INVENTREE_DB_ENGINE   = postgresql
INVENTREE_DB_NAME     = {{ key "dcusr/inventree/db/name" }}
INVENTREE_DB_USER     = {{ key "dcusr/inventree/db/user" }}
INVENTREE_DB_PASSWORD = {{ key "dcusr/inventree/db/password" }}

{{ range service "inventree-db" }}
INVENTREE_DB_HOST={{ .Address }}
INVENTREE_DB_PORT={{ .Port }}
{{ end }}

INVENTREE_CACHE_ENABLED=True

{{ range service "inventree-cache" }}
INVENTREE_CACHE_HOST={{ .Address }}
INVENTREE_CACHE_PORT={{ .Port }}
{{ end }}

INVENTREE_SITE_URL        = https://{{ env "NOMAD_META_domain" }}
INVENTREE_DEBUG           = False
INVENTREE_LOG_LEVEL       = WARNING
INVENTREE_PLUGINS_ENABLED = True

INVENTREE_EMAIL_HOST      = {{ key "dcusr/inventree/smtp/host" }}
INVENTREE_EMAIL_PORT      = {{ key "dcusr/inventree/smtp/port" }}
INVENTREE_EMAIL_USERNAME  = {{ key "dcusr/inventree/smtp/user" }}
INVENTREE_EMAIL_PASSWORD  = {{ key "dcusr/inventree/smtp/password" }}
INVENTREE_EMAIL_TLS       = True
INVENTREE_EMAIL_SENDER    = {{ key "dcusr/inventree/smtp/from" }}

INVENTREE_USE_X_FORWARDED_HOST=True
INVENTREE_USE_X_FORWARDED_PORT=True
INVENTREE_USE_X_FORWARDED_PROTO=True

INVENTREE_COOKIE_SAMESITE = Lax
INVENTREE_SESSION_COOKIE_SECURE = True

INVENTREE_SOCIAL_BACKENDS = allauth.socialaccount.providers.openid_connect
INVENTREE_SOCIAL_PROVIDERS = '{"openid_connect":{"EMAIL_AUTHENTICATION":true,"VERIFIED_EMAIL":true,"OAUTH_PKCE_ENABLED":true,"APPS":[{"provider_id":"authentik","name":"Authentik","client_id":"{{ key "dcusr/inventree/sso/client_id" }}","secret":"{{ key "dcusr/inventree/sso/client_secret" }}","settings":{"server_url":"{{ key "dcusr/inventree/sso/server_url" }}","OAUTH_PKCE_ENABLED":true}}],"SCOPE":["openid","profile","email","groups"]}}'

INVENTREE_GLOBAL_SETTINGS = '{"LOGIN_ENABLE_SSO":true,"LOGIN_ENABLE_SSO_REG":true,"LOGIN_ENABLE_REG":false,"LOGIN_ENABLE_PWD_FORGOT":false,"LOGIN_ENABLE_SSO_GROUP_SYNC":true,"SSO_GROUP_KEY":"groups","SSO_GROUP_MAP":"{\"dcusr-software\":\"Software\",\"dcusr-mech\":\"Mechanical\",\"dcusr-elec\":\"Electrical\",\"dcusr-business\":\"Business\",\"all access - website read-only\":\"Read Only\"}","SSO_REMOVE_GROUPS":true}'
EOH
      }

      resources {
        cpu    = 500
        memory = 2048
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
      max_parallel = 0
      auto_revert  = false
    }

    task "inventree-db" {
      driver         = "docker"
      kill_signal    = "SIGTERM"

      service {
        name = "inventree-db"
        port = "db"
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
POSTGRES_DB={{ key "dcusr/inventree/db/name" }}
POSTGRES_USER={{ key "dcusr/inventree/db/user" }}
POSTGRES_PASSWORD={{ key "dcusr/inventree/db/password" }}
EOH
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  group "cache" {
    count = 1

    network {
      port "redis" {
        to = 6379
      }
    }

    task "inventree-cache" {
      driver = "docker"

      service {
        name = "inventree-cache"
        port = "redis"
      }

      config {
        image = "redis:7-alpine"
        ports = ["redis"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}

