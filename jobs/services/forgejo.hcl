job "forgejo" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "git.redbrick.dcu.ie"
  }

  group "web" {
    network {
      port "http" {
        to = 3000
      }

      port "ssh" {
      }

      port "db" {
        to = 5432
      }
    }

    service {
      name = "forgejo-web"
      port = "http"

      # check {
      #   type     = "http"
      #   path     = "/"
      #   interval = "10s"
      #   timeout  = "2s"
      # }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.forgejo-web.rule=Host(`git.redbrick.dcu.ie`)",
        "traefik.http.routers.forgejo-web.entrypoints=websecure",
        "traefik.http.routers.forgejo-web.tls.certresolver=rb"
      ]
    }

    service {
      name = "forgejo-ssh"
      port = "ssh"

      # check {
      #   type     = "http"
      #   path     = "/"
      #   interval = "10s"
      #   timeout  = "2s"
      # }

      tags = [
        "traefik.tcp.routers.forgejo-ssh.rule=HostSNI(`git.redbrick.dcu.ie`)",
        "traefik.tcp.routers.forgejo-ssh.entrypoints=ssh",
        "traefik.tcp.routers.forgejo-ssh.service=forgejo-ssh",
        "traefik.tcp.services.forgejo-ssh.loadbalancer.server.port=${NOMAD_PORT_ssh}",
        "traefik.tcp.services.forgejo-ssh.loadbalancer.proxyProtocol.version=2",
      ]
    }

    task "forgejo" {
      driver = "docker"

      config {
        image = "codeberg.org/forgejo/forgejo:16"
        ports = ["http", "ssh"]

        volumes = [
          "/storage/nomad/${NOMAD_TASK_NAME}:/data",
          "/etc/timezone:/etc/timezone:ro",
          "/etc/localtime:/etc/localtime:ro",
        ]
      }

      resources {
        cpu    = 300
        memory = 500
      }
      template {
        destination = "local/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
# check https://forgejo.org/docs/next/admin/config-cheat-sheet/ for full list of options

FORGEJO____APP_NAME = Redbrick Git
FORGEJO____RUN_MODE = prod
FORGEJO____APP_SLOGAN =
FORGEJO____RUN_USER = git
FORGEJO____WORK_PATH = /data/gitea

FORGEJO__repository__ROOT = /data/git/repositories
FORGEJO__repository.local__LOCAL_COPY_PATH = /data/gitea/tmp/local-repo
FORGEJO__repository.upload__TEMP_PATH = /data/gitea/uploads

FORGEJO__server__APP_DATA_PATH = /data/gitea
FORGEJO__server__DOMAIN = git.redbrick.dcu.ie
FORGEJO__server__SSH_DOMAIN = git.redbrick.dcu.ie
FORGEJO__server__HTTP_PORT = 3000
FORGEJO__server__ROOT_URL = https://git.redbrick.dcu.ie/
FORGEJO__server__DISABLE_SSH = false
FORGEJO__server__SSH_PORT = 22
FORGEJO__server__SSH_LISTEN_PORT = {{ env "NOMAD_PORT_ssh" }}
FORGEJO__server__LFS_START_SERVER = true
FORGEJO__server__LFS_JWT_SECRET = {{ key "forgejo/server/jwt_secret" }}
FORGEJO__server__OFFLINE_MODE = false

FORGEJO__database__DB_TYPE = postgres
FORGEJO__database__HOST = {{ env "NOMAD_ADDR_db" }}
FORGEJO__database__NAME = {{ key "forgejo/db/name" }}
FORGEJO__database__USER = {{ key "forgejo/db/user"}}
FORGEJO__database__PASSWD = {{ key "forgejo/db/password" }}
FORGEJO__database__SSL_MODE = disable

FORGEJO__indexer__ISSUE_INDEXER_PATH = /data/gitea/indexers/issues.bleve

FORGEJO__session__PROVIDER_CONFIG = /data/gitea/sessions
FORGEJO__session__PROVIDER = file

FORGEJO__picture__AVATAR_UPLOAD_PATH = /data/gitea/avatars
FORGEJO__picture__REPOSITORY_AVATAR_UPLOAD_PATH = /data/gitea/repo-avatars

FORGEJO__attachment__PATH = /data/gitea/attachments

FORGEJO__log__MODE = console
FORGEJO__log__LEVEL = DEBUG
FORGEJO__log__ROOT_PATH = /data/gitea/log

FORGEJO__security__INSTALL_LOCK = true
FORGEJO__security__SECRET_KEY = ; {{ key "forgejo/security/secret_key" }}
FORGEJO__security__REVERSE_PROXY_LIMIT = 1
FORGEJO__security__REVERSE_PROXY_TRUSTED_PROXIES = 136.206.16.4,136.206.16.5,136.206.16.6
FORGEJO__security__INTERNAL_TOKEN = {{ key "forgejo/security/internal_token" }}
FORGEJO__security__PASSWORD_HASH_ALGO = argon2

FORGEJO__service__DISABLE_REGISTRATION = true
FORGEJO__service__REQUIRE_SIGNIN_VIEW = false
FORGEJO__service__REGISTER_EMAIL_CONFIRM = false
FORGEJO__service__ENABLE_NOTIFY_MAIL = false
FORGEJO__service__ALLOW_ONLY_EXTERNAL_REGISTRATION = false
FORGEJO__service__ENABLE_CAPTCHA = false
FORGEJO__service__DEFAULT_KEEP_EMAIL_PRIVATE = true
FORGEJO__service__DEFAULT_ALLOW_CREATE_ORGANIZATION = true
FORGEJO__service__DEFAULT_ENABLE_TIMETRACKING = true
FORGEJO__service__NO_REPLY_ADDRESS = noreply.redbrick.dcu.ie

FORGEJO__lfs__PATH = /data/git/lfs

FORGEJO__mailer__ENABLED = true
FORGEJO__mailer__SMTP_ADDR = 192.168.0.158
FORGEJO__mailer__SMTP_PORT = 587
FORGEJO__mailer__FROM = "Redbrick Git" <git@redbrick.dcu.ie>
FORGEJO__mailer__USER =
FORGEJO__mailer__PASSWD =

FORGEJO__openid__ENABLE_OPENID_SIGNIN = false
FORGEJO__openid__ENABLE_OPENID_SIGNUP = false

FORGEJO__cron.update_checker__ENABLED = true

FORGEJO__repository.pull_request__DEFAULT_MERGE_STYLE = merge

FORGEJO__repository.signing__DEFAULT_TRUST_MODEL = committer

FORGEJO__repository.signing__JWT_SECRET = {{ key "forgejo/repository/jwt_secret" }}
EOH
      }
    }

    task "forgejo-db" {
      driver = "docker"

      config {
        image = "postgres:14-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/forgejo/db:/var/lib/postgresql/data",
        ]
      }

      template {
        data        = <<EOH
POSTGRES_PASSWORD={{ key "forgejo/db/password" }}
POSTGRES_USER={{ key "forgejo/db/user" }}
POSTGRES_NAME={{ key "forgejo/db/name" }}
EOH
        destination = "local/db.env"
        env         = true
      }
    }
  }
}

