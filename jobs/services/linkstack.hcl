job "linkstack" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "links.rb.dcu.ie"
  }

  group "linkstack" {
    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "linkstack"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.linkstack.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.linkstack.entrypoints=web,websecure",
        "traefik.http.routers.linkstack.tls.certresolver=rb",
        "traefik.http.routers.linkstack.tls=true",
        "traefik.http.routers.linkstack.service=linkstack",
        "traefik.http.middlewares.name-head.headers.customrequestheaders.X-Forwarded-Proto=https",
        "traefik.http.middlewares.name-head.headers.customResponseHeaders.X-Robots-Tag=none",
        "traefik.http.middlewares.name-head.headers.customResponseHeaders.Strict-Transport-Security=max-age=63072000",
        "traefik.http.middlewares.name-head.headers.stsSeconds=31536000",
        "traefik.http.middlewares.name-head.headers.accesscontrolalloworiginlist=*",
        "traefik.http.routers.linkstack.middlewares=name-head",
      ]
    }


    task "linkstack" {
      driver = "docker"

      config {
        image = "linkstackorg/linkstack:latest"
        ports = ["http"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/htdocs",
          "local/.env:/htdocs/.env",
        ]
      }

      resources {
        cpu    = 1000
        memory = 1024
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

      template {
        destination = "local/.env"
        env         = false
        data        = <<EOH
LOCALE=en

# auth or verified. auth required email verificaiton
REGISTER_AUTH=verified
ALLOW_REGISTRATION=false

NOTIFY_EVENTS=true
NOTIFY_UPDATES=true
DISPLAY_FOOTER=true
DISPLAY_CREDIT=false
DISPLAY_CREDIT_FOOTER=false

ADMIN_EMAIL={{ key "linkstack/admin/email" }}

SUPPORTED_DOMAINS=""

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
DB_CONNECTION=sqlite

MAIL_MAILER=smtp
MAIL_HOST=mail.redbrick.dcu.ie
MAIL_PORT=465
MAIL_USERNAME={{ key "linkstack/ldap/username" }}
MAIL_PASSWORD={{ key "linkstack/ldap/password" }}
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS={{ key "linkstack/from/address" }}
MAIL_FROM_NAME="${APP_NAME}"

#Cache Settings=Completely optional.
MEMCACHED_HOST=127.0.0.1
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

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
ALLOW_CUSTOM_CODE_IN_THEMES=false

ENABLE_THEME_UPDATER=true

ENABLE_SOCIAL_LOGIN=false

USE_THEME_PREVIEW_IFRAME=true

FORCE_ROUTE_HTTPS=false

DISPLAY_FOOTER_HOME=true
DISPLAY_FOOTER_TERMS=true
DISPLAY_FOOTER_PRIVACY=true
DISPLAY_FOOTER_CONTACT=false

TITLE_FOOTER_HOME=
TITLE_FOOTER_TERMS=
TITLE_FOOTER_PRIVACY=
TITLE_FOOTER_CONTACT=

HOME_FOOTER_LINK=""

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
  }
}
