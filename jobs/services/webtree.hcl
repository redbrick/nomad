job "webtree" {
  datacenters = ["aperture"]
  type        = "service"

  group "webtree" {
    count = 3

    network {
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
        path     = "/404.html"
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
          "/storage/webtree:/var/www/html",
          "local/nginx.conf:/etc/nginx/nginx.conf:ro",
        ]
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
  server_tokens off;

  access_log /dev/stdout;
  error_log /dev/stderr error;

  charset utf-8;

  map $subdomain $first_letter {
    default "";
    ~^(.) $1;
  }

  server {
    listen 80;

    server_name ~^(?<subdomain>[a-z0-9-]+)\.redbrick\.dcu\.ie$;

    root /var/www/html/$first_letter/$subdomain;
    index index.php index.html index.htm;

    location / {
      try_files $uri $uri/ /index.php?$args =404;
    }

    error_page 400 401 403 404 500 502 503 504 /404.html;
    location = /404.html {
      root /var/www/html;
    }

    location ~ \.php$ {
      include fastcgi_params;
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
      fastcgi_index index.php;
      fastcgi_pass {{ env "NOMAD_HOST_ADDR_fpm" }};
    }

    location ~ /\.ht {
      deny all;
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
          "/storage/webtree:/var/www/html",
        ]
        command = "sh"
        args    = ["-c", "docker-php-ext-install mysqli && docker-php-ext-enable mysqli && php-fpm"]
      }

      resources {
        cpu    = 4000
        memory = 1200
      }
    }
  }
}
