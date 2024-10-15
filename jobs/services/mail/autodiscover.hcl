job "autodiscover" {
  datacenters = ["aperture"]

  type = "service"

  meta {
    tld  = "rb.dcu.ie"
    mail = "mail.rb.dcu.ie"
  }

  group "autodiscover" {
    count = 1

    network {
      port "http" {
        to = 8000
      }
    }

    service {
      name = "autodiscover"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.autodiscover.rule=Host(`autoconfig.${NOMAD_META_tld}`) || Host(`autodiscover.${NOMAD_META_tld}`)",
        "traefik.http.routers.autodiscover.entrypoints=web,websecure",
        "traefik.http.routers.autodiscover.tls.certresolver=lets-encrypt",
      ]
    }

    task "autodiscover" {
      driver = "docker"

      config {
        image = "monogramm/autodiscover-email-settings:latest"
        ports = ["http"]
      }

      template {
        data        = <<EOF
COMPANY_NAME=Redbrick
SUPPORT_URL=https://autodiscover.{{ env "NOMAD_META_tld" }}
DOMAIN={{ env "NOMAD_META_tld" }}
# IMAP configuration (host mandatory to enable)
IMAP_HOST={{ env "NOMAD_META_mail" }}
IMAP_PORT=993
IMAP_SOCKET=SSL
# POP configuration (host mandatory to enable)
POP_HOST={{ env "NOMAD_META_mail" }}
POP_PORT=995
POP_SOCKET=SSL
# SMTP configuration (host mandatory to enable)
SMTP_HOST={{ env "NOMAD_META_mail" }}
SMTP_PORT=587
SMTP_SOCKET=STARTTLS
# MobileSync/ActiveSync configuration (url mandatory to enable)
# MOBILESYNC_URL=https://sync.example.com
# MOBILESYNC_NAME=sync.example.com
# LDAP configuration (host mandatory to enable)
# LDAP_HOST=ldap.example.com
# LDAP_PORT=636
# LDAP_SOCKET=SSL
# LDAP_BASE=dc=ldap,dc=example,dc=com
# LDAP_USER_FIELD=uid
# LDAP_USER_BASE=ou=People,dc=ldap,dc=example,dc=com
# LDAP_SEARCH=(|(objectClass=PostfixBookMailAccount))
# Apple mobile config identifiers (identifier mandatory to enable)
# PROFILE_IDENTIFIER=com.example.autodiscover
# PROFILE_UUID=92943D26-CAB3-4086-897D-DC6C0D8B1E86
# MAIL_UUID=7A981A9E-D5D0-4EF8-87FE-39FD6A506FAC
# LDAP_UUID=6ECB6BA9-2208-4ABF-9E60-4E9F4CD7309E
EOF
        destination = "local/autodiscover.env"
        env         = true
      }
    }
  }
}
