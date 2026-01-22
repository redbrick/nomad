job "linkstack" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "links.rb.dcu.ie"
  }

  group "linkstack" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    service {
      name = "linkstack"
      port = "http"

      # check {
      #   type      = "http"
      #   path      = "/"
      #   interval  = "10s"
      #   timeout   = "2s"
      # }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.linkstack.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.linkstack.entrypoints=websecure",
        "traefik.http.routers.linkstack.tls.certresolver=rb",
        "traefik.http.routers.linkstack.tls=true",
      ]
    }


    task "linkstack" {
      driver = "docker"

      config {
        image = "linkstackorg/linkstack:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}/advanced-config.php:/htdocs/config/advanced-config.php",
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}/images:/htdocs/assets/linkstack/images",
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}/themes:/htdocs/themes",
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}/assets/img:/htdocs/assets/img",
          "local/.env:/htdocs/.env",
        ]
      }

      resources {
        cpu    = 800
        memory = 768
      }

      template {
        destination = "local/file.env"
        env         = true
        data        = <<EOH
TZ=Europe/Dublin
SERVER_ADMIN=elected-admins@redbrick.dcu.ie
HTTP_SERVER_NAME={{ env "NOMAD_META_domain" }}
HTTPS_SERVER_NAME={{ env "NOMAD_META_domain" }}
LOG_LEVEL=info
PHP_MEMORY_LIMIT=512M
UPLOAD_MAX_FILESIZE=16M
EOH
      }

      # NOTE: Not a real .env file, but used by LinkStack as its config, for some reason...
      template {
        destination = "local/.env"
        env         = false
        change_mode = "noop"
        data        = <<EOH
LOCALE=en

# auth or verified. auth required email verification
REGISTER_AUTH=verified
ALLOW_REGISTRATION=false

NOTIFY_EVENTS=true
NOTIFY_UPDATES=true
DISPLAY_FOOTER=true
DISPLAY_CREDIT=false
DISPLAY_CREDIT_FOOTER=false

ADMIN_EMAIL={{ key "linkstack/admin/email" }}

SUPPORTED_DOMAINS="{{ env "NOMAD_META_domain" }}"

#=Leave empty to use the default homepage.
#or user's profile e.g. 'admin' without the '@'
HOME_URL="redbrick"

ALLOW_USER_HTML=true

APP_NAME="Redbrick Links"
APP_KEY={{ key "linkstack/app/key" }}
#=The APP_URL should be left empty under most circumstances. This setting is not required for LinkStack, and you should only change this if required for your setup.
APP_URL=https://{{ env "NOMAD_META_domain" }}

#ENABLE_BUTTON_EDITOR=Determines if the custom button editor should be enabled or not, default is true.
ENABLE_BUTTON_EDITOR=true

APP_DEBUG=false
APP_ENV=production
LOG_CHANNEL=stack
LOG_LEVEL=info
#=Disables all routes and displays a Maintenance placeholder page.
MAINTENANCE_MODE=false

#Database Settings=Should be left alone. If you wish to use mysql you'd have to seed the database again.
DB_CONNECTION=mysql
{{- range service "linkstack-db" }}
DB_HOST={{ .Address }}
DB_PORT={{ .Port }}
{{- end }}
DB_DATABASE={{ key "linkstack/db/name" }}
DB_USERNAME={{ key "linkstack/db/user" }}
DB_PASSWORD={{ key "linkstack/db/password" }}

MAIL_MAILER=smtp
MAIL_HOST=mail.redbrick.dcu.ie
MAIL_PORT=465
MAIL_USERNAME={{ key "linkstack/ldap/username" }}
MAIL_PASSWORD={{ key "linkstack/ldap/password" }}
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS={{ key "linkstack/ldap/username" }}@redbrick.dcu.ie
MAIL_FROM_NAME="${APP_NAME}"

#Miscellaneous Settings=Should be left alone if you don't know what you're doing.
BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

#Updater Settings=Changes settings regarding the built-in updater.
JOIN_BETA=false
#=SKIP_UPDATE_BACKUP either true or false. Skips backup before updating. Use at your own risk.
SKIP_UPDATE_BACKUP=false

#=CUSTOM_META_TAGS either true or false. Used to enable setting in advanced config file (config/advanced-config.php).
#=You can read more about this config at https://llc.bio/advanced-config.
CUSTOM_META_TAGS=false

# this has to be true according to the docs: https://docs.linkstack.org/docker/reverse-proxies/
FORCE_HTTPS=true

#=Defines wether or not themes are allowed to inject custom code.
ALLOW_CUSTOM_CODE_IN_THEMES=true

ENABLE_THEME_UPDATER=true

ENABLE_SOCIAL_LOGIN=false

USE_THEME_PREVIEW_IFRAME=true

# traefik terminates TLS, don't need to force it here
FORCE_ROUTE_HTTPS=false

DISPLAY_FOOTER_HOME=true
DISPLAY_FOOTER_TERMS=true
DISPLAY_FOOTER_PRIVACY=true
DISPLAY_FOOTER_CONTACT=false

TITLE_FOOTER_HOME=
TITLE_FOOTER_TERMS=
TITLE_FOOTER_PRIVACY=
TITLE_FOOTER_CONTACT=

HOME_FOOTER_LINK=https://{{ env "NOMAD_META_domain" }}/

HIDE_VERIFICATION_CHECKMARK=false

ALLOW_CUSTOM_BACKGROUNDS=true

ALLOW_USER_EXPORT=true

ALLOW_USER_IMPORT=true

MANUAL_USER_VERIFICATION=true

ENABLE_REPORT_ICON=false

ENABLE_ADMIN_BAR=true
ENABLE_ADMIN_BAR_USERS=true
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
        image   = "mariadb:12"
        command = "sh"
        args = [
          "-c",
          "until mariadb-admin ping -h\"${DB_HOST}\" -P\"${DB_PORT}\" --silent; do echo 'Waiting for DB...'; sleep 1; done; echo 'DB is ready!'"
        ]
      }

      template {
        destination = "local/wait.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
    {{ range service "linkstack-db" }}
    DB_HOST={{ .Address }}
    DB_PORT={{ .Port }}
    {{ end }}
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
        to = 3306
      }
    }

    update {
      max_parallel = 0 # don't update this group automatically
      auto_revert  = false
    }

    task "db" {
      driver         = "docker"
      kill_signal    = "SIGTERM" # SIGTERM instead of SIGKILL so database can shutdown safely
      kill_timeout   = "30s"
      shutdown_delay = "5s"

      service {
        name = "linkstack-db"
        port = "db"

        check {
          name     = "mariadb-probe"
          type     = "tcp"
          interval = "10s"
          timeout  = "1s"

        }
      }

      config {
        image = "mariadb:12"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/mysql",
          "local/server.cnf:/etc/mysql/mariadb.conf.d/50-server.cnf",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        data        = <<EOH
MARIADB_RANDOM_ROOT_PASSWORD=true
MARIADB_PASSWORD={{ key "linkstack/db/password" }}
MARIADB_USER={{ key "linkstack/db/user" }}
MARIADB_DATABASE={{ key "linkstack/db/name" }}
EOH
      }
      template {
        destination = "local/server.cnf"
        data        = <<EOH
[server]

[mariadbd]

pid-file                = /run/mysqld/mysqld.pid
basedir                 = /usr

bind-address            = 0.0.0.0

expire_logs_days        = 10

character-set-server     = utf8mb4
character-set-collations = utf8mb4=uca1400_ai_ci

[mariadbd]
        EOH
      }

      resources {
        cpu    = 400
        memory = 800
      }
    }
  }
}
