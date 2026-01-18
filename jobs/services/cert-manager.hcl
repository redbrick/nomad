# A really crude reimplementation of cert-manager (https://cert-manager.io/) using lego in Nomad.
job "cert-manager" {
  datacenters = ["aperture"]
  type        = "service"

  group "manager" {
    count = 1

    network {
      port "http" {
        static = 8888
      }
    }

    service {
      name = "acme-challenge-solver"
      port = "http"
    }

    task "server" {
      driver = "docker"
      config {
        image   = "python:3-alpine"
        volumes = ["/storage/nomad/traefik/www:/www"]
        command = "python"
        args    = ["-m", "http.server", "8888", "--directory", "/www"]
      }
      resources {
        cpu    = 500
        memory = 1024
      }
    }

    task "dns-certs" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image = "goacme/lego:v4"
        volumes = [
          "/storage/nomad/traefik/certs:/certs"
        ]
        entrypoint = ["/bin/sh", "-c"]
        args       = ["/local/dns-loop.sh"]
      }

      template {
        env         = true
        destination = "local/.env"
        data        = <<EOF
RFC2136_TSIG_KEY=dnsupdate.redbrick.dcu.ie.
RFC2136_TSIG_SECRET={{ key "traefik/acme/dns/key" }}
RFC2136_TSIG_ALGORITHM=hmac-sha256.
RFC2136_NAMESERVER=ns1.redbrick.dcu.ie:53
LEGO_EMAIL=elected-admins@redbrick.dcu.ie
EOF
      }

      template {
        perms       = "755"
        destination = "local/dns-loop.sh"
        data        = <<EOF
#!/bin/sh
set -e

manage_wildcards() {
  echo "=== Managing Wildcard Certificates via DNS ==="

  /lego --email $LEGO_EMAIL --dns rfc2136 --accept-tos \
    --domains "*.redbrick.dcu.ie" --domains "redbrick.dcu.ie" \
    --path /certs run || true

  /lego --email $LEGO_EMAIL --dns rfc2136 --accept-tos \
    --domains "*.redbrick.ie" --domains "redbrick.ie" \
    --path /certs run || true

  /lego --email $LEGO_EMAIL --dns rfc2136 --accept-tos \
    --domains "*.rb.dcu.ie" --domains "rb.dcu.ie" \
    --path /certs run || true

  /lego --email $LEGO_EMAIL --dns rfc2136 --accept-tos \
    --path /certs renew --days 30
}

manage_wildcards

while true; do
  sleep 43200
  manage_wildcards
done
EOF
      }
    }

    task "http-certs" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image = "goacme/lego:v4.14.0"
        volumes = [
          "/storage/nomad/traefik/certs:/certs",
          "/storage/nomad/traefik/www:/www"
        ]
        entrypoint = ["/bin/sh", "-c"]
        args       = ["while true; do /local/manage-http-certs.sh; sleep 600; done"]
      }

      env {
        LEGO_EMAIL = "elected-admins@redbrick.dcu.ie"
      }

      template {
        perms       = "755"
        destination = "local/manage-http-certs.sh"
        change_mode = "noop"
        data        = <<EOF
#!/bin/sh
set -e

echo "=== Checking for new HTTP domains ==="

# Nomad template interpolation extracts all domains from Consul
DOMAINS=""

# Extract from Consul Catalog service tags
{{ range services }}
  {{ range service .Name }}
    {{ range .Tags }}
      {{ if . | regexMatch "traefik\\.http\\.routers\\..*\\.rule.*Host" }}
        {{ $extracted := . | regexReplaceAll ".*Host[^`]*\\`([^`]+)\\`.*" "$1" }}
        {{ if not ($extracted | regexMatch "\\*") }}
DOMAINS="$DOMAINS {{ $extracted }}"
        {{ end }}
      {{ end }}
    {{ end }}
  {{ end }}
{{ end }}

# Extract from webtree domains in Consul KV
{{ range tree "webtree/domains" }}
DOMAINS="$DOMAINS {{ .Key }}"
{{ end }}

# Deduplicate
DOMAINS=$(echo $DOMAINS | tr ' ' '\n' | sort -u | tr '\n' ' ')

echo "Discovered domains: $DOMAINS"

for domain in $DOMAINS; do
  # Skip wildcards
  if echo "$domain" | grep -q "\*"; then
    continue
  fi

  # Skip redbrick subdomains (covered by wildcard)
  if echo "$domain" | grep -qE "\.redbrick\.(dcu\.ie|ie)$|\.rb\.dcu\.ie$"; then
    echo "Skipping $domain (covered by wildcard)"
    continue
  fi

  # Check if cert exists and is still valid (>30 days)
  if [ -f "/certs/certificates/$domain.crt" ]; then
    EXPIRY=$(openssl x509 -enddate -noout -in "/certs/certificates/$domain.crt" | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$EXPIRY" +%s 2>/dev/null || echo 0)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

    if [ $DAYS_LEFT -gt 30 ]; then
      echo "Cert for $domain is valid for $DAYS_LEFT days, skipping..."
      continue
    fi
  fi

  echo "Requesting cert for: $domain"

  /lego --email $LEGO_EMAIL \
    --http --http.webroot /www \
    --accept-tos \
    --domains "$domain" \
    --path /certs \
    run || echo "Failed to get cert for $domain"
done

# Renew all HTTP certs
echo "=== Checking renewals ==="
/lego --email $LEGO_EMAIL \
  --http --http.webroot /www \
  --path /certs \
  renew --days 30 || true

chmod -R 755 /certs
EOF
      }
    }
  }
}
