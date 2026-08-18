import json
import os
import ssl
import urllib.error
import urllib.request

from ldap3 import SUBTREE, Connection, Server

LDAP_HOST = "136.206.16.4"
LDAP_PORT = 389

BIND_USERNAME = os.environ["LDAP_USERNAME"]
BIND_PASSWORD = os.environ["LDAP_PASSWORD"]
BIND_DN = (
    f"uid={BIND_USERNAME},ou=serviceAccounts,"
    "o=redbrick,dc=redbrick,dc=dcu,dc=ie"
)

SEARCH_BASE = "ou=accounts,o=redbrick,dc=redbrick,dc=dcu,dc=ie"
SEARCH_FILTER = "(objectClass=brickie)"
LDAP_PAGE_SIZE = 250

TRUENAS_API_KEY = os.environ["TRUENAS_API_KEY"]
TRUENAS_URL = os.environ["TRUENAS_URL"]
TRUENAS_API_URL = f"https://{TRUENAS_URL}/api/v2.0/pool/dataset/set_quota"

TRUENAS_DATASETS = ["storage/home", "storage/webtree"]

TRUENAS_INSECURE_SKIP_VERIFY = (
    os.environ.get("TRUENAS_INSECURE_SKIP_VERIFY", "true").lower()
    in ("1", "true", "yes")
)

# TrueNAS permits no more than 100 entries in a single quotas request.
TRUENAS_QUOTA_BATCH_SIZE = 100


def ldap_value_to_int(value, attribute_name, dn):
    """Return a single LDAP numeric attribute as an integer."""
    if isinstance(value, list):
        if len(value) != 1:
            raise ValueError(
                f"{dn}: expected exactly one {attribute_name} value, "
                f"got {len(value)}"
            )

        value = value[0]

    if value is None:
        raise ValueError(f"{dn}: missing {attribute_name}")

    try:
        parsed = int(value)
    except (TypeError, ValueError) as error:
        raise ValueError(
            f"{dn}: invalid {attribute_name} value {value!r}"
        ) from error

    if parsed < 0:
        raise ValueError(
            f"{dn}: invalid negative {attribute_name} value {parsed}"
        )

    return parsed


def truenas_ssl_context():
    if TRUENAS_INSECURE_SKIP_VERIFY:
        # Equivalent to curl -k. Prefer a trusted TrueNAS certificate and
        # TRUENAS_INSECURE_SKIP_VERIFY=false when possible.
        return ssl._create_unverified_context()

    return ssl.create_default_context()


def apply_quota_batch(quotas, ssl_context):
    """Send one batch of up to 100 quota entries to TrueNAS."""
    if not quotas:
        return

    if len(quotas) > TRUENAS_QUOTA_BATCH_SIZE:
        raise ValueError(
            f"Attempted to submit {len(quotas)} quotas; "
            f"maximum is {TRUENAS_QUOTA_BATCH_SIZE}"
        )

    for dataset in TRUENAS_DATASETS:

        payload = {
            "dataset": dataset,
            "quotas": quotas,
        }

        request = urllib.request.Request(
            TRUENAS_API_URL,
            data=json.dumps(payload).encode("utf-8"),
            method="POST",
            headers={
                "Authorization": f"Bearer {TRUENAS_API_KEY}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )

        try:
            with urllib.request.urlopen(
                request,
                timeout=60,
                context=ssl_context,
            ) as response:
                # Read the response so HTTP connection resources are released.
                response.read()

                if not 200 <= response.status < 300:
                    raise RuntimeError(
                        f"TrueNAS returned unexpected HTTP status {response.status}"
                    )

        except urllib.error.HTTPError as error:
            response_body = error.read().decode("utf-8", errors="replace")

            raise RuntimeError(
                f"TrueNAS quota API request failed with HTTP {error.code}: "
                f"{response_body}"
            ) from error

        except urllib.error.URLError as error:
            raise RuntimeError(
                f"Could not reach TrueNAS quota API at {TRUENAS_API_URL}: {error}"
            ) from error


def sync_quotas():
    server = Server(
        LDAP_HOST,
        port=LDAP_PORT,
        connect_timeout=10,
    )

    connection = Connection(
        server,
        user=BIND_DN,
        password=BIND_PASSWORD,
        auto_bind=True,
        raise_exceptions=True,
    )

    ldap_entries = 0
    synced_quotas = 0
    skipped_entries = 0
    request_count = 0
    quota_batch = []

    ssl_context = truenas_ssl_context()

    try:
        results = connection.extend.standard.paged_search(
            search_base=SEARCH_BASE,
            search_filter=SEARCH_FILTER,
            search_scope=SUBTREE,
            attributes=["uidNumber", "storageQuota"],
            paged_size=LDAP_PAGE_SIZE,
            generator=True,
        )

        for result in results:
            if result["type"] != "searchResEntry":
                continue

            ldap_entries += 1

            dn = result["dn"]
            attributes = result["attributes"]

            try:
                uid_number = ldap_value_to_int(
                    attributes.get("uidNumber"),
                    "uidNumber",
                    dn,
                )

                storage_quota = ldap_value_to_int(
                    attributes.get("storageQuota"),
                    "storageQuota",
                    dn,
                )

            except ValueError as error:
                skipped_entries += 1
                print(f"Skipping LDAP entry: {error}", flush=True)
                continue

            quota_batch.append({
                "quota_type": "USER",
                "id": str(uid_number),
                "quota_value": storage_quota * (1024 ** 3),
            })

            if len(quota_batch) == TRUENAS_QUOTA_BATCH_SIZE:
                apply_quota_batch(quota_batch, ssl_context)

                synced_quotas += len(quota_batch)
                request_count += 1

                print(
                    f"Applied TrueNAS quota batch {request_count}: "
                    f"{len(quota_batch)} users",
                    flush=True,
                )

                quota_batch = []

        # Submit the final batch, which may contain fewer than 100 entries.
        if quota_batch:
            apply_quota_batch(quota_batch, ssl_context)

            synced_quotas += len(quota_batch)
            request_count += 1

            print(
                f"Applied final TrueNAS quota batch {request_count}: "
                f"{len(quota_batch)} users",
                flush=True,
            )

    finally:
        connection.unbind()

    return ldap_entries, synced_quotas, skipped_entries, request_count


try:
    ldap_entries, synced_quotas, skipped_entries, request_count = sync_quotas()

    print(
        f"TrueNAS quota sync complete: "
        f"{synced_quotas} quota(s) applied in {request_count} request(s); "
        f"{ldap_entries} LDAP entry/entries processed; "
        f"{skipped_entries} skipped.",
        flush=True,
    )

except Exception as error:
    print(f"TrueNAS quota sync failed: {error}", flush=True)
    raise