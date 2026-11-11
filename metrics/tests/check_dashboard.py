"""Exercise provisioned Grafana queries against its actual PostgreSQL datasource.

Uses only Python's standard library. Set GRAFANA_ADMIN_PASSWORD or enter it when
prompted. This validates API queries, not the browser rendering of the dashboard.
"""

import base64
import getpass
import json
import os
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def main():
    url = os.environ.get("GRAFANA_URL", "http://127.0.0.1:53000").rstrip("/")
    username = os.environ.get("GRAFANA_ADMIN_USER", "dani")
    password = os.environ.get("GRAFANA_ADMIN_PASSWORD") or getpass.getpass("Grafana password: ")
    auth = base64.b64encode(f"{username}:{password}".encode()).decode()

    def request(path, body=None):
        data = json.dumps(body).encode() if body is not None else None
        req = Request(url + path, data=data, headers={
            "Authorization": "Basic " + auth,
            "Content-Type": "application/json",
        })
        with urlopen(req, timeout=30) as response:
            return json.load(response)

    health = request("/api/health")
    if health.get("database") != "ok":
        raise RuntimeError("Grafana's internal database is unhealthy")
    datasource = request("/api/datasources/uid/homelab-postgres/health")
    if datasource.get("status") != "OK":
        raise RuntimeError("PostgreSQL datasource is unhealthy")

    dashboard = request("/api/dashboards/uid/homelab-workflow-runs")["dashboard"]
    if len(dashboard["panels"]) != 9:
        raise RuntimeError("Expected nine provisioned panels")
    for panel in dashboard["panels"]:
        queries = [dict(target, intervalMs=3600000, maxDataPoints=1000)
                   for target in panel["targets"]]
        response = request("/api/ds/query", {
            "from": "now-24h", "to": "now", "queries": queries,
        })
        result = response.get("results", {}).get("A", {})
        if result.get("error") or result.get("status", 200) >= 400:
            raise RuntimeError(f"Panel query failed: {panel['title']}")
        frames = result.get("frames")
        if not frames:
            raise RuntimeError(f"Panel returned no data frame: {panel['title']}")
        print("PASS:", panel["title"])
    print("PASS: Grafana health, datasource and all nine SQL panel queries")


if __name__ == "__main__":
    try:
        main()
    except (HTTPError, URLError, RuntimeError, KeyError) as exc:
        raise SystemExit(f"FAIL: {exc}") from None
