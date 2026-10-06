job "inspircd" {
  datacenters = ["aperture"]
  type        = "service"

  group "irc-server" {
    count = 1

    network {
      # TLS Port
      port "ircs" {
        static = 6697
      }
    }

    volume "inspircd-config" {
      type      = "local"
      read_only = false
    }

    task "inspircd" {
      driver = "docker"
      config {
        # Using a community variant that includes LDAP modules pre-compiled
        image = "ghcr.io/redbrick/inspircd-docker-ldap:latest"
        ports = ["ircs"]

        # Mount our generated configuration directory
        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/inspircd/conf",
          "local/config/inspircd.conf:/inspircd/conf/inspircd.conf",
          "local/config/ldap.conf:/inspircd/conf/ldap.conf",
          "local/config/rb.motd:/inspircd/conf/rb.motd",
          "local/config/inspircd.rules:/inspircd/conf/inspircd.rules",
        ]
      }

      template {
        data        = <<EOH
INSP_NET_SUFFIX=irc.redbrick.dcu.ie
INSP_NET_NAME=RedbrickNet
INSP_SERVER_NAME=irc.redbrick.dcu.ie
INSP_NET_DESC="Redbrick DCU Student Networking Society IRC"
INSP_ADMIN_NAME="Redbrick Sysadmins"
INSP_ADMIN_DESC="Overpowered nerds who run the IRC server"
INSP_ADMIN_EMAIL="elected-admins@redbrick.dcu.ie"

EOH
        destination = "local/config/inspircd.env"
        env         = true
      }


      # Inject InspIRCd core configuration
      template {
        data        = <<EOH
<server name="irc.redbrick.dcu.ie" description="Redbrick DCU Student Networking Society IRC" id="00R" network="RedbrickNet" >
<admin name="Redbrick System Administrators" email="elected-admins@redbrick.dcu.ie" >

<module name="ldap">
<module name="ldapauth" >
<module name="cloak" >
<module name="sha2">
<module name="cloak_sha256" >
<module name="alias" >

<alias text="MODE $nick +x" replace="USERHOST $nick" >

<log method="stderr"
     type="*"
     level="normal">

<cloak method="hmac-sha256"
       key="{{ key "inspircd/cloak/key" }}"
       prefix="redbrick/"
       suffix=".cloak" >

# Accept connections wrapped in PROXY Protocol v2 from Traefik
<bind address="0.0.0.0" 
      port="{{ env "NOMAD_PORT_ircs" }}" 
      type="clients" 
      proxyranges="10.0.0.0/8 127.0.0.1/32" >

<include file="/inspircd/conf/ldap.conf" >
<files motd="/inspircd/conf/rb.motd" rules="/inspircd/conf/inspircd.rules" >

# Traefik terminates the TLS externally, so incoming container traffic is plaintext
<connect allow="*" 
         timeout="60" 
         ssl="optional"
         useident="no"
         haproxy="yes"
         modes="+x" 
         config="redbrick_ldapauth" >
EOH
        destination = "local/config/inspircd.conf"
      }

      # Inject LDAP specific configuration
      template {
        data        = <<EOH
# Database definition for the LDAP connection
<database id="ldap_server"
          module="ldap"
          server="ldap://{{ range service "openldap-ldap" }}{{ .Address }}:{{ .Port }}{{ end }}"
          binddn="{{ key "inspircd/ldap/binddn" }}"
          bindauth="{{ key "inspircd/ldap/password" }}"
          timeout="5s" >

<ldapauth id="redbrick_ldapauth"
          dbid="ldap_server"
          baserdn="{{ key "inspircd/ldap/basedn" }}"
          attribute="uid"
          killreason="Access denied: Invalid LDAP credentials."
          field="nickname"
          verbose="yes" >
EOH
        destination = "local/config/ldap.conf"
      }

      template {
        data        = <<EOH
 _________________________
< Welcome to Redbrick IRC >
 -------------------------
   \
    \
        .--.
       |o_o |
       |:_/ |
      //   \ \
     (|     | )
    /'\_   _/`\
    \___)=(___/
EOH
        destination = "local/config/rb.motd"
      }

      template {
        data        = <<EOH
This is the InspIRCd rules file.

https://wiki.redbrick.dcu.ie/index.php/IRC#Chat_etiquette_and_channel_operators

1) Be respectful to other members.
2) Sending/Linking any harmful material such as viruses, IP grabbers or any harmful software results in an immediate and permanent ban.
3) No spamming
4) If you wish to make an announcement to the membership as a whole ask the permission of the committee first.
5) Try and post content in its relevant channels.
6) Do not dox or post any private information of any individual.
7) Listen to what the committee says at all times.
8) Do not post graphic images or any illegal content on the server.
9) No bots are allowed in channels shared with discord please use #bots
EOH
        destination = "local/config/inspircd.rules"
      }

      resources {
        cpu    = 300 # MHz
        memory = 256 # MB
      }

      service {
        name = "inspircd"
        port = "ircs"

        tags = [
          # "traefik.enable=true",
          # # "traefik.tcp.routers.irc-redbrick.rule=HostSNI(`irc.rb.dcu.ie`)",
          # "traefik.tcp.routers.irc-redbrick.entrypoints=websecure",
          # "traefik.tcp.routers.irc-redbrick.tls=true",
          # "traefik.tcp.services.irc-redbrick.loadbalancer.proxyprotocol.version=2"
        ]

        check {
          name     = "IRC Port Alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
