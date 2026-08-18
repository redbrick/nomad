job "traefik-acme-renewer" {
  datacenters = ["aperture"]
  type        = "service"

  group "acme" {
    count = 1

    network {
      mode = "host"

      port "web" {
        static = 18080
      }

      port "websecure" {
        static = 18443
      }
    }

    service {
      name     = "traefik-acme-renewer"
      provider = "consul"
      port     = "web"

      tags = [
        "redbrick.acme.dns-zone=redbrick.dcu.ie",
        "redbrick.acme.dns-zone=rb.dcu.ie",
      ]

      check {
        name     = "traefik-acme-renewer-ping"
        type     = "http"
        path     = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "acme-config-generator" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image        = "python:3.12-alpine"
        network_mode = "host"

        volumes = [
          "/storage/nomad/traefik/acme-dynamic:/dynamic",
        ]

        entrypoint = ["/bin/sh", "-lc"]

        args = [<<EOS
set -eu

cat > /tmp/generate-acme-config.py <<'PY'
import hashlib
import json
import os
import re
import time
import urllib.error
import urllib.request

CONSUL_HTTP_ADDR = os.environ.get("CONSUL_HTTP_ADDR", "http://127.0.0.1:8500")
OUTPUT_FILE = "/dynamic/dynamic-acme.toml"
INTERVAL_SECONDS = int(os.environ.get("ACME_CONFIG_INTERVAL_SECONDS", "60"))

HTTP_TAG_PREFIX = "redbrick.acme.http-domain="
DNS_TAG_PREFIX = "redbrick.acme.dns-zone="

SUPPORTED_DNS_ZONES = {
    "redbrick.dcu.ie",
    "rb.dcu.ie",
}

DOMAIN_RE = re.compile(r"^(?=.{1,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$")
WILDCARD_RE = re.compile(r"^\*\.(?=.{1,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$")

TRAEFIK_ROUTER_RULE_RE = re.compile(
    r"^traefik\.http\.routers\.[^.]+\.rule=(.*)$"
)

TRAEFIK_TLS_DOMAIN_MAIN_RE = re.compile(
    r"^traefik\.http\.routers\.[^.]+\.tls\.domains\[[0-9]+\]\.main=(.*)$"
)

TRAEFIK_TLS_DOMAIN_SANS_RE = re.compile(
    r"^traefik\.http\.routers\.[^.]+\.tls\.domains\[[0-9]+\]\.sans=(.*)$"
)

HOST_CALL_RE = re.compile(r"Host\(([^)]*)\)")


def fetch_json(path):
    url = CONSUL_HTTP_ADDR.rstrip("/") + path

    with urllib.request.urlopen(url, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def normalise_domain(value):
    value = value.strip().lower().rstrip(".")
    return value


def split_values(value):
    return [normalise_domain(item) for item in value.split(",") if item.strip()]


def valid_http_domain(domain):
    if "*" in domain:
        return False

    if "$" in domain or "{" in domain or "}" in domain:
        return False

    return bool(DOMAIN_RE.match(domain))


def valid_dns_zone(zone):
    if "*" in zone:
        return False

    if "$" in zone or "{" in zone or "}" in zone:
        return False

    return bool(DOMAIN_RE.match(zone))


def valid_wildcard_domain(domain):
    if "$" in domain or "{" in domain or "}" in domain:
        return False

    return bool(WILDCARD_RE.match(domain))


def router_name(prefix, value):
    digest = hashlib.sha1(value.encode("utf-8")).hexdigest()[:12]
    safe = re.sub(r"[^a-z0-9-]+", "-", value.lower()).strip("-")

    if len(safe) > 40:
        safe = safe[:40].strip("-")

    return f"{prefix}-{safe}-{digest}"


def strip_traefik_arg(value):
    value = value.strip()

    if value.startswith("`") and value.endswith("`"):
        value = value[1:-1]
    elif value.startswith("'") and value.endswith("'"):
        value = value[1:-1]
    elif value.startswith('"') and value.endswith('"'):
        value = value[1:-1]

    return normalise_domain(value)


def domains_from_host_rule(rule):
    domains = []

    for host_call in HOST_CALL_RE.finditer(rule):
        args = host_call.group(1)

        for item in args.split(","):
            domain = strip_traefik_arg(item)

            if valid_http_domain(domain):
                domains.append(domain)
            elif domain:
                print(f"Skipping invalid Traefik Host() domain: {domain}", flush=True)

    return domains


def http_domains_from_traefik_tls_value(value):
    domains = []

    for domain in split_values(value):
        if valid_http_domain(domain):
            domains.append(domain)

    return domains


def dns_zone_for_domain(domain, dns_zones):
    for zone in dns_zones:
        if domain == zone or domain.endswith("." + zone):
            return zone

    return None


def discover_acme_intent():
    services = fetch_json("/v1/catalog/services")

    http_domains = set()
    dns_zones = set()

    for service_name, tags in services.items():
        if not isinstance(tags, list):
            continue

        for tag in tags:
            if not isinstance(tag, str):
                continue

            if tag.startswith(HTTP_TAG_PREFIX):
                raw_value = tag[len(HTTP_TAG_PREFIX):]

                for domain in split_values(raw_value):
                    if valid_http_domain(domain):
                        http_domains.add(domain)
                    else:
                        print(f"Skipping invalid HTTP ACME domain tag on {service_name}: {domain}", flush=True)

                continue

            if tag.startswith(DNS_TAG_PREFIX):
                raw_value = tag[len(DNS_TAG_PREFIX):]

                for zone in split_values(raw_value):
                    if valid_dns_zone(zone) and zone in SUPPORTED_DNS_ZONES:
                        dns_zones.add(zone)
                    elif valid_dns_zone(zone):
                        print(f"Skipping unsupported DNS ACME zone tag on {service_name}: {zone}", flush=True)
                    else:
                        print(f"Skipping invalid DNS ACME zone tag on {service_name}: {zone}", flush=True)

                continue

            rule_match = TRAEFIK_ROUTER_RULE_RE.match(tag)
            if rule_match:
                for domain in domains_from_host_rule(rule_match.group(1)):
                    http_domains.add(domain)

                continue

            tls_main_match = TRAEFIK_TLS_DOMAIN_MAIN_RE.match(tag)
            if tls_main_match:
                for domain in http_domains_from_traefik_tls_value(tls_main_match.group(1)):
                    http_domains.add(domain)

                continue

            tls_sans_match = TRAEFIK_TLS_DOMAIN_SANS_RE.match(tag)
            if tls_sans_match:
                for domain in split_values(tls_sans_match.group(1)):
                    if valid_http_domain(domain):
                        http_domains.add(domain)
                    elif valid_wildcard_domain(domain):
                        print(
                            f"Skipping wildcard Traefik TLS domain on {service_name}; "
                            f"HTTP-01 cannot issue wildcard certs: {domain}",
                            flush=True,
                        )
                    else:
                        print(f"Skipping invalid Traefik TLS SAN on {service_name}: {domain}", flush=True)

                continue

    http_domains = {
        domain
        for domain in http_domains
        if dns_zone_for_domain(domain, dns_zones) is None
    }

    return sorted(http_domains), sorted(dns_zones)


def render_config(http_domains, dns_zones):
    lines = [
        "# Generated by traefik-acme-renewer acme-config-generator.",
        "# Do not edit by hand.",
        "",
        "[http]",
        "",
        "[http.routers]",
        "",
    ]

    for zone in dns_zones:
        name = router_name("cert-dns", zone)

        lines.extend([
            f"  [http.routers.{name}]",
            f'    rule = "Host(`{zone}`)"',
            '    entryPoints = ["websecure"]',
            '    service = "noop"',
            "",
            f"    [http.routers.{name}.tls]",
            '      certResolver = "rb"',
            "",
            f"      [[http.routers.{name}.tls.domains]]",
            f'        main = "{zone}"',
            f'        sans = ["*.{zone}"]',
            "",
        ])

    for domain in http_domains:
        name = router_name("cert-http", domain)

        lines.extend([
            f"  [http.routers.{name}]",
            f'    rule = "Host(`{domain}`)"',
            '    entryPoints = ["websecure"]',
            '    service = "noop"',
            "",
            f"    [http.routers.{name}.tls]",
            '      certResolver = "lets-encrypt"',
            "",
        ])

    lines.extend([
        "[http.services]",
        "",
        "  [http.services.noop.loadBalancer]",
        "",
        "    [[http.services.noop.loadBalancer.servers]]",
        '      url = "http://127.0.0.1:9"',
        "",
    ])

    return "\n".join(lines)


def write_if_changed(content):
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    previous = None

    if os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE, "r") as f:
            previous = f.read()

    if previous == content + "\n":
        return False

    tmp = OUTPUT_FILE + ".tmp"

    with open(tmp, "w") as f:
        f.write(content)
        f.write("\n")

    os.replace(tmp, OUTPUT_FILE)

    return True


while True:
    try:
        http_domains, dns_zones = discover_acme_intent()
        content = render_config(http_domains, dns_zones)
        changed = write_if_changed(content)

        print(
            f"ACME config generated: {len(dns_zones)} DNS zone(s), "
            f"{len(http_domains)} HTTP domain(s), changed={changed}",
            flush=True,
        )

        if dns_zones:
            print("DNS-01 zones: " + ", ".join(dns_zones), flush=True)

        if http_domains:
            print("HTTP-01 domains: " + ", ".join(http_domains), flush=True)

    except urllib.error.URLError as e:
        print(f"Could not reach Consul at {CONSUL_HTTP_ADDR}: {e}", flush=True)

    except Exception as e:
        print(f"ACME config generation failed: {e}", flush=True)

    time.sleep(INTERVAL_SECONDS)
PY

python /tmp/generate-acme-config.py
EOS
        ]
      }

      env {
        CONSUL_HTTP_ADDR             = "http://127.0.0.1:8500"
        ACME_CONFIG_INTERVAL_SECONDS = "60"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    task "traefik-acme" {
      driver = "docker"

      config {
        image        = "traefik:v3.3"
        network_mode = "host"

        volumes = [
          "local/traefik-acme.toml:/etc/traefik/traefik.toml:ro",
          "/storage/nomad/traefik/acme-dynamic:/dynamic",
          "/storage/nomad/traefik/acme:/acme",
        ]

        args = [
          "--configFile=/etc/traefik/traefik.toml",
        ]
      }

      template {
        destination = "secrets/env"
        env         = true
        change_mode = "restart"

        data = <<EOF
RFC2136_TSIG_KEY=dnsupdate.redbrick.dcu.ie.
RFC2136_TSIG_SECRET={{ key "traefik/acme/dns/key" }}
RFC2136_TSIG_ALGORITHM=hmac-sha256.
RFC2136_NAMESERVER=136.206.16.31:53
EOF
      }

      template {
        destination = "local/traefik-acme.toml"
        change_mode = "restart"

        data = <<EOF
[entryPoints]
  [entryPoints.web]
    address = ":18080"

  [entryPoints.websecure]
    address = ":18443"

[ping]
  entryPoint = "web"

[providers.file]
  directory = "/dynamic"
  watch     = true

[certificatesResolvers]

  [certificatesResolvers.rb]
    [certificatesResolvers.rb.acme]
      email   = "elected-admins@redbrick.dcu.ie"
      storage = "/acme/acme-dns.json"

      [certificatesResolvers.rb.acme.dnsChallenge]
        provider  = "rfc2136"
        resolvers = ["1.1.1.1:53", "8.8.8.8:53"]

  [certificatesResolvers.rb.acme.dnsChallenge.propagation]
    delayBeforeChecks = "60s"
    disableANSChecks  = true

  [certificatesResolvers.lets-encrypt]
    [certificatesResolvers.lets-encrypt.acme]
      email   = "elected-admins@redbrick.dcu.ie"
      storage = "/acme/acme-http.json"

      [certificatesResolvers.lets-encrypt.acme.httpChallenge]
        entryPoint = "web"

[log]
  level = "INFO"
EOF
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    task "extract-acme" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image = "python:3.12-alpine"

        volumes = [
          "/storage/nomad/traefik:/traefik",
        ]

        entrypoint = ["/bin/sh", "-lc"]

        args = [<<EOS
set -eu

cat > /tmp/extract.py <<'PY'
import base64
import json
import os
import re
import time

ACME_FILES = [
    "/traefik/acme/acme-dns.json",
    "/traefik/acme/acme-http.json",
]

CERT_ROOT = "/traefik/certs"
DYNAMIC_DIR = "/traefik/dynamic"
TLS_FILE = os.path.join(DYNAMIC_DIR, "90-acme-extracted-certs.toml")

DEFAULT_CERT_ZONE = "redbrick.dcu.ie"


def safe_name(name):
    name = name.lower().strip()
    name = name.replace("*.", "wildcard.")
    return re.sub(r"[^a-z0-9._-]+", "_", name)


def normalise_sans(value):
    if value is None:
        return []

    if isinstance(value, list):
        return value

    return []


def decode_field(value):
    if not isinstance(value, str):
        raise ValueError("ACME field is not a string")

    return base64.b64decode(value)


def load_acme(path):
    if not os.path.exists(path):
        return []

    try:
        with open(path, "r") as f:
            data = json.load(f)

    except Exception as e:
        print(f"Could not load {path}: {e}", flush=True)
        return []

    all_certs = []

    for resolver_name, resolver_data in data.items():
        certs = resolver_data.get("Certificates") or []

        for cert in certs:
            domain = cert.get("domain") or cert.get("Domain") or {}
            main = domain.get("main") or domain.get("Main")
            sans = normalise_sans(domain.get("sans") or domain.get("SANs"))

            if not main:
                continue

            try:
                fullchain = decode_field(cert["certificate"])
                key = decode_field(cert["key"])

            except Exception as e:
                print(f"Could not decode certificate for {main}: {e}", flush=True)
                continue

            all_certs.append({
                "resolver": resolver_name,
                "main": main.lower().strip().rstrip("."),
                "sans": [item.lower().strip().rstrip(".") for item in sans],
                "fullchain": fullchain,
                "key": key,
            })

    return all_certs


def cert_output_dir(cert):
    main = cert["main"]
    sans = cert.get("sans") or []

    if main.startswith("*."):
        return main[2:]

    wildcard_sans = [item for item in sans if item.startswith("*.")]

    if wildcard_sans:
        return main

    return os.path.join("external", safe_name(main))


def write_cert(cert):
    rel_dir = cert_output_dir(cert)
    outdir = os.path.join(CERT_ROOT, rel_dir)

    os.makedirs(outdir, exist_ok=True)

    fullchain_path = os.path.join(outdir, "fullchain.pem")
    key_path = os.path.join(outdir, "privkey.pem")

    with open(fullchain_path, "wb") as f:
        f.write(cert["fullchain"])

    with open(key_path, "wb") as f:
        f.write(cert["key"])

    os.chmod(fullchain_path, 0o644)
    os.chmod(key_path, 0o600)

    return rel_dir


def extract_once():
    os.makedirs(CERT_ROOT, exist_ok=True)
    os.makedirs(DYNAMIC_DIR, exist_ok=True)

    cert_entries = []
    seen = set()

    for acme_path in ACME_FILES:
        for cert in load_acme(acme_path):
            sans_tuple = tuple(sorted(cert.get("sans") or []))
            dedupe_key = (cert["main"], sans_tuple)

            if dedupe_key in seen:
                continue

            seen.add(dedupe_key)

            rel_dir = write_cert(cert)

            if rel_dir not in cert_entries:
                cert_entries.append(rel_dir)

            print(f"Extracted {cert['main']} to /traefik/certs/{rel_dir}", flush=True)

    if not cert_entries:
        return False

    lines = [
        "# Generated from Traefik ACME stores. Do not edit by hand.",
        "",
    ]

    if DEFAULT_CERT_ZONE in cert_entries:
        lines.extend([
            "[tls.stores]",
            "  [tls.stores.default.defaultCertificate]",
            f'    certFile = "/certs/{DEFAULT_CERT_ZONE}/fullchain.pem"',
            f'    keyFile  = "/certs/{DEFAULT_CERT_ZONE}/privkey.pem"',
            "",
        ])

    for rel_dir in sorted(cert_entries):
        lines.extend([
            "[[tls.certificates]]",
            f'  certFile = "/certs/{rel_dir}/fullchain.pem"',
            f'  keyFile  = "/certs/{rel_dir}/privkey.pem"',
            "",
        ])

    tmp = TLS_FILE + ".tmp"

    with open(tmp, "w") as f:
        f.write("\n".join(lines))
        f.write("\n")

    os.replace(tmp, TLS_FILE)
    os.utime(TLS_FILE, None)

    return True


while True:
    try:
        if extract_once():
            print("ACME extraction complete; dynamic TLS file touched", flush=True)

    except Exception as e:
        print(f"Extraction failed: {e}", flush=True)

    time.sleep(300)
PY

python /tmp/extract.py
EOS
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
