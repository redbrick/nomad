job "traefik" {
  datacenters = ["aperture"]
  type        = "system"

  group "traefik" {
    network {
      port "http"{
        static = 80
      }
      port "https" {
        static = 443
      }
      port "admin"{
        static = 8080
      }
    }

    service {
      name = "traefik-http"
      provider = "nomad"
      port = "https"
    }

    task "traefik" {
      driver = "docker"
      config {
        image = "traefik"
        network_mode = "host"
        
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
        ]
      }

      template {
        data = <<EOF
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

#[providers.nomad]
#  [providers.nomad.endpoint]
#    address = "127.0.0.1:4646"
#    scheme = "http"

[certificatesResolvers.lets-encrypt.acme]
  email = "elected-admins@redbrick.dcu.ie"
  storage = "local/acme.json"
  [certificatesResolvers.lets-encrypt.acme.tlsChallenge]
EOF
        destination = "/local/traefik.toml"
      }
    }
  }
}
