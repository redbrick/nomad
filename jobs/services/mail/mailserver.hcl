job "mailserver" {
  datacenters = ["aperture"]
  type        = "service"
  node_pool   = "ingress"

  meta {
    tld    = "redbrick.dcu.ie"
    domain = "mail.redbrick.dcu.ie"
  }

  group "mail" {
    network {
      port "http" {
        to = 80
      }

      port "smtp" {
        static = 25
      }

      port "submissions" {
        static = 465
      }

      port "submission" {
        static = 587
      }

      port "imap" {
        static = 143
      }

      port "imaps" {
        static = 993
      }

      port "pop3" {
        static = 110
      }

      port "pop3s" {
        static = 995
      }

      port "managesieve" {
        static = 4190
      }
    }

    task "whoami" {
      driver = "docker"

      config {
        image = "traefik/whoami"
        ports = ["http"]
      }

      service {
        name = "whoami"
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
          "traefik.http.routers.mail-http.rule=Host(`${NOMAD_META_domain}`)",
          "traefik.http.routers.mail-http.entrypoints=web,websecure",
          "traefik.http.routers.mail-http.tls.certresolver=lets-encrypt",
        ]
      }
    }

    task "mail-server" {
      driver = "docker"

      config {
        image = "ghcr.io/docker-mailserver/docker-mailserver:latest"
        ports = ["smtp", "submissions", "submission", "imap", "imaps", "pop3", "pop3s", "managesieve"]

        volumes = [
          # mount mailserver dirs
          "/storage/nomad/mail/data/:/var/mail/",
          "/storage/nomad/mail/state/:/var/mail-state/",
          "/storage/nomad/mail/logs/:/var/log/mail/",
          "/storage/nomad/mail/config/:/tmp/docker-mailserver/",

          # acme.json in read-only mode so certs can be generated
          "/storage/nomad/traefik/acme/acme.json:/etc/letsencrypt/acme.json:ro",

          # "local/dovecot.cf:/tmp/docker-mailserver/dovecot.cf",
          "local/postfix-main.cf:/tmp/docker-mailserver/postfix-main.cf",
          "local/transport:/etc/postfix/transport",

          "/etc/localtime:/etc/localtime:ro",

          # TODO: wrong dir, fix 
          "/storage/zbackup/oldstorage/home:/home/:ro",
        ]
      }

      template {
        data        = file("mailserver.env")
        destination = "local/mailserver.env"
        env         = true
      }

      #       template {
      #         destination = "local/dovecot.cf"
      #         data        = <<EOH
      # mail_gid=5000
      # EOH
      #       }

      template {
        destination = "local/postfix-main.cf"
        data        = <<EOH
# enable a transport map
transport_maps = texthash:/etc/postfix/transport
relay_domains = lists.redbrick.dcu.ie
EOH
      }

      template {
        destination = "local/transport"
        data        = <<EOH
lists.redbrick.dcu.ie  lmtp:[{{ range service "mailman-lmtp" }}{{ .Address }}{{ end }}]:{{ range service "mailman-lmtp" }}{{ .Port }}{{ end }}
EOH
      }

      resources {
        cpu    = 800
        memory = 2048
      }
    }
  }
}
