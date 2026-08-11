#!/usr/bin/env python3
"""Copy wildcard TLS cert from Traefik file-based cert store to OpenLDAP cert dir.

Looks for fullchain.pem + privkey.pem in the traefik certs dir (domain-named
subdirectory, e.g. /storage/nomad/traefik/certs/rb.dcu.ie/).

Usage: extract-certs.py <traefik-certs-dir> <output-dir>
"""
import os
import shutil
import sys
import time
import pwd
from pathlib import Path


def log(msg: str):
    ts = time.strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)


def list_dir(dir_path: Path, label: str):
    """List all files in a directory (not recursively)."""
    try:
        entries = list(dir_path.iterdir())
    except FileNotFoundError:
        log(f"  {label}: directory NOT FOUND: {dir_path}")
        return []
    except PermissionError:
        log(f"  {label}: PERMISSION DENIED: {dir_path}")
        return []

    log(f"  {label}: {len(entries)} entries in {dir_path}")
    for e in sorted(entries, key=lambda x: x.name):
        mode = oct(e.stat().st_mode) if e.exists() else "???"
        log(f"    {mode} {e.name}")
    return entries


def check_file_privileges():
    """Print user/group/umask for debugging container permissions."""
    try:
        uid = os.getuid()
        gid = os.getgid()
        user_info = pwd.getpwuid(uid)
        umask = os.umask(0)
        os.umask(umask)
        log(f"  running as: uid={uid} ({user_info.pw_name}) gid={gid} umask={oct(umask)}")
    except Exception as e:
        log(f"  privilege check failed: {e}")


def main() -> int:
    certs_dir = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    copy_cert_dir = Path(sys.argv[3])
    poll_interval = int(os.environ.get("POLL_INTERVAL", "15"))

    log("=== ACME CERT EXTRACT STARTING ===")
    log(f"  args: {sys.argv}")
    log(f"  poll_interval={poll_interval}s")
    log(f"  certs_dir={certs_dir}")
    log(f"  output_dir={output_dir}")
    check_file_privileges()

    # Check traefik certs dir immediately
    log("--- Checking traefik certs dir ---")
    list_dir(certs_dir, "traefik-certs")

    # Check output parent dir
    log("--- Checking output parent dir ---")
    list_dir(output_dir.parent, "output-parent")

    iteration = 0
    while True:
        iteration += 1

        # Re-list traefik dir each iteration
        files = list_dir(certs_dir, f"traefik-certs (iter={iteration})")

        crt = None
        key = None
        for f in files:
            name = f.name
            if name == "fullchain.pem":
                crt = f
                log(f"  ✓ found CRT: fullchain.pem")
            if name == "privkey.pem":
                key = f
                log(f"  ✓ found KEY: privkey.pem")

        if crt:
            log(f"  CRT: {crt}  size={crt.stat().st_size}")
        else:
            log(f"  CRT: NOT FOUND (looking for fullchain.pem)")

        if key:
            log(f"  KEY: {key}  size={key.stat().st_size}")
        else:
            log(f"  KEY: NOT FOUND (looking for privkey.pem)")

        if crt and key:
            log("--- Both cert files found! Copying... ---")
            output_dir.mkdir(parents=True, exist_ok=True)
            log(f"  Created/wrote to output dir: {output_dir}")
            list_dir(output_dir, "output-dir (before copy)")

            dest_crt = output_dir / "server.crt"
            dest_key = output_dir / "server.key"

            shutil.copy2(str(crt), str(dest_crt))
            log(f"  Copied fullchain.pem -> {dest_crt}  (size={dest_crt.stat().st_size})")

            shutil.copy2(str(key), str(dest_key))
            dest_key.chmod(0o644)
            log(f"  Copied privkey.pem -> {dest_key}  (size={dest_key.stat().st_size})")

            list_dir(output_dir, "output-dir (after copy)")

            # Also copy crt as CA.crt since Bitnami might look for it
            dest_ca = output_dir / "CA.crt"
            if not dest_ca.exists():
                shutil.copy2(str(crt), str(dest_ca))
                log(f"  Also copied fullchain.pem -> {dest_ca} (CA fallback)")


            # Also copy it to the storage mount
            dest_ca = copy_cert_dir / "server.crt"
            if not dest_ca.exists():
                shutil.copy2(str(crt), str(dest_ca))
                log(f"  Also copied fullchain.pem -> {dest_ca} (storage mount)")
            log(f"=== ACME CERT EXTRACT SUCCESS ===")
            return 0

        log(f"  wildcard cert not complete, sleeping {poll_interval}s")
        time.sleep(poll_interval)


if __name__ == "__main__":
    sys.exit(main())