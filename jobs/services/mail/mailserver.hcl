job "mailserver" {
  datacenters = ["aperture"]

  type = "service"

  meta {
    tld    = "rb.dcu.ie"
    domain = "mail.rb.dcu.ie"
  }

  group "mail" {
    network {
      # mode = "bridge"
      port "http" {
        to = 80
      }

      port "smtp" {
        to = 25
      }

      port "submissions" {
        to = 465
      }

      port "submission" {
        to = 587
      }

      port "imap" {
        to = 143
      }

      port "imaps" {
        to = 993
      }

      port "pop3" {
        to = 110
      }

      port "pop3s" {
        to = 995
      }

      port "managesieve" {
        to = 4190
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

    service {
      name = "mail"
      # port = "http"

      tags = [
        "traefik.enable=true",
        # Explicit TLS (STARTTLS):
        # SMTP
        "traefik.tcp.routers.mail-smtp.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-smtp.entrypoints=smtp",
        "traefik.tcp.routers.mail-smtp.service=mail-smtp",
        "traefik.tcp.services.mail-smtp.loadbalancer.server.port=${NOMAD_HOST_PORT_smtp}",
        "traefik.tcp.services.mail-smtp.loadbalancer.proxyProtocol.version=2",

        # SMTP Submission
        "traefik.tcp.routers.mail-submission.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-submission.entrypoints=submission",
        "traefik.tcp.routers.mail-submission.service=mail-submission",
        "traefik.tcp.services.mail-submission.loadbalancer.server.port=${NOMAD_HOST_PORT_submission}",
        "traefik.tcp.services.mail-submission.loadbalancer.proxyProtocol.version=2",

        # IMAP
        "traefik.tcp.routers.mail-imap.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-imap.entrypoints=imap",
        "traefik.tcp.routers.mail-imap.service=mail-imap",
        "traefik.tcp.services.mail-imap.loadbalancer.server.port=${NOMAD_HOST_PORT_imap}",
        "traefik.tcp.services.mail-imap.loadbalancer.proxyProtocol.version=2",

        # POP3
        "traefik.tcp.routers.mail-pop3.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-pop3.entrypoints=pop3",
        "traefik.tcp.routers.mail-pop3.service=mail-pop3",
        "traefik.tcp.services.mail-pop3.loadbalancer.server.port=${NOMAD_HOST_PORT_pop3}",
        "traefik.tcp.services.mail-pop3.loadbalancer.proxyProtocol.version=2",

        # ManageSieve
        "traefik.tcp.routers.mail-managesieve.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-managesieve.entrypoints=managesieve",
        "traefik.tcp.routers.mail-managesieve.service=mail-managesieve",
        "traefik.tcp.services.mail-managesieve.loadbalancer.server.port=${NOMAD_HOST_PORT_managesieve}",
        "traefik.tcp.services.mail-managesieve.loadbalancer.proxyProtocol.version=2",

        # Implicit TLS is no different, except for optional HostSNI support:
        # SMTP Submission Secure
        # "traefik.tcp.routers.mail-submissions.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-submissions.entrypoints=submissions",
        "traefik.tcp.routers.mail-submissions.service=mail-submissions",
        "traefik.tcp.services.mail-submissions.loadbalancer.server.port=${NOMAD_HOST_PORT_submissions}",
        "traefik.tcp.services.mail-submissions.loadbalancer.proxyProtocol.version=2",
        # NOTE: Optionally match by SNI rule, this requires TLS passthrough (not compatible with STARTTLS):
        "traefik.tcp.routers.mail-submissions.rule=HostSNI(`${NOMAD_META_domain}`)",
        "traefik.tcp.routers.mail-submissions.tls.passthrough=true",

        # IMAP Secure
        # "traefik.tcp.routers.mail-imaps.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-imaps.entrypoints=imaps",
        "traefik.tcp.routers.mail-imaps.service=mail-imaps",
        "traefik.tcp.services.mail-imaps.loadbalancer.server.port=${NOMAD_HOST_PORT_imaps}",
        "traefik.tcp.services.mail-imaps.loadbalancer.proxyProtocol.version=2",
        # NOTE: Optionally match by SNI rule, this requires TLS passthrough (not compatible with STARTTLS):
        "traefik.tcp.routers.mail-imaps.rule=HostSNI(`${NOMAD_META_domain}`)",
        "traefik.tcp.routers.mail-imaps.tls.passthrough=true",

        # POP3 Secure
        # "traefik.tcp.routers.mail-pop3s.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-pop3s.entrypoints=pop3s",
        "traefik.tcp.routers.mail-pop3s.service=mail-pop3s",
        "traefik.tcp.services.mail-pop3s.loadbalancer.server.port=${NOMAD_HOST_PORT_pop3s}",
        "traefik.tcp.services.mail-pop3s.loadbalancer.proxyProtocol.version=2",
        # NOTE: Optionally match by SNI rule, this requires TLS passthrough (not compatible with STARTTLS):
        "traefik.tcp.routers.mail-pop3s.rule=HostSNI(`${NOMAD_META_domain}`)",
        "traefik.tcp.routers.mail-pop3s.tls.passthrough=true",
      ]
    }

    task "mail-server" {
      driver = "docker"

      config {
        image    = "ghcr.io/docker-mailserver/docker-mailserver:latest"
        ports    = ["smtp", "submissions", "submission", "imap", "imaps", "pop3", "pop3s", "managesieve"]
        hostname = "${NOMAD_META_domain}"
        volumes = [
          "/storage/nomad/mail/data/:/var/mail/",
          "/storage/nomad/mail/state/:/var/mail-state/",
          "/storage/nomad/mail/logs/:/var/log/mail/",
          "/storage/nomad/mail/config/:/tmp/docker-mailserver/",
          # "local/postfix-virtual.cf:/tmp/docker-mailserver/postfix-virtual.cf",
          "local/postfix-master.cf:/tmp/docker-mailserver/postfix-master.cf",
          "local/dovecot.cf:/tmp/docker-mailserver/dovecot.cf",
          "/etc/localtime:/etc/localtime:ro",
          "/oldstorage/home:/home/:ro",
          "/storage/nomad/traefik/acme/acme.json:/etc/letsencrypt/acme.json:ro",
        ]
      }
      resources {
        cpu    = 2000
        memory = 5000
      }

      template {
        data        = file("mailserver.env")
        destination = "local/mailserver.env"
        env         = true
      }

      template {
        data        = file("postfix-virtual.cf")
        destination = "local/postfix-virtual.cf"
      }

      template {
        data        = <<EOF
# Enable proxy protocol support for postfix
smtp/inet/postscreen_upstream_proxy_protocol=haproxy
submission/inet/smtpd_upstream_proxy_protocol=haproxy
submissions/inet/smtpd_upstream_proxy_protocol=haproxy
EOF
        destination = "local/postfix-master.cf"
      }

      template {
        data        = <<EOF
# Enable proxy protocol support for dovecot
haproxy_trusted_networks = 136.206.16.50

service imap-login {
  inet_listener imap {
    haproxy = yes
  }

  inet_listener imaps {
    haproxy = yes
  }
}

service pop3-login {
  inet_listener pop3 {
    haproxy = yes
  }

  inet_listener pop3s {
    haproxy = yes
  }
}

service managesieve-login {
  inet_listener sieve {
    haproxy = yes
  }
}
EOF
        destination = "local/dovecot.cf"
      }
    }
  }
}
