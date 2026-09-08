job "traefik" {
  datacenters = ["aperture"]
  type        = "system"

  group "traefik" {
    network {
      port "http" {
        static = 80
      }

      port "https" {
        static = 443
      }

      port "admin" {
        static = 8080
      }

      port "voice-tcp" {
        static = 4502
      }

      port "voice-udp" {
        static = 4503
      }

      port "matrix" {
        static = 8448
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

      port "palworld-game" {
        static = 8211
      }

      port "palworld-query" {
        static = 27015
      }
    }

    service {
      name     = "traefik-http"
      provider = "nomad"
      port     = "admin"

      check {
        name     = "traefik-ping"
        type     = "http"
        path     = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3.3"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml:ro",

          # Shared dynamic config directory.
          #
          # The ACME extractor writes:
          #   /storage/nomad/traefik/dynamic/90-acme-extracted-certs.toml
          #
          # Nomad overlays this job's generated config as:
          #   /dynamic/10-generated.toml
          #
          # Keeping both files directly under /dynamic avoids relying on
          # Traefik watching subdirectories.
          "/storage/nomad/traefik/dynamic:/dynamic",
          "local/dynamic-generated.toml:/dynamic/10-generated.toml:ro",

          # PEM certs extracted from the ACME renewer.
          "/storage/nomad/traefik/certs:/certs:ro",

          "/storage/nomad/traefik/access.log:/access.log",
        ]
      }

      template {
        destination = "local/traefik.toml"
        change_mode = "restart"
        data        = <<EOF
# ---------------------------------------------------------------------------
# Static Traefik config.
# ---------------------------------------------------------------------------
# Static config is intentionally kept boring and explicit.
# Dynamic routers/services/TLS certificates live in /dynamic/*.toml.
# ---------------------------------------------------------------------------

[entryPoints]
  [entryPoints.web]
    address = ":80"

    [entryPoints.web.http.redirections.entryPoint]
      to = "websecure"
      scheme = "https"
      permanent = true
      priority = 9000

  [entryPoints.websecure]
    address = ":443"
    asDefault = true

    [entryPoints.websecure.http.tls]

    [entryPoints.websecure.forwardedHeaders]
      trustedIPs = [
        "127.0.0.1/32",
        "10.10.0.0/16",
        "136.206.16.0/24",
      ]

  [entryPoints.traefik]
    address = ":8080"

  [entryPoints.voice-tcp]
    address = ":4502"

  [entryPoints.voice-udp]
    address = ":4503/udp"

    [entryPoints.voice-udp.udp]
      timeout = "15s" # this will help reduce random dropouts in audio https://github.com/mumble-voip/mumble/issues/3550#issuecomment-441495977

  [entryPoints.matrix]
    address = ":8448"

  [entryPoints.smtp]
    address = "136.206.16.50:25"

  [entryPoints.submissions]
    address = "136.206.16.50:465"

  [entryPoints.submission]
    address = "136.206.16.50:587"

  [entryPoints.imap]
    address = "136.206.16.50:143"

  [entryPoints.imaps]
    address = "136.206.16.50:993"

  [entryPoints.pop3]
    address = "136.206.16.50:110"

  [entryPoints.pop3s]
    address = "136.206.16.50:995"

  [entryPoints.managesieve]
    address = "136.206.16.50:4190"
  
  [entryPoints.palworld-game]
    address = "136.206.16.50:8211/udp"
    [entryPoints.palworld-game.udp]
      timeout = "30s"

  [entryPoints.palworld-query]
    address = "136.206.16.50:27015/udp"
    [entryPoints.palworld-query.udp]
      timeout = "30s"


[tls.options]
  [tls.options.default]
    minVersion = "VersionTLS12"
    cipherSuites = [
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
      "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256",
    ]

[api]
  dashboard = true
  insecure  = true

[ping]
  entryPoint = "traefik"

[providers.consulCatalog]
  prefix           = "traefik"
  exposedByDefault = false

  [providers.consulCatalog.endpoint]
    address = "127.0.0.1:8500"
    scheme  = "http"

[providers.file]
  directory = "/dynamic"
  watch     = true

[tracing]

[accessLog]
  filePath = "/access.log"

[log]
  level = "INFO"
EOF
      }

      template {
        destination = "local/dynamic-generated.toml"
        change_mode = "restart"
        data        = <<EOF
# ---------------------------------------------------------------------------
# Dynamic Traefik config generated by Nomad/Consul Template.
# ---------------------------------------------------------------------------
# This file is mounted into the container as:
#   /dynamic/10-generated.toml
#
# ACME-extracted certs are written separately by traefik-acme-renewer as:
#   /dynamic/90-acme-extracted-certs.toml
# ---------------------------------------------------------------------------

[http]

# ---------------------------------------------------------------------------
# HTTP middlewares
# ---------------------------------------------------------------------------

[http.middlewares]

  [http.middlewares.redirect-to-https.redirectScheme]
    scheme = "https"
    permanent = true

# Short-link redirects.
# Add entries in Consul KV under:
#   redirect/redbrick/<subdomain>
#
# Example:
#   redirect/redbrick/wiki = https://wiki.redbrick.dcu.ie/
 # --- Short-link redirects for redbrick.dcu.ie ---
{{ range $pair := tree "redirect/redbrick" }}
{{ $name := trimPrefix "redirect/redbrick/" $pair.Key }}
  [http.middlewares.redirect-{{ $name }}.redirectRegex]
    regex = ".*"
    replacement = "{{ $pair.Value }}"
    permanent = true

{{ end }}
      
 # --- Short-link redirects for rb.dcu.ie ---
{{ range $pair := tree "redirect/rb" }}
{{ $name := trimPrefix "redirect/rb/" $pair.Key }}
  [http.middlewares.redirect-rb-{{ $name }}.redirectRegex]
    regex = ".*"
    replacement = "{{ $pair.Value }}"
    permanent = true
{{ end }}

# ---------------------------------------------------------------------------
# HTTP routers
# ---------------------------------------------------------------------------

[http.routers]

# HTTP-01 ACME challenge router.
# Public traffic reaches whichever Traefik owns the Keepalived VIP.
# That Traefik forwards the challenge to the active ACME renewer via Consul.
[http.routers.acme-http01]
  rule = "PathPrefix(`/.well-known/acme-challenge/`)"
  entryPoints = ["web"]
  service = "traefik-acme-renewer"
  priority = 10000

[http.routers.webtree]
  rule = "HostRegexp(`^([a-z0-9_-]+)\\.redbrick\\.dcu\\.ie$`) || ((Host(`redbrick.dcu.ie`) || Host(`www.redbrick.dcu.ie`)) && PathPrefix(`/~`))"
  entryPoints = ["websecure"]
  priority = 10
  service = "webtree@consulcatalog"

  [http.routers.webtree.tls]

# --- redbrick.dcu.ie short-link redirect routers ---
{{ range $pair := tree "redirect/redbrick" }}
{{ $name := trimPrefix "redirect/redbrick/" $pair.Key }}
  [http.routers.{{ $name }}-redirect]
    rule = "Host(`{{ $name }}.redbrick.dcu.ie`)"
    entryPoints = ["web", "websecure"]
    middlewares = ["redirect-{{ $name }}"]
    service = "dummy-service"
    priority = 50

    [http.routers.{{ $name }}-redirect.tls]

{{ end }}

# --- rb.dcu.ie short-link redirect routers ---
{{ range $pair := tree "redirect/rb" }}
{{ $name := trimPrefix "redirect/rb/" $pair.Key }}
  [http.routers.{{ $name }}-rb-redirect]
    rule = "Host(`{{ $name }}.rb.dcu.ie`)"
    entryPoints = ["web", "websecure"]
    middlewares = ["redirect-rb-{{ $name }}"]
    service = "dummy-service"
    priority = 50

    [http.routers.{{ $name }}-rb-redirect.tls]

{{ end }}


# Default TLS router.
# This exists so Traefik can present an extracted cert for known Redbrick zones
# even when no higher-priority router has matched.
[http.routers.tls-default]
  rule = "HostRegexp(`{any:.+}.redbrick.dcu.ie`) || HostRegexp(`{any:.+}.rb.dcu.ie`) || HostRegexp(`{any:.+}.redbrick.ie`)"
  entryPoints = ["websecure"]
  service = "dummy-service"
  priority = -1

  [http.routers.tls-default.tls]

# Extra webtree domains from Consul KV.
{{ $i := 0 -}}
{{- range $pair := tree "webtree/domains" -}}
  {{- $i = add $i 1 }}

[http.routers.webtree-domain-{{ $i }}]
  rule = "Host(`{{ $pair.Key }}`)"
  entryPoints = ["websecure"]
  service = "webtree@consulcatalog"
  priority = 20

  [http.routers.webtree-domain-{{ $i }}.tls]

{{ end }}

# ---------------------------------------------------------------------------
# HTTP services
# ---------------------------------------------------------------------------

[http.services]

  [http.services.traefik-acme-renewer.loadBalancer]
    passHostHeader = true

{{ range service "traefik-acme-renewer" }}
    [[http.services.traefik-acme-renewer.loadBalancer.servers]]
      url = "http://{{ .Address }}:{{ .Port }}"
{{ end }}

  [http.services.dummy-service.loadBalancer]

    [[http.services.dummy-service.loadBalancer.servers]]
      url = "http://127.0.0.1"

# ---------------------------------------------------------------------------
# TCP routers
# ---------------------------------------------------------------------------

[tcp]

[tcp.routers]

  [tcp.routers.mail-smtp]
    entryPoints = ["smtp"]
    rule = "HostSNI(`*`)"
    service = "mail-smtp"

  [tcp.routers.mail-submissions]
    entryPoints = ["submissions"]
    rule = "HostSNI(`*`)"
    service = "mail-submissions"

  [tcp.routers.mail-submissions.tls]
    passthrough = true

  [tcp.routers.mail-submission]
    entryPoints = ["submission"]
    rule = "HostSNI(`*`)"
    service = "mail-submission"

  [tcp.routers.mail-imap]
    entryPoints = ["imap"]
    rule = "HostSNI(`*`)"
    service = "mail-imap"

  [tcp.routers.mail-imaps]
    entryPoints = ["imaps"]
    rule = "HostSNI(`*`)"
    service = "mail-imaps"

  [tcp.routers.mail-imaps.tls]
    passthrough = true

  [tcp.routers.mail-pop3]
    entryPoints = ["pop3"]
    rule = "HostSNI(`*`)"
    service = "mail-pop3"

  [tcp.routers.mail-pop3s]
    entryPoints = ["pop3s"]
    rule = "HostSNI(`*`)"
    service = "mail-pop3s"

  [tcp.routers.mail-pop3s.tls]
    passthrough = true

  [tcp.routers.mail-managesieve]
    entryPoints = ["managesieve"]
    rule = "HostSNI(`*`)"
    service = "mail-managesieve"

# ---------------------------------------------------------------------------
# TCP services
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# TCP services
# ---------------------------------------------------------------------------

[tcp.services]

  [tcp.services.mail-smtp.loadBalancer]
    [tcp.services.mail-smtp.loadBalancer.proxyProtocol]
      version = 2

{{ range service "mailserver-smtp" }}
    [[tcp.services.mail-smtp.loadBalancer.servers]]
      address = "{{ .Address }}:{{ .Port }}"
{{ end }}

  [tcp.services.mail-submissions.loadBalancer]
    [tcp.services.mail-submissions.loadBalancer.proxyProtocol]
      version = 2

{{ range service "mailserver-submissions" }}
    [[tcp.services.mail-submissions.loadBalancer.servers]]
      address = "{{ .Address }}:{{ .Port }}"
{{ end }}

  [tcp.services.mail-submission.loadBalancer]
    [tcp.services.mail-submission.loadBalancer.proxyProtocol]
      version = 2

{{ range service "mailserver-submission" }}
    [[tcp.services.mail-submission.loadBalancer.servers]]
      address = "{{ .Address }}:{{ .Port }}"
{{ end }}

  [tcp.services.mail-imap.loadBalancer]
    [tcp.services.mail-imap.loadBalancer.proxyProtocol]
      version = 2

{{ range service "mailserver-imap" }}
    [[tcp.services.mail-imap.loadBalancer.servers]]
      address = "{{ .Address }}:{{ .Port }}"
{{ end }}

  [tcp.services.mail-imaps.loadBalancer]
    [tcp.services.mail-imaps.loadBalancer.proxyProtocol]
      version = 2

{{ range service "mailserver-imaps" }}
    [[tcp.services.mail-imaps.loadBalancer.servers]]
      address = "{{ .Address }}:{{ .Port }}"
{{ end }}

  [tcp.services.mail-pop3.loadBalancer]
    [tcp.services.mail-pop3.loadBalancer.proxyProtocol]
      version = 2

{{ range service "mailserver-pop3" }}
    [[tcp.services.mail-pop3.loadBalancer.servers]]
      address = "{{ .Address }}:{{ .Port }}"
{{ end }}

  [tcp.services.mail-pop3s.loadBalancer]
    [tcp.services.mail-pop3s.loadBalancer.proxyProtocol]
      version = 2

{{ range service "mailserver-pop3s" }}
    [[tcp.services.mail-pop3s.loadBalancer.servers]]
      address = "{{ .Address }}:{{ .Port }}"
{{ end }}

  [tcp.services.mail-managesieve.loadBalancer]
    [tcp.services.mail-managesieve.loadBalancer.proxyProtocol]
      version = 2

{{ range service "mailserver-managesieve" }}
    [[tcp.services.mail-managesieve.loadBalancer.servers]]
      address = "{{ .Address }}:{{ .Port }}"
{{ end }}
EOF
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
