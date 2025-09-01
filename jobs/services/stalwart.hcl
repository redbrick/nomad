job "stalwart" {
  datacenters = ["aperture"]
  type        = "service"

  meta = { 
    domain = "mail.rb.dcu.ie" 
  }

  group "stalwart" {
    count = 1

    network {
      port "smtp" { 
        to = 25  
      }
      port "submissions" { 
        to = 465 
      }
      port "submission" { 
        to = 587 
      }
      port "imap"  { 
        to = 143 
      }
      port "imaps" { 
        to = 993 
      }
      port "pop3"  { 
        to = 110 
      }
      port "pop3s" { 
        to = 995 
      }
      port "sieve" { 
        to = 4190 
      }
      port "http" { 
        to = 8080 
      }
    }

    service {
      name = "stalwart-admin"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.stalwart-admin.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.stalwart-admin.entrypoints=websecure",
        "traefik.http.routers.stalwart-admin.tls.certresolver=lets-encrypt",
      ]

      check {
        type     = "http"
        method   = "GET"
        path     = "/login"
        interval = "20s"
        timeout  = "2s"
      }
    }

    service {
      name = "mail-smtp"
      port = "smtp"
      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.mail-smtp.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-smtp.entrypoints=smtp",
        "traefik.tcp.routers.mail-smtp.service=mail-smtp",
        "traefik.tcp.services.mail-smtp.loadbalancer.proxyProtocol.version=2",
      ]
    }

    service {
      name = "mail-submission"
      port = "submission"
      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.mail-submission.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-submission.entrypoints=submission",
        "traefik.tcp.routers.mail-submission.service=mail-submission",
        "traefik.tcp.services.mail-submission.loadbalancer.proxyProtocol.version=2",
      ]
    }

    service {
      name = "mail-imap"
      port = "imap"
      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.mail-imap.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-imap.entrypoints=imap",
        "traefik.tcp.routers.mail-imap.service=mail-imap",
        "traefik.tcp.services.mail-imap.loadbalancer.proxyProtocol.version=2",
      ]
    }

    service {
      name = "mail-pop3"
      port = "pop3"
      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.mail-pop3.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-pop3.entrypoints=pop3",
        "traefik.tcp.routers.mail-pop3.service=mail-pop3",
        "traefik.tcp.services.mail-pop3.loadbalancer.proxyProtocol.version=2",
      ]
    }

    service {
      name = "mail-managesieve"
      port = "sieve"
      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.mail-managesieve.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-managesieve.entrypoints=managesieve",
        "traefik.tcp.routers.mail-managesieve.service=mail-managesieve",
        "traefik.tcp.services.mail-managesieve.loadbalancer.proxyProtocol.version=2",
      ]
    }

    service {
      name = "mail-imaps"
      port = "imaps"
      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.mail-imaps.entrypoints=imaps",
        "traefik.tcp.routers.mail-imaps.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-imaps.tls.passthrough=true",
        "traefik.tcp.routers.mail-imaps.service=mail-imaps",
        "traefik.tcp.services.mail-imaps.loadbalancer.proxyProtocol.version=2",
      ]
    }

    service {
      name = "mail-submissions"
      port = "submissions"
      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.mail-submissions.entrypoints=submissions",
        "traefik.tcp.routers.mail-submissions.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-submissions.tls.passthrough=true",
        "traefik.tcp.routers.mail-submissions.service=mail-submissions",
        "traefik.tcp.services.mail-submissions.loadbalancer.proxyProtocol.version=2",
      ]
    }

    service {
      name = "mail-pop3s"
      port = "pop3s"
      tags = [
        "traefik.enable=true",
        "traefik.tcp.routers.mail-pop3s.entrypoints=pop3s",
        "traefik.tcp.routers.mail-pop3s.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mail-pop3s.tls.passthrough=true",
        "traefik.tcp.routers.mail-pop3s.service=mail-pop3s",
        "traefik.tcp.services.mail-pop3s.loadbalancer.proxyProtocol.version=2",
      ]
    }

    task "stalwart" {
      driver = "docker"

      env {
        LDAP_URL         = "ldap://192.168.0.150"
        LDAP_BASE_DN     = "o=redbrick,ou=accounts"
        LDAP_DN_TEMPLATE = "uid={username},ou=accounts,o=redbrick"
        LDAP_STARTTLS    = "false"
      }

      config {
        image = "stalwartlabs/stalwart:latest"
        args  = ["--config=/local/config/config.toml"]
        ports = ["http","smtp","submission","submissions","imap","imaps","pop3","pop3s","sieve"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/storage:/opt/stalwart-mail/storage",
          "/etc/localtime:/etc/localtime:ro"
        ]
      }

      template {
        destination = "local/config/config.toml"
        data = <<EOF
          server.hostname = "mail.rb.dcu.ie"
          http.use-x-forwarded = true
          http.hsts = true

          [server.listener."http"]
          bind     = ["[::]:{{ env "NOMAD_PORT_http" }}"]
          protocol = "http"

          [server.listener."smtp"]
          bind     = ["[::]:{{ env "NOMAD_PORT_smtp" }}"]
          protocol = "smtp"
          [server.listener."smtp".proxy]
          override = true
          trusted-networks = ["0.0.0.0/0","::/0"]

          [server.listener."submission"]
          bind     = ["[::]:{{ env "NOMAD_PORT_submission" }}"]
          protocol = "smtp"
          [server.listener."submission".proxy]
          override = true
          trusted-networks = ["0.0.0.0/0","::/0"]

          [server.listener."imap"]
          bind     = ["[::]:{{ env "NOMAD_PORT_imap" }}"]
          protocol = "imap"
          [server.listener."imap".proxy]
          override = true
          trusted-networks = ["0.0.0.0/0","::/0"]

          [server.listener."pop3"]
          bind     = ["[::]:{{ env "NOMAD_PORT_pop3" }}"]
          protocol = "pop3"
          [server.listener."pop3".proxy]
          override = true
          trusted-networks = ["0.0.0.0/0","::/0"]

          [server.listener."sieve"]
          bind     = ["[::]:{{ env "NOMAD_PORT_sieve" }}"]
          protocol = "managesieve"
          [server.listener."sieve".proxy]
          override = true
          trusted-networks = ["0.0.0.0/0","::/0"]

          [server.listener."imaps"]
          bind         = ["[::]:{{ env "NOMAD_PORT_imaps" }}"]
          protocol     = "imap"
          tls.implicit = true
          [server.listener."imaps".proxy]
          override = true
          trusted-networks = ["136.206.16.50/32","::/0"]

          [server.listener."submissions"]
          bind         = ["[::]:{{ env "NOMAD_PORT_submissions" }}"]
          protocol     = "smtp"
          tls.implicit = true
          [server.listener."submissions".proxy]
          override = true
          trusted-networks = ["0.0.0.0/0","::/0"]

          [server.listener."pop3s"]
          bind         = ["[::]:{{ env "NOMAD_PORT_pop3s" }}"]
          protocol     = "pop3"
          tls.implicit = true
          [server.listener."pop3s".proxy]
          override = true
          trusted-networks = ["0.0.0.0/0","::/0"]

          [storage]
          directory = "ldap"

          [directory."ldap"]
          type    = "ldap"
          url     = "{{ env "LDAP_URL" }}"
          timeout = "30s"
          base-dn = "{{ env "LDAP_BASE_DN" }}"

          [directory."ldap".tls]
          enable = {{ env "LDAP_STARTTLS" }}

          [directory."ldap".bind]
          dn = "cn=root,ou=services,o=redbrick"
          secret = 'sooSh0eesh~ooPaghei8'

          [directory."ldap".bind.auth]
          method   = "template"
          template = "{{ env "LDAP_DN_TEMPLATE" }}"

          [directory."ldap".filter]
          name  = "(&(objectClass=posixAccount)(uid=?))"
          email = "(&(|(objectClass=posixAccount)(objectClass=posixGroup))(|(mail=?)(altmail=?)))"

          [directory."ldap".attributes]
          name           = "uid"
          class          = "objectClass"
          description    = ["gecos","description"]
          email          = "altmail"
          quota          = "quota"
          secret         = "userPassword"
          secret-changed = "shadowLastChange"

          [authentication.fallback-admin]
          user   = "admin"
          secret = "{{ key "stalwart/admin/secret_hash" }}"

          [tracer.console]
          type   = "console"
          level  = "trace"
          ansi   = true
          enable = true
        EOF
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      restart {
        attempts = 3
        interval = "30s"
        delay    = "10s"
        mode     = "fail"
      }
    }
  }
}

