import json
import os
import ssl
from contextlib import suppress

import websocket
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

# TrueNAS current JSON-RPC-over-WebSocket endpoint.
#
# Set TRUENAS_WS_URL explicitly if your TrueNAS version exposes a different
# endpoint, for example:
#   wss://truenas.example.org/api/current
TRUENAS_WS_URL = os.environ.get(
    "TRUENAS_WS_URL",
    f"wss://{TRUENAS_URL}/api/current",
)

TRUENAS_DATASETS = ["storage/home", "storage/webtree"]

TRUENAS_INSECURE_SKIP_VERIFY = (
    os.environ.get("TRUENAS_INSECURE_SKIP_VERIFY", "true").lower()
    in ("1", "true", "yes")
)

# TrueNAS permits no more than 100 quota entries in one set_quota call.
TRUENAS_QUOTA_BATCH_SIZE = 100
TRUENAS_WS_TIMEOUT = 60


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


def truenas_websocket_ssl_options():
    """Return websocket-client SSL options."""
    if TRUENAS_INSECURE_SKIP_VERIFY:
        # Equivalent to curl -k.
        # Prefer a trusted certificate in production.
        return {
            "cert_reqs": ssl.CERT_NONE,
            "check_hostname": False,
        }

    return {
        "cert_reqs": ssl.CERT_REQUIRED,
    }


class TrueNASJsonRpcClient:
    """Small synchronous JSON-RPC 2.0 client for TrueNAS WebSocket API."""

    def __init__(self, url, api_key):
        self.url = url
        self.api_key = api_key
        self.ws = None
        self.request_id = 0

    def connect(self):
        try:
            self.ws = websocket.create_connection(
                self.url,
                timeout=TRUENAS_WS_TIMEOUT,
                sslopt=truenas_websocket_ssl_options(),
            )
        except Exception as error:
            raise RuntimeError(
                f"Could not connect to TrueNAS WebSocket API at "
                f"{self.url}: {error}"
            ) from error

    def authenticate(self):
        """Authenticate this WebSocket session using the TrueNAS API key."""
        result = self.call(
            "auth.login_with_api_key",
            [self.api_key],
        )

        if result is not True:
            raise RuntimeError(
                f"TrueNAS API-key authentication failed; "
                f"unexpected result: {result!r}"
            )

    def close(self):
        if self.ws is not None:
            with suppress(Exception):
                self.ws.close()
            self.ws = None

    def call(self, method, params):
        """Perform one JSON-RPC request and return its result."""
        if self.ws is None:
            raise RuntimeError("TrueNAS WebSocket connection is not open")

        self.request_id += 1
        request_id = self.request_id

        request = {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method,
            "params": params,
        }

        try:
            self.ws.send(json.dumps(request))

            while True:
                raw_response = self.ws.recv()

                if raw_response is None:
                    raise RuntimeError(
                        "TrueNAS closed the WebSocket connection unexpectedly"
                    )

                if isinstance(raw_response, bytes):
                    raw_response = raw_response.decode("utf-8")

                response = json.loads(raw_response)

                # TrueNAS may send asynchronous notifications. They do not
                # correspond to this request, so ignore them.
                if response.get("id") != request_id:
                    continue

                if "error" in response:
                    error = response["error"]
                    raise RuntimeError(
                        f"TrueNAS JSON-RPC method {method!r} failed: "
                        f"{json.dumps(error, sort_keys=True)}"
                    )

                if "result" not in response:
                    raise RuntimeError(
                        f"TrueNAS returned an invalid JSON-RPC response for "
                        f"{method!r}: {response!r}"
                    )

                return response["result"]

        except RuntimeError:
            raise
        except Exception as error:
            raise RuntimeError(
                f"TrueNAS JSON-RPC request {method!r} failed: {error}"
            ) from error


def apply_quota_batch(client, quotas):
    """Apply one batch of up to 100 quota entries to every configured dataset."""
    if not quotas:
        return 0

    if len(quotas) > TRUENAS_QUOTA_BATCH_SIZE:
        raise ValueError(
            f"Attempted to submit {len(quotas)} quotas; "
            f"maximum is {TRUENAS_QUOTA_BATCH_SIZE}"
        )

    rpc_calls = 0

    for dataset in TRUENAS_DATASETS:
        # JSON-RPC parameters are positional:
        #
        # pool.dataset.set_quota(dataset, quotas)
        client.call(
            "pool.dataset.set_quota",
            [
                dataset,
                quotas,
            ],
        )
        rpc_calls += 1

    return rpc_calls


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
    quota_batches = 0
    rpc_calls = 0
    quota_batch = []

    truenas = TrueNASJsonRpcClient(
        TRUENAS_WS_URL,
        TRUENAS_API_KEY,
    )

    try:
        truenas.connect()
        truenas.authenticate()

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

            quota_batch.append(
                {
                    "quota_type": "USER",
                    "id": str(uid_number),
                    # LDAP storageQuota is in GiB; TrueNAS expects bytes.
                    "quota_value": storage_quota * (1024 ** 3),
                }
            )

            if len(quota_batch) == TRUENAS_QUOTA_BATCH_SIZE:
                rpc_calls += apply_quota_batch(truenas, quota_batch)
                synced_quotas += len(quota_batch)
                quota_batches += 1

                print(
                    f"Applied TrueNAS quota batch {quota_batches}: "
                    f"{len(quota_batch)} users "
                    f"to {len(TRUENAS_DATASETS)} dataset(s)",
                    flush=True,
                )

                quota_batch = []

        # Submit the final partial batch.
        if quota_batch:
            rpc_calls += apply_quota_batch(truenas, quota_batch)
            synced_quotas += len(quota_batch)
            quota_batches += 1

            print(
                f"Applied final TrueNAS quota batch {quota_batches}: "
                f"{len(quota_batch)} users "
                f"to {len(TRUENAS_DATASETS)} dataset(s)",
                flush=True,
            )

    finally:
        truenas.close()
        connection.unbind()

    return (
        ldap_entries,
        synced_quotas,
        skipped_entries,
        quota_batches,
        rpc_calls,
    )


try:
    (
        ldap_entries,
        synced_quotas,
        skipped_entries,
        quota_batches,
        rpc_calls,
    ) = sync_quotas()

    print(
        f"TrueNAS quota sync complete: "
        f"{synced_quotas} quota(s) applied in {quota_batches} batch(es) "
        f"using {rpc_calls} JSON-RPC call(s); "
        f"{ldap_entries} LDAP entry/entries processed; "
        f"{skipped_entries} skipped.",
        flush=True,
    )

except Exception as error:
    print(f"TrueNAS quota sync failed: {error}", flush=True)
    raise