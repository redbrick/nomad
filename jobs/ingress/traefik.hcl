job "traefik" {
  datacenters = ["aperture"]
  node_pool   = "ingress"
  type        = "service"

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
      port "ssh" {
        static = 22
      }
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
      port     = "https"
    }

    task "traefik" {
      driver = "docker"
      config {
        image        = "traefik"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "/storage/nomad/traefik/acme/acme.json:/acme.json",
          "/storage/nomad/traefik/acme/acme-dns.json:/acme-dns.json",
          "/storage/nomad/traefik/access.log:/access.log",
        ]
      }

      template {
        destination = "local/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOF
RFC2136_TSIG_KEY=dnsupdate.redbrick.dcu.ie.
RFC2136_TSIG_SECRET={{ key "traefik/acme/dns/key" }}
RFC2136_TSIG_ALGORITHM=hmac-sha256.
RFC2136_NAMESERVER=ns1.redbrick.dcu.ie:53
EOF
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

  [entryPoints.traefik]
  address = ":8080"

  [entryPoints.ssh]
  address = ":22"

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

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false

    [providers.consulCatalog.endpoint]
      address = "127.0.0.1:8500"
      scheme  = "http"

# Enable the file provider for dynamic configuration.
[providers.file]
  filename = "/local/dynamic.toml"

#[providers.nomad]
#  [providers.nomad.endpoint]
#    address = "127.0.0.1:4646"
#    scheme = "http"

[certificatesResolvers.lets-encrypt.acme]
  email = "elected-admins@redbrick.dcu.ie"
  storage = "acme.json"
  [certificatesResolvers.lets-encrypt.acme.tlsChallenge]

[certificatesResolvers.rb.acme]
  email = "elected-admins@redbrick.dcu.ie"
  storage = "acme-dns.json"
  [certificatesResolvers.rb.acme.dnsChallenge]
    provider = "rfc2136"
    delayBeforeCheck = 60
        resolvers = "ns1.redbrick.dcu.ie:53,1.1.1.1:53,8.8.8.8:53"

[tracing]

[accessLog]
  filePath = "/access.log"
EOF
      }
      template {
        destination = "local/dynamic.toml"
        change_mode = "noop"
        data        = <<EOF
[http]

[http.middlewares]

# handle redirects for short links
# NOTE: this is a consul template, add entries via consul kv
# create the middlewares with replacements for each redirect
{{ range $pair := tree "redirect/redbrick" }}
  [http.middlewares.redirect-{{ trimPrefix "redirect/redbrick/" $pair.Key }}.redirectRegex]
    regex = ".*"  # match everything - hosts are handled by the router
    replacement = "{{ $pair.Value }}"
    permanent = true
{{- end }}

[http.routers]

# create routers with middlewares for each redirect
{{ range $pair := tree "redirect/redbrick" }}
  [http.routers.{{ trimPrefix "redirect/redbrick/" $pair.Key }}-redirect]
    rule = "Host(`{{ trimPrefix "redirect/redbrick/" $pair.Key }}.redbrick.dcu.ie`)"
    entryPoints = ["web", "websecure"]
    middlewares = ["redirect-{{ trimPrefix "redirect/redbrick/" $pair.Key }}"]
    service = "dummy-service"  # all routers need a service, this isn't used
    [http.routers.{{ trimPrefix "redirect/redbrick/" $pair.Key }}-redirect.tls]
{{- end }}

[http.routers.tls-default]
      rule = "HostRegexp(`{any:.+}.redbrick.dcu.ie`) || HostRegexp(`{any:.+}.rb.dcu.ie`) || HostRegexp(`{any:.+}.redbrick.ie`)"
      entryPoints = ["web", "websecure"]
      service = "dummy-service"
      priority = -1

      [http.routers.tls-default.tls]
        certResolver = "rb"

        [[http.routers.tls-default.tls.domains]]
          main = "redbrick.dcu.ie"
          sans = ["*.redbrick.dcu.ie"]

        [[http.routers.tls-default.tls.domains]]
          main = "rb.dcu.ie"
          sans = ["*.rb.dcu.ie"]

        [[http.routers.tls-default.tls.domains]]
          main = "redbrick.ie"
          sans = ["*.redbrick.ie"]


[http.services]
  [http.services.dummy-service.loadBalancer]
    [[http.services.dummy-service.loadBalancer.servers]]
      url = "http://127.0.0.1"  # Dummy service - not used
EOF
      }
    }
  }
}
