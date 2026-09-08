job "openldap" {
  datacenters = ["aperture"]
  type        = "service"

  meta {
    domain = "ldap.rb.dcu.ie"
  }

  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "glados"
  }

  group "openldap" {

    network {
      port "ldap" {
        to     = 389
        static = 389
      }

      port "ldaps" {
        to     = 636
        static = 636
      }

      port "http" {
        to = 80
      }
    }

    service {
      name = "openldap-http"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
        "traefik.http.routers.openldap.rule=Host(`${NOMAD_META_domain}`)",
        "traefik.http.routers.openldap.entrypoints=web,websecure",
        "traefik.http.routers.openldap.tls.certresolver=lets-encrypt"
      ]
    }

    service {
      name = "openldap-ldap"
      port = "ldap"
    }

    service {
      name = "openldap-ldaps"
      port = "ldaps"
    }

    task "acme-cert-extract" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "python:3-alpine"
        command = "python3"
        args = [
          "/local/extract-certs.py",
          "/traefik-certs",
          "/bitnami/openldap/certs",
          "/bitnami/certs"
        ]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/openldap/:/bitnami/openldap",
          "/storage/nomad/traefik/certs/rb.dcu.ie/:/traefik-certs:ro",
          "/storage/ca/ldap/:/bitnami/certs:rw",
        ]
      }

      resources {
        cpu    = 50
        memory = 64
      }

      template {
        data        = file("./scripts/extract-certs.py")
        destination = "local/extract-certs.py"
      }
    }

    task "openldap" {
      driver = "docker"

      config {
        image = "bitnamilegacy/openldap:latest"
        ports = ["ldap", "ldaps"]
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}/:/bitnami/openldap",
          "local/schemas/:/bitnami/openldap/schemas/",
          "local/docker-entrypoint-initdb.d/:/docker-entrypoint-initdb.d/",
          "local/ldifs/:/bitnami/openldap/ldifs/",
        ]
      }

      resources {
        cpu    = 300
        memory = 600
      }

      template {
        data        = <<EOH
# Basic LDAP Configuration
LDAP_ROOT="dc=redbrick,dc=dcu,dc=ie"
LDAP_ALLOW_ANON_BINDING=no

# Port Configuration
LDAP_PORT_NUMBER=389
LDAP_LDAPS_PORT_NUMBER=636

# Domain and Organization
LDAP_ORGANISATION=Redbrick
LDAP_DOMAIN={{ env "NOMAD_META_domain" }}

# Tree Structure
LDAP_SKIP_DEFAULT_TREE=yes

# Bootstrapped Structure
LDAP_CUSTOM_LDIF_DIR=/bitnami/openldap/ldifs
LDAP_USER_DN=ou=accounts,o=redbrick,dc=redbrick,dc=dcu,dc=ie
LDAP_GROUP_DN=ou=groups,o=redbrick,dc=redbrick,dc=dcu,dc=ie

# Security
LDAP_ENABLE_TLS=yes

# TLS Certificate Paths (explicit — Bitnami validation checks all three)
LDAP_TLS_CERT_FILE=/bitnami/openldap/certs/server.crt
LDAP_TLS_KEY_FILE=/bitnami/openldap/certs/server.key
LDAP_TLS_CA_FILE=/bitnami/openldap/certs/CA.crt

# Schemas
LDAP_ADD_SCHEMAS=yes
LDAP_EXTRA_SCHEMAS=cosine,inetorgperson
LDAP_CUSTOM_SCHEMA_DIR=/bitnami/openldap/schemas

# Logging
LDAP_LOGLEVEL=256

# Admin
LDAP_ADMIN_DN='cn={{ key "ldap/admin/username" }},dc=redbrick,dc=dcu,dc=ie'
LDAP_ADMIN_USERNAME={{ key "ldap/admin/username" }}
LDAP_ADMIN_PASSWORD={{ key "ldap/admin/password" }}

# Config Admin
LDAP_CONFIG_ADMIN_ENABLED=yes
LDAP_CONFIG_ADMIN_USERNAME={{ key "ldap/configadmin/username" }}
LDAP_CONFIG_ADMIN_PASSWORD={{ key "ldap/configadmin/password" }}

BITNAMI_DEBUG=true


# ====================================== MODULES ======================================
# Access Logging
LDAP_ENABLE_ACCESSLOG=yes
LDAP_ACCESSLOG_ADMIN_USERNAME={{ key "ldap/admin/username" }}
LDAP_ACCESSLOG_ADMIN_PASSWORD={{ key "ldap/admin/password" }}
LDAP_ACCESSLOG_DB=cn=accesslog
LDAP_ACCESSLOG_LOGOPS=all
LDAP_ACCESSLOG_LOGSUCCESS=TRUE
LDAP_ACCESSLOG_LOGPURGE=30+00:00 3+00:00
LDAP_ACCESSLOG_LOGOLD=(objectClass=*)
LDAP_ACCESSLOG_LOGOLDATTR=objectClass

# Policy
# LDAP_CONFIGURE_PPOLICY=no
# LDAP_PPOLICY_USE_LOCKOUT=no
# LDAP_PPOLICY_HASH_CLEARTEXT=no



EOH
        destination = "local/.env"
        env         = true
        change_mode = "restart"
      }


      template {
        data        = file("./schemas/03-rfc2307bis.ldif")
        destination = "local/schemas/03-rfc2307bis.ldif"
      }

      template {
        data        = file("./schemas/04-redbrick.ldif")
        destination = "local/schemas/04-redbrick.ldif"
      }

      template {
        data        = file("./ldifs/00-modules.ldif")
        destination = "local/docker-entrypoint-initdb.d/00-modules.ldif"
      }

      template {
        data        = file("./ldifs/01-memberOf.ldif")
        destination = "local/docker-entrypoint-initdb.d/01-memberOf.ldif"
      }

      template {
        data        = file("./scripts/apply-config.sh")
        destination = "local/docker-entrypoint-initdb.d/apply-config.sh"
      }
    }

    task "lam" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image = "ghcr.io/ldapaccountmanager/lam:stable"
        ports = ["http"]

      }

      resources {
        cpu    = 300
        memory = 300
      }

      template {
        data        = <<EOH
LAM_SKIP_PRECONFIGURE=false
LDAP_DOMAIN=redbrick.dcu.ie
LDAP_BASE_DN=dc=redbrick,dc=dcu,dc=ie
LDAP_USERS_DN=ou=accounts,o=redbrick,dc=redbrick,dc=dcu,dc=ie
LDAP_GROUPS_DN=ou=groups,o=redbrick,dc=redbrick,dc=dcu,dc=ie
LDAP_SERVER=ldap://{{ env "NOMAD_IP_ldap" }}:{{ env "NOMAD_HOST_PORT_ldap" }}

LDAP_USER=cn=admin,dc=redbrick,dc=dcu,dc=ie
LAM_LANG=en_US
LAM_PASSWORD={{ key "ldap/admin/password" }}

LAM_CONFIGURATION_DATABASE=files

# deactivate TLS certificate checks, activate for development only
LAM_DISABLE_TLS_CHECK=true

LDAP_ORGANISATION="Redbrick"
LDAP_ADMIN_PASSWORD={{ key "ldap/admin/password" }}
EOH
        destination = "local/.env"
        env         = true
      }
    }
  }
}