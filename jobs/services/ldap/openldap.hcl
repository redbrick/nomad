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

    task "openldap" {
      driver = "docker"

      config {
        image = "bitnamilegacy/openldap:latest"
        ports = ["ldap", "ldaps"]


        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}/:/bitnami/openldap",
          "local/schemas/:/bitnami/openldap/schemas/",
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
LDAP_ALLOW_ANON_BINDING=no

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
# LDAP_ENABLE_ACCESSLOG=yes
#
# LDAP_ACCESSLOG_ADMIN_USERNAME={{ key "ldap/admin/username" }}
# LDAP_ACCESSLOG_ADMIN_PASSWORD={{ key "ldap/admin/password" }}
# LDAP_ACCESSLOG_DB=cn=accesslog
# LDAP_ACCESSLOG_LOGOPS=all
# LDAP_ACCESSLOG_LOGSUCCESS=TRUE
# LDAP_ACCESSLOG_LOGPURGE=30+00:00 3+00:00
# LDAP_ACCESSLOG_LOGOLD=(objectClass=*)
# LDAP_ACCESSLOG_LOGOLDATTR=objectClass
#
#
# PPolicy
# LDAP_CONFIGURE_PPOLICY=yes
# LDAP_PPOLICY_USE_LOCKOUT=yes
# LDAP_PPOLICY_HASH_CLEARTEXT=yes



EOH
        destination = "local/.env"
        env         = true
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
        data        = file("./ldifs/redbrick-structure.ldif")
        destination = "local/ldifs/redbrick-structure.ldif"
      }

      template {
        data        = file("./scripts/01-memberOf.sh")
        destination = "local/scripts/01-memberOf.sh"
      }

      # template {
      #   data        = file("./scripts/acls.sh")
      #   destination = "local/scripts/acls.sh"
      # }
    }


    task "lam" {
      driver = "docker"

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
