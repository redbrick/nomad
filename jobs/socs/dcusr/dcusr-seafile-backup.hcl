job "dcusr-seafile-backup" {
  datacenters = ["aperture"]
  type        = "batch"

  meta {
    target_job   = "dcusr-seafile"
    target_group = "seafile"
    target_task  = "db"
    backup_dir   = "/storage/backups/nomad/dcusr-seafile"
    retain_days  = "3"
  }

  periodic {
    crons            = ["45 */3 * * *"]
    time_zone        = "Europe/Dublin"
    prohibit_overlap = true
  }

  group "db-backup" {
    count = 1

    # Fail fast: no retry overlapping the next run.
    restart {
      attempts = 0
      mode     = "fail"
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }

    task "mariadb-dump" {
      driver = "raw_exec"

      config {
        command = "/bin/bash"
        args    = ["${NOMAD_TASK_DIR}/backup.sh"]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/backup.env"
        env         = true
        data        = <<EOH
DISCORD_WEBHOOK={{ key "socs/dcusr/postgres/webhook/discord" }}
EOH
      }

      template {
        destination = "${NOMAD_TASK_DIR}/backup.sh"
        perms       = "0755"
        data        = <<EOH
#!/bin/bash
set -euo pipefail

job_name="$${NOMAD_JOB_NAME%%/*}"
backup_dir="$${NOMAD_META_backup_dir}"
file="$${backup_dir}/mariadb-seafile-$(TZ=Europe/Dublin date +%Y-%m-%d_%H-%M-%S).sql.gz"
# Scratch file in target alloc dir.
remote="seafile-backup.sql.gz"
alloc_id=""

fail() {
  echo "Backup FAILED: $1" >&2
  rm -f "$${file}" "$${file}.partial"
  [ -n "$${alloc_id}" ] && nomad alloc exec -task "$${NOMAD_META_target_task}" "$${alloc_id}" \
    rm -f "/alloc/data/$${remote}" "/alloc/data/$${remote}.partial" >/dev/null 2>&1 || true
  curl -sS -H "Content-Type: application/json" -d \
    '{"content": "<@&585512338728419341> `MariaDB` backup for **'"$${job_name}"'** has just **FAILED**\nReason: '"$1"'\nFile name: `'"$${file}"'`\nDate: `'"$(TZ=Europe/Dublin date)"'`\nTurn off this script with `nomad job stop '"$${job_name}"'` \n\n## Remember to restart this backup job when fixed!!!"}' \
    "$${DISCORD_WEBHOOK}" || true
  exit 1
}
trap 'fail "unexpected error on line $${LINENO}"' ERR

mkdir -p "$${backup_dir}"

alloc_id=$(nomad job allocs -json "$${NOMAD_META_target_job}" \
  | jq -r --arg g "$${NOMAD_META_target_group}" \
      '[.[] | select(.TaskGroup == $g and .ClientStatus == "running")][0].ID // empty')
[ -n "$${alloc_id}" ] || fail "no running $${NOMAD_META_target_group} allocation in $${NOMAD_META_target_job}"

# DB port not exposed: dump to alloc dir, fetch via `alloc fs` (exec truncates), verify sha256.
remote_sum=$(nomad alloc exec -task "$${NOMAD_META_target_task}" "$${alloc_id}" bash -c '
  set -euo pipefail
  dump=$(command -v mariadb-dump || command -v mysqldump)
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" "$dump" -uroot --all-databases --single-transaction \
    --quick --routines --events --triggers | gzip > "/alloc/data/'"$${remote}"'.partial"
  mv "/alloc/data/'"$${remote}"'.partial" "/alloc/data/'"$${remote}"'"
  sha256sum "/alloc/data/'"$${remote}"'" | cut -d" " -f1
' | tr -d '\r\n') || fail "mariadb-dump exited non-zero"
[ -n "$${remote_sum}" ] || fail "dump produced no checksum"

nomad alloc fs "$${alloc_id}" "alloc/data/$${remote}" > "$${file}.partial" || fail "nomad alloc fs failed"
nomad alloc exec -task "$${NOMAD_META_target_task}" "$${alloc_id}" rm -f "/alloc/data/$${remote}" || true

[ "$(sha256sum "$${file}.partial" | cut -d' ' -f1)" = "$${remote_sum}" ] || fail "checksum mismatch after transfer"
gzip -t "$${file}.partial" || fail "gzip integrity check failed"
zcat "$${file}.partial" | tail -n 1 | grep -q "Dump completed" || fail "dump has no completion marker"
mv "$${file}.partial" "$${file}"

find "$${backup_dir}" -maxdepth 1 -name 'mariadb-seafile-*.sql.gz' -mtime "+$${NOMAD_META_retain_days}" -delete

echo "Backup successful: $${file} ($(stat -c %s "$${file}") bytes)"
EOH
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
