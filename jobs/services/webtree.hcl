job "webtree" {
  datacenters = ["aperture"]
  type        = "service"

  group "webtree" {
    count = 3

    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
      port "fpm" {
        to = 9000
      }
    }

    service {
      name = "webtree"
      port = "http"

      check {
        type     = "http"
        path     = "/_health"
        interval = "10s"
        timeout  = "5s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.port=${NOMAD_PORT_http}",
      ]
    }

    task "webtree-nginx" {
      driver = "docker"
      config {
        image = "nginx:alpine"
        ports = ["http"]
        volumes = [
          "/storage/webtree:/webtree",
          "local/nginx.conf:/etc/nginx/nginx.conf:ro",
        ]
        group_add = [82, 10000] # www-data in alpine, RB member groups

      }

      resources {
        cpu    = 200
        memory = 500
      }

      template {
        destination = "local/nginx.conf"
        change_mode = "restart"
        data        = <<EOH
error_log /dev/stderr error;

events {
  worker_connections 1024;
}

http {
  include /etc/nginx/mime.types;
  default_type  text/html;
  server_tokens off;

  # Real IP Config
  set_real_ip_from 136.206.16.0/24;
  real_ip_header X-Forwarded-For;
  real_ip_recursive on;

  access_log /dev/stdout;
  error_log /dev/stderr error;
  charset utf-8;

  # Logic for extracting the first letter automatically from various variables
  map $subdomain $subdomain_first_letter {
      ~^(?P<first>.) $first;
  }

  map $tilde_user $tilde_first_letter {
    default "";
    ~^(.) $1;
  }

  # --- Subdomain Server (user.redbrick.dcu.ie) ---
  server {
    listen 80;
    server_name ~^(?<subdomain>[a-z0-9_-]+)\.redbrick\.dcu\.ie$;

    # Redirect broken links like user.rb.dcu.ie/~anyuser to www.rb.dcu.ie/~anyuser
    location ~ ^/~(?<tilde_user>[a-z0-9_-]+) {
      return 301 $scheme://www.redbrick.dcu.ie$request_uri;
    }

    root /webtree/$subdomain_first_letter/$subdomain;
    index index.html index.php index.htm index.shtml;
    ssi on;

    location / {
        try_files $uri $uri/ /index.php?$is_args$args =404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass {{ env "NOMAD_ADDR_fpm" }};
    }

    error_page 400 401 403 404 405 408 410 413 414 415 429 500 501 502 503 504 /404.html;
    location = /404.html { root /webtree; }

    location ~ /\.ht { deny all; }
  }

  # --- Main Server (redbrick.dcu.ie/~user) ---
  server {
    listen 80;
    server_name redbrick.dcu.ie www.redbrick.dcu.ie;

    root /webtree;

    ssi on;

    # /~user/path -> /<first>/<user>/path
    location ~ ^/~(?<tilde_user>[a-z0-9_-]+)(?<rest>/.*)?$ {
      rewrite ^ /$tilde_first_letter/$tilde_user$rest last;
    }

    # PHP to FPM
    location ~ \.php$ {
      try_files $uri =404;
      include fastcgi_params;
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
      fastcgi_param DOCUMENT_ROOT $document_root;
      fastcgi_index index.php;
      fastcgi_pass {{ env "NOMAD_ADDR_fpm" }};
    }

    # Handle rewritten tilde paths
    location ~ ^/(?<f_letter>[a-z0-9])/(?<u_name>[a-z0-9_-]+)(?<u_rest>/.*)?$ {
      index index.html index.php index.htm index.shtml;

      # Only redirect if it's a directory AND doesn't already end with /
      set $redirect_check "";
      if (-d $request_filename) {
        set $redirect_check "D";
      }
      if ($uri !~ "/$") {
        set $redirect_check "${redirect_check}N";
      }
      if ($redirect_check = "DN") {
        return 301 /~$u_name$u_rest/;
      }

      try_files $uri $uri/ =404;
  }

  location / { return 404; }

  error_page 400 401 403 404 405 408 410 413 414 415 429 500 501 502 503 504 /404.html;
  location = /404.html { root /webtree; }

  location ~ /\.ht { deny all; }
  }

  # --- server blocks for custom domains ---
  {{ range $pair := tree "webtree/domains" }}
  server {
    listen 80;
    server_name {{ $pair.Key }};

    root /webtree/{{ $pair.Value }};
    index index.html index.php index.htm index.shtml;

    ssi on;

    location / {
      try_files $uri $uri/ /index.php?$args =404;
    }

    location ~ \.php$ {
      include fastcgi_params;
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
      fastcgi_pass {{ env "NOMAD_HOST_ADDR_fpm" }};
    }

    error_page 400 401 403 404 405 408 410 413 414 415 429 500 501 502 503 504 /404.html;
    location = /404.html { root /webtree; }

    location ~ /\.ht { deny all; }
  }
  {{ end }}

  # --- Default catch-all server ---
  server {
    listen 80 default_server;
    server_name _;

    error_page 400 401 403 404 405 408 410 413 414 415 429 500 501 502 503 504 /404.html;
    location = /404.html { root /webtree; }

    location ~ /\.ht { deny all; }

    location = /_health {
      access_log off;
      add_header Content-Type text/plain;
      return 200 "ok\n";
    }
    location / {
      return 404;
    }
  }
}
EOH
      }
    }

    task "webtree-php" {
      driver = "docker"

      config {
        image = "php:8-fpm-alpine"
        ports = ["fpm"]
        volumes = [
          "/storage/webtree:/webtree",
          "local/php.ini:/usr/local/etc/php/conf.d/99-webtree.ini:ro",
        ]
        group_add = [10000] # RB member group
        command   = "sh"
        args      = ["-c", "docker-php-ext-install mysqli && docker-php-ext-enable mysqli && php-fpm"]
      }

      template {
        destination = "local/php.ini"
        change_mode = "restart"
        data        = <<EOH
; Mostly to improve performance and compatability with legacy webtree sites

expose_php = Off
default_charset = "UTF-8"
date.timezone = "Europe/Dublin"

output_buffering = 4096
implicit_flush = Off
precision = 14
serialize_precision = -1
zlib.output_compression = Off

variables_order = "GPCS"
request_order = "GP"

; allow old-style short tags
short_open_tag = On

; log errors, don't display them to users
display_errors = Off
display_startup_errors = Off
log_errors = On
error_reporting = E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED & ~E_STRICT

; resource limits
memory_limit = 1024M
max_execution_time = 30
max_input_time = 60

; uploads
file_uploads = On
upload_max_filesize = 32M
post_max_size = 32M
max_file_uploads = 20

mbstring.language = Neutral
mbstring.internal_encoding = UTF-8
mbstring.detect_order = auto
mbstring.func_overload = 0

; sessions
session.use_strict_mode = 0
session.cookie_httponly = 1
session.cookie_samesite = Lax

allow_url_fopen = On
allow_url_include = Off
cgi.fix_pathinfo = 0

; OPcache (performance go brrr)
opcache.enable = 1
opcache.enable_cli = 0
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 1
opcache.revalidate_freq = 2
EOH
      }

      resources {
        cpu    = 4000
        memory = 1200
      }
    }
  }
}
