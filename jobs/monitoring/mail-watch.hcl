job "mail-watch" {
  datacenters = ["aperture"]
  type        = "service"

  group "watch" {
    count = 1

    task "watcher" {
      driver = "docker"

      config {
        image   = "python:3.12-alpine"
        command = "sh"
        args    = ["-lc", "pip install requests && python3 local/watch.py"]

        volumes = [
          "/storage/nomad/mail/logs/mail.log:/var/log/mail/mail.log:ro"
        ]
      }

      # Render the python + a .env file from templates, so we can pull the webhook URL from a key.
      template {
        destination = "local/watch.py"
        data        = <<EOT
#!/usr/bin/env python3
import os
import subprocess
import sys
import time
import json
import requests

LOG_PATH = "/var/log/mail/mail.log"
TOP_N = int(os.environ.get("TOP_N", "30"))
WEBHOOK_URL = "{{key "mail/monitor/webhookurl"}}"
STATE_FILE = os.environ.get("STATE_FILE", "/alloc/top_sasl_prev.txt")
INTERVAL_SECONDS = int(os.environ.get("INTERVAL_SECONDS", "60"))

def die(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(2)

def read_prev():
    try:
      with open(STATE_FILE, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
        return "\n".join(sorted(line.rstrip() for line in lines if line.strip()))
    except FileNotFoundError:
      return ""

def write_prev(s):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    # Normalize and sort lines before saving
    lines = [line.rstrip() for line in s.splitlines() if line.strip()]
    lines.sort()
    with open(STATE_FILE, "w", encoding="utf-8") as f:
      f.write("\n".join(lines) + ("\n" if lines else ""))

def post_webhook(text_payload: str):
    if not WEBHOOK_URL:
        die("WEBHOOK_URL env var is required")
    payload = {"content": f"```\n{text_payload}\n```"}
    headers = {"Content-Type": "application/json"}
    resp = requests.post(WEBHOOK_URL, json=payload, headers=headers, timeout=10)
    print(f"DEBUG: Response {resp.status_code} {resp.text}")
    resp.raise_for_status()

def get_top():
    cmd = (
        f"grep -oE 'sasl_username=[^ ,]+' {LOG_PATH} "
        f"| cut -d= -f2 "
        f"| sort | uniq -c | sort -nr | head -n {TOP_N}"
    )
    return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)

def main():
    if not WEBHOOK_URL:
        die("WEBHOOK_URL env var is required")

    prev = read_prev()

    while True:
      try:
        cur = get_top()
        # Normalize and sort lines for comparison
        cur_norm = "\n".join(sorted(line.rstrip() for line in cur.splitlines() if line.strip()))
      except subprocess.CalledProcessError as e:
        print(f"Command failed, will retry:\n{e.output}", file=sys.stderr)
        time.sleep(INTERVAL_SECONDS)
        continue

      if cur_norm != prev:
        try:
          post_webhook(cur if cur.strip() else "(no sasl_username matches)")
          write_prev(cur)
          prev = cur_norm
        except Exception as e:
          print(f"Webhook failed, will retry next interval: {e}", file=sys.stderr)

      time.sleep(INTERVAL_SECONDS)

if __name__ == "__main__":
    main()
EOT
      }

      template {
        destination = "secrets/env"
        env         = true
        data        = <<EOT
WEBHOOK_URL={{ key "mail/monitor/webhookurl" }}
TOP_N=6
INTERVAL_SECONDS=86400
STATE_FILE=${NOMAD_ALLOC_DIR}/top_sasl_prev.txt
# LOG_PATH is fixed to /var/log/mail/mail.log in the script
EOT
      }

      resources {
        cpu    = 50
        memory = 256
      }
    }
  }
}