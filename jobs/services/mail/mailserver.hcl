job "mailserver" {
  datacenters = ["aperture"]
  type        = "service"

  constraint {
    attribute = "${meta.ingress_vip_node}"
    value     = "1"
  }

  meta {
    tld    = "redbrick.dcu.ie"
    domain = "mail.redbrick.dcu.ie"
    relay  = "lists.redbrick.dcu.ie"
  }

  group "mail" {
    network {
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

    service {
      name = "mailserver-smtp"
      port = "smtp"
    }

    service {
      name = "mailserver-submissions"
      port = "submissions"
    }

    service {
      name = "mailserver-submission"
      port = "submission"
    }

    service {
      name = "mailserver-imap"
      port = "imap"
    }

    service {
      name = "mailserver-imaps"
      port = "imaps"
    }

    service {
      name = "mailserver-pop3"
      port = "pop3"
    }

    service {
      name = "mailserver-pop3s"
      port = "pop3s"
    }

    service {
      name = "mailserver-managesieve"
      port = "managesieve"
    }

    task "whoami" {
      driver = "docker"

      config {
        image = "traefik/whoami"
        ports = ["http"]
      }

      service {
        name = "mail-http"
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
          "traefik.http.routers.mail-http.entrypoints=websecure",
          "traefik.http.routers.mail-http.tls=true",
        ]
      }
    }

    task "mail-server" {
      driver = "docker"

      config {
        image    = "ghcr.io/docker-mailserver/docker-mailserver:latest"
        hostname = "mail.redbrick.dcu.ie"

        ports = [
          "smtp",
          "submissions",
          "submission",
          "imap",
          "imaps",
          "pop3",
          "pop3s",
          "managesieve"
        ]

        volumes = [
          # mount mailserver dirs
          "/storage/nomad/mail/data/:/var/mail/",
          "/storage/nomad/mail/state/:/var/mail-state/",
          "/storage/nomad/mail/logs/:/var/log/mail/",
          "/storage/nomad/mail/config/:/tmp/docker-mailserver/",

          # Use extracted wildcard PEM certs, not Traefik ACME JSON.
          "/storage/nomad/traefik/certs/redbrick.dcu.ie:/etc/docker-mailserver/ssl/redbrick.dcu.ie:ro",

          "local/postfix-main.cf:/tmp/docker-mailserver/postfix-main.cf",
          "local/transport:/etc/postfix/transport",

          # Add a blocklist and whitelist for senders to control who can send to us and who we will accept mail from.
          "local/sender_blocklist:/etc/postfix/sender_blocklist:ro",
          "local/sender_whitelist:/etc/postfix/sender_whitelist:ro",
          "local/postfix-sender-login.pcre:/etc/postfix/postfix-sender-login.pcre:ro",
          "local/10-auth.conf:/etc/dovecot/conf.d/10-auth.conf:ro",
          "local/aliases:/tmp/docker-mailserver/aliases:ro",
          "local/sasl_access:/etc/postfix/sasl_access:ro",
          "local/99-proxy-protocol.conf:/etc/dovecot/conf.d/99-proxy-protocol.conf:ro",

          "/etc/localtime:/etc/localtime:ro",
          "/storage/home:/home/:ro",

          # Mount persistant master.cf to keep smtpd_client_restrictions settings across restarts
          "/storage/nomad/mail/master.cf:/etc/postfix/master.cf:ro",
        ]
      }

      template {
        data        = file("mailserver.env")
        destination = "local/mailserver.env"
        env         = true
      }

      template {
        data        = file("aliases")
        destination = "local/aliases"
      }

      template {
        destination = "local/postfix-main.cf"
        data        = <<EOH
# enable a transport map
transport_maps = texthash:/etc/postfix/transport
relay_domains  = {{ env "NOMAD_META_relay"}}

# Use a PCRE map to map envelope senders -> allowed SASL logins
# PCRE supports patterns so we can permit all normal users and mailman.
smtpd_sender_login_maps = pcre:/etc/postfix/postfix-sender-login.pcre

# Allow only mailman senders (Mailman) to send as list addresses
# and allow authenticated users/mynetworks before rejecting mismatches.
smtpd_sender_restrictions =
  check_sender_access texthash:/etc/postfix/sender_blocklist,
  check_sender_access texthash:/etc/postfix/sender_whitelist,
  permit_mynetworks,
  permit_sasl_authenticated,
  reject_non_fqdn_sender,
  reject_unknown_sender_domain,
  reject_unlisted_sender,
  reject_unauth_pipelining,
  reject_sender_login_mismatch,

# Rate limit outgoing mail to prevent spam (100/day)
smtpd_client_message_rate_limit = 100
smtpd_client_auth_rate_limit = 100
anvil_rate_time_unit = 1d

# This file is so that aliases resolve correctly
virtual_alias_maps = texthash:/tmp/docker-mailserver/aliases
EOH
      }

      template {
        destination = "local/sender_blocklist"
        data        = <<EOH
{{ key "mail/postfix/sender_blocklist" }}
EOH
      }

      template {
        destination = "local/sender_whitelist"
        data        = <<EOH
# taken from https://github.com/redbrick/nix-configs/blob/master/services/postfix/default.nix#L35

# Allows mailman to spoof addresses
mailman@{{ env "NOMAD_META_tld" }} OK
EOH
      }

      template {
        destination = "local/postfix-sender-maps"
        data        = <<EOH
# taken from https://github.com/redbrick/nix-configs/blob/master/services/postfix/default.nix#L29

# This is to allow normal users to send emails
query_filter = (uid=%u)
result_attribute = uid
result_format = %s@{{ env "NOMAD_META_tld" }}
EOH
      }

      template {
        destination = "local/postfix-sender-login.pcre"
        data        = <<EOH
# Allow Mailman SASL user to send as any list address under lists.redbrick.dcu.ie
/@lists\.redbrick\.dcu\.ie$/    mailman@{{ env "NOMAD_META_tld" }}

# Allow authenticated users to send as their own address.
# When an envelope is "alice@redbrick.dcu.ie" this returns "alice alice@redbrick.dcu.ie"
# so either SASL username form will be accepted.
/^([^@]+)@redbrick\.dcu\.ie$/    $1 $1@{{ env "NOMAD_META_tld" }}

# Allow bare localpart SASL usernames to send as localpart@redbrick.dcu.ie
/^([^@]+)$/    $1 $1@{{ env "NOMAD_META_tld" }}
EOH
      }

      template {
        destination = "local/transport"
        data        = <<EOH
{{ env "NOMAD_META_relay" }}  lmtp:[{{ range service "mailman-lmtp" }}{{ .Address }}{{ end }}]:{{ range service "mailman-lmtp" }}{{ .Port }}{{ end }}
EOH
      }

      template {
        destination = "local/10-auth.conf"
        data        = <<EOH
# taken from https://github.com/redbrick/nix-configs/blob/master/services/dovecot/auth.nix#L22

# cache all authentication results for one hour
auth_cache_size = 10M
auth_cache_ttl = 1 hour
auth_cache_negative_ttl = 1 hour

# Set domain for login names without a domain specified
auth_default_realm = {{ env "NOMAD_META_tld" }}

# only use plain username/password auth - OK since everything is over TLS
auth_mechanisms = plain login

# Don't strip domain from username. Means that mail_location can reference %d
auth_username_format = %Lu

!include auth-ldap.conf.ext
EOH
      }

      template {
        destination = "local/sasl_access"
        data        = <<EOH
{{ key "mail/postfix/sasl_access" }}
EOH
      }

      template {
        destination = "local/99-proxy-protocol.conf"
        data        = <<EOH
# Enable PROXY protocol support for mail traffic proxied by Traefik.
haproxy_trusted_networks = 127.0.0.1/32 10.10.0.0/16 10.20.0.0/16 136.206.16.0/24

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
EOH
      }

      resources {
        cpu    = 800
        memory = 4096
      }
    }
  }
}