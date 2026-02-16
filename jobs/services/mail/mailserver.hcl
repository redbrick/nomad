job "mailserver" {
  datacenters = ["aperture"]
  type        = "service"
  node_pool   = "ingress"

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

          "local/postfix-main.cf:/tmp/docker-mailserver/postfix-main.cf",
          "local/transport:/etc/postfix/transport",
          "local/sender_whitelist:/etc/postfix/sender_whitelist:ro",
          "local/postfix-sender-login.pcre:/etc/postfix/postfix-sender-login.pcre:ro",
          "local/10-auth.conf:/etc/dovecot/conf.d/10-auth.conf:ro",
          "local/aliases:/tmp/docker-mailserver/aliases:ro",

          "/etc/localtime:/etc/localtime:ro",

          "/storage/home:/home/:ro",
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
  check_sender_access texthash:/etc/postfix/sender_whitelist,
  permit_mynetworks,
  permit_sasl_authenticated,
  reject_non_fqdn_sender,
  reject_unknown_sender_domain,
  reject_unlisted_sender,
  reject_unauth_pipelining,
  reject_sender_login_mismatch,
  warn_if_reject,
  reject_unverified_sender

# This file is so that aliases resolve correctly
virtual_alias_maps = texthash:/tmp/docker-mailserver/aliases
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

      resources {
        cpu    = 800
        memory = 4096
      }
    }
  }
}
