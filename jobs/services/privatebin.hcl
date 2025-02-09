job "privatebin" {
  datacenters = ["aperture"]

  type = "service"

  group "privatebin" {
    count = 1

    network {
      port "http" {
        to = 8080
      }
      port "db" {
        to = 5432
      }
    }

    service {
      name = "privatebin"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.privatebin.rule=Host(`paste.redbrick.dcu.ie`) || Host(`paste.rb.dcu.ie`)",
        "traefik.http.routers.privatebin.entrypoints=web,websecure",
        "traefik.http.routers.privatebin.tls.certresolver=lets-encrypt",
      ]
    }

    task "privatebin" {
      driver = "docker"

      config {
        image = "privatebin/nginx-fpm-alpine:stable"
        ports = ["http"]

        volumes = [
          "local/conf.php:/srv/data/conf.php",
        ]
      }
      env {
        TZ          = "Europe/Dublin"
        PHP_TZ      = "Europe/Dublin"
        CONFIG_PATH = "/srv/data/"
      }

      template {
        destination = "local/conf.php"
        data        = <<EOH
[main]
name = "Redbrick PasteBin"

basepath = "https://paste.redbrick.dcu.ie/"

discussion = true

opendiscussion = false

password = true

fileupload = true

burnafterreadingselected = false

defaultformatter = "markdown"

; (optional) set a syntax highlighting theme, as found in css/prettify/
syntaxhighlightingtheme = "sons-of-obsidian"

; size limit per paste or comment in bytes, defaults to 10 Mebibytes
sizelimit = 10485760

; template to include, default is "bootstrap" (tpl/bootstrap.php)
template = "bootstrap-dark"

; (optional) info text to display
; use single, instead of double quotes for HTML attributes
;info = "More information on the <a href='https://privatebin.info/'>project page</a>."

; (optional) notice to display
; notice = "Note: Distro is a Goombean."

languageselection = false

languagedefault = "en"

; (optional) URL shortener address to offer after a new paste is created.
; It is suggested to only use this with self-hosted shorteners as this will leak
; the pastes encryption key.
urlshortener = "https://s.rb.dcu.ie/rest/v1/short-urls/shorten?apiKey={{ key "privatebin/shlink/api" }}&format=txt&longUrl="

qrcode = true
email = true

; Can be set to one these values:
; "none" / "identicon" (default) / "jdenticon" / "vizhash".
icon = "identicon"

; Content Security Policy headers allow a website to restrict what sources are
; allowed to be accessed in its context. You need to change this if you added
; custom scripts from third-party domains to your templates, e.g. tracking
; scripts or run your site behind certain DDoS-protection services.
; Check the documentation at https://content-security-policy.com/
; Notes:
; - If you use a bootstrap theme, you can remove the allow-popups from the
;   sandbox restrictions.
; - By default this disallows to load images from third-party servers, e.g. when
;   they are embedded in pastes. If you wish to allow that, you can adjust the
;   policy here. See https://github.com/PrivateBin/PrivateBin/wiki/FAQ#why-does-not-it-load-embedded-images
;   for details.
; - The 'unsafe-eval' is used in two cases; to check if the browser supports
;   async functions and display an error if not and for Chrome to enable
;   webassembly support (used for zlib compression). You can remove it if Chrome
;   doesn't need to be supported and old browsers don't need to be warned.
; cspheader = "default-src 'none'; base-uri 'self'; form-action 'none'; manifest-src 'self'; connect-src * blob:; script-src 'self' 'unsafe-eval'; style-src 'self'; font-src 'self'; frame-ancestors 'none'; img-src 'self' data: blob:; media-src blob:; object-src blob:; sandbox allow-same-origin allow-scripts allow-forms allow-popups allow-modals allow-downloads"

zerobincompatibility = false

httpwarning = true

compression = "zlib"

[expire]
; make sure the value exists in [expire_options]
default = "1week"

[expire_options]
5min = 300
10min = 600
1hour = 3600
1day = 86400
1week = 604800
2week = 1209600
; Well this is not *exactly* one month, it's 30 days:
1month = 2592000
1year = 31536000
never = 0

[formatter_options]
plaintext = "Plain Text"
markdown = "Markdown"
syntaxhighlighting = "Source Code"

[traffic]
; time limit between calls from the same IP address in seconds
; Set this to 0 to disable rate limiting.
limit = 10

; (optional) Set IPs addresses (v4 or v6) or subnets (CIDR) which are exempted
; from the rate-limit. Invalid IPs will be ignored. If multiple values are to
; be exempted, the list needs to be comma separated. Leave unset to disable
; exemptions.
; exempted = "1.2.3.4,10.10.10/24"

; (optional) If you want only some source IP addresses (v4 or v6) or subnets
; (CIDR) to be allowed to create pastes, set these here. Invalid IPs will be
; ignored. If multiple values are to be exempted, the list needs to be comma
; separated. Leave unset to allow anyone to create pastes.
; creators = "1.2.3.4,10.10.10/24"

; (optional) if your website runs behind a reverse proxy or load balancer,
; set the HTTP header containing the visitors IP address, i.e. X_FORWARDED_FOR
; header = "X_FORWARDED_FOR"

[purge]
; minimum time limit between two purgings of expired pastes, it is only
; triggered when pastes are created
; Set this to 0 to run a purge every time a paste is created.
limit = 300

; maximum amount of expired pastes to delete in one purge
; Set this to 0 to disable purging. Set it higher, if you are running a large
; site
batchsize = 10

[model]
class = Database
[model_options]
dsn = "pgsql:host={{ env "NOMAD_ADDR_db" }};dbname={{ key "privatebin/db/name" }}"
tbl = "{{ key "privatebin/db/name" }}"     ; table prefix
usr = "{{ key "privatebin/db/user" }}"
pwd = "{{ key "privatebin/db/password" }}"
opt[12] = true    ; PDO::ATTR_PERSISTENT ; use persistent connections - default
EOH
      }
    }

    task "db" {
      driver = "docker"

      config {
        image = "postgres:17-alpine"
        ports = ["db"]

        volumes = [
          "/storage/nomad/${NOMAD_JOB_NAME}/${NOMAD_TASK_NAME}:/var/lib/postgresql/data",
        ]
      }

      template {
        data        = <<EOH
POSTGRES_PASSWORD={{ key "privatebin/db/password" }}
POSTGRES_USER={{ key "privatebin/db/user" }}
POSTGRES_NAME={{ key "privatebin/db/name" }}
EOH
        destination = "local/db.env"
        env         = true
      }
    }
  }
}
