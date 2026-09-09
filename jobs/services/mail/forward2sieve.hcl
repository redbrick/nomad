job "forward2sieve" {
  datacenters = ["aperture"]
  type        = "batch"

  periodic {
    crons            = ["0 */3 * * * *"]
    prohibit_overlap = true
  }

  group "forward2sieve" {
    task "forward2sieve" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["local/forward2sieve.sh"]
      }

      template {
        destination = "local/forward2sieve.sh"
        data        = <<EOH
#!/bin/bash

DOMAIN="redbrick.dcu.ie"
MAIL_ROOT="/storage/nomad/mail/data/$DOMAIN"

for forward in /storage/home/member/?/*/.forward /home/committee/?/*/.forward; do
  [ -f "$forward" ] || continue

  user=$(basename $(dirname "$forward"))
  sieve_dir="$MAIL_ROOT/$user/home/sieve"
  sieve_file="$sieve_dir/forward.sieve"

  forwards=$(grep -v '^#' "$forward" | grep -v '^$' | tr -d '\r')

  if [ -z "$forwards" ]; then
    rm -f "$sieve_file" 2>/dev/null
    continue
  fi

  mkdir -p "$sieve_dir"

  cat > "$sieve_file" <<EOF
require ["copy"];

EOF

  if echo "$forwards" | grep -q '^\\'; then
    echo "$forwards" | while read line; do
      addr=$(echo "$line" | sed 's/^\\//' | tr -d ' ')
      [ -n "$addr" ] && echo "redirect :copy \"$addr\";" >> "$sieve_file"
    done
  else
    echo "$forwards" | while read line; do
      addr=$(echo "$line" | tr -d ' ')
      [ -n "$addr" ] && echo "redirect \"$addr\";" >> "$sieve_file"
    done
  fi

  chown --reference="$sieve_dir" "$sieve_file" 2>/dev/null
  chmod 644 "$sieve_file"
done
EOH
      }
    }
  }
}

