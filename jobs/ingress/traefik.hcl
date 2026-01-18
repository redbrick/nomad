job "traefik" {
  datacenters = ["aperture"]
  node_pool   = "default"
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
      # port "ssh" {
      #   static = 22
      # }
      port "voice-tcp" {
        static = 4502
      }
      port "voice-udp" {
        static = 4503
      }
    }

    service {
      name     = "traefik-http"
      provider = "nomad"
      port     = "admin"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"
      config {
        image        = "traefik:v3"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          # "/storage/nomad/traefik/acme/acme.json:/acme.json",
          # "/storage/nomad/traefik/acme/acme-dns.json:/acme-dns.json",
          # "/storage/nomad/traefik/access.log:/access.log",
          "/storage/nomad/traefik/certs/certificates:/local/certs:ro",
        ]
      }

      template {
        destination = "local/traefik.toml"
        change_mode = "restart"
        data        = <<EOF
[entryPoints]
  [entryPoints.web]
  address = ":80"
  [entryPoints.web.http.redirections.entryPoint]
    to = "websecure"
    scheme = "https"

  [entryPoints.websecure]
    address = ":443"
    asDefault = true
    [entryPoints.websecure.forwardedHeaders]
      trustedIPs = ["127.0.0.1/32", "10.10.0.0/16", "136.206.16.0/24"]

  [entryPoints.traefik]
  address = ":8080"

  # [entryPoints.ssh]
  # address = ":22"

  [entryPoints.voice-tcp]
  address = ":4502"

  [entryPoints.voice-udp]
    address = ":4503/udp"
    [entryPoints.voice-udp.udp]
      timeout = "15s" # this will help reduce random dropouts in audio https://github.com/mumble-voip/mumble/issues/3550#issuecomment-441495977

[tls.options]
  [tls.options.default]
    minVersion = "VersionTLS12"
    cipherSuites = [
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
      "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
      "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256",
      "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256"
    ]

[api]
    dashboard = true
    insecure  = true

[ping]

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false

    [providers.consulCatalog.endpoint]
      address = "127.0.0.1:8500"
      scheme  = "http"

# Enable the file provider for dynamic configuration.
[providers.file]
  directory = "/local"
  watch     = true

#[providers.nomad]
#  [providers.nomad.endpoint]
#    address = "127.0.0.1:4646"
#    scheme = "http"

[tracing]

[accessLog]
  filePath = "/dev/stderr"
EOF
      }
      template {
        destination = "local/dynamic.toml"
        change_mode = "noop"
        data        = <<EOF
[http]

[http.middlewares]

[http.middlewares.https-redirect.redirectScheme]
  scheme = "https"
  permanent = true

# handle redirects for short links
# NOTE: this is a consul template, add entries via consul kv
# create the middlewares with replacements for each redirect
{{ range $pair := tree "redirect/redbrick" }}
  [http.middlewares.redirect-{{ trimPrefix "redirect/redbrick/" $pair.Key }}.redirectRegex]
    regex = ".*" # match everything - hosts are handled by the router
    replacement = "{{ $pair.Value }}"
    permanent = true
{{- end }}

[http.routers]

# ACME Challenge Router
[http.routers.acme-http-challenge]
  rule = "PathPrefix(`/.well-known/acme-challenge/`)"
  entryPoints = ["web"]
  service = "acme-challenge-solver"
  priority = 10000

# Global HTTPS Redirect
[http.routers.https-redirect]
  rule = "HostRegexp(`{host:.+}`)"
  entryPoints = ["web"]
  middlewares = ["https-redirect"]
  service = "dummy-service"
  priority = 1

[http.routers.webtree]
  rule = "HostRegexp(`^([a-z0-9_-]+)\\.redbrick\\.dcu\\.ie$`) || ((Host(`redbrick.dcu.ie`) || Host(`www.redbrick.dcu.ie`)) && PathPrefix(`/~`))"
  entryPoints = ["websecure"]
  priority = 10
  service = "webtree@consulcatalog"
  [http.routers.webtree.tls]

# create routers with middlewares for each redirect
{{ range $pair := tree "redirect/redbrick" }}
  [http.routers.{{ trimPrefix "redirect/redbrick/" $pair.Key }}-redirect]
    rule = "Host(`{{ trimPrefix "redirect/redbrick/" $pair.Key }}.redbrick.dcu.ie`)"
    entryPoints = ["web", "websecure"]
    middlewares = ["redirect-{{ trimPrefix "redirect/redbrick/" $pair.Key }}"]
    service = "dummy-service" # all routers need a service, this isn't used
    [http.routers.{{ trimPrefix "redirect/redbrick/" $pair.Key }}-redirect.tls]
{{- end }}

# Dynamic webtree domains
{{ $i := 0 -}}
{{- range $pair := tree "webtree/domains" -}}
  {{- $i = add $i 1 -}}

  [http.routers.webtree-domain-{{ $i }}]
    rule = "Host(`{{ $pair.Key }}`)"
    entryPoints = ["web", "websecure"]
    service = "webtree@consulcatalog"
    priority = 20
    [http.routers.webtree-domain-{{ $i }}.tls]

{{ end -}}

[http.services]

  [http.services.acme-challenge-solver.loadBalancer]
    [[http.services.acme-challenge-solver.loadBalancer.servers]]
      url = "http://acme-challenge-solver.service.consul:8888"

  [http.services.dummy-service.loadBalancer]
    [[http.services.dummy-service.loadBalancer.servers]]
      url = "http://127.0.0.1" # Dummy service - not used
EOF
      }
      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
