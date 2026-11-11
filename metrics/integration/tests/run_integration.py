"""Execute the generated workflow in real n8n against isolated PostgreSQL and mocks.

No dependencies beyond Python, Docker Compose and the pinned Docker images. No real
Gmail credentials or Discord URLs are imported. The Docker network has no external
connectivity. Only the unique test project's containers/volumes are removed afterward.
"""

import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import uuid
import re


ROOT = Path(__file__).resolve().parents[1]
CASES = [
    ("success", "succeeded", 2, 2, 0, None),
    ("empty", "succeeded", 0, 0, 0, None),
    ("gmail-failure", "failed", 0, 0, 0, "GMAIL_READ_FAILED"),
    ("invalid", "failed", 2, 0, 2, "INVALID_MODEL_RESPONSE"),
    ("missing", "failed", 2, 0, 2, "INVALID_MODEL_RESPONSE"),
    ("duplicate", "failed", 2, 0, 2, "INVALID_MODEL_RESPONSE"),
    ("bad-priority", "failed", 2, 0, 2, "INVALID_MODEL_RESPONSE"),
    ("unavailable", "failed", 2, 0, 0, "OLLAMA_UNAVAILABLE"),
    ("timeout", "failed", 2, 0, 0, "OLLAMA_TIMEOUT"),
    ("discord-failure", "failed", 2, 2, 0, "DISCORD_SEND_FAILED"),
    ("multipart", "succeeded", 2, 2, 0, None),
    ("discord-partial", "failed", 2, 2, 0, "DISCORD_SEND_FAILED"),
]


def fixture(base, index, scenario):
    workflow = json.loads(json.dumps(base))
    workflow["id"] = f"MetricsTest{index:02}"
    workflow["name"] = f"Synthetic integration: {scenario}"
    workflow["active"] = False
    for node in workflow["nodes"]:
        if node["name"] == "Run context":
            node["parameters"]["assignments"]["assignments"][0]["value"] = "integration-" + scenario
            if scenario == "success":
                node["parameters"]["assignments"]["assignments"][1]["value"] = "test-fixed-execution"
        if node["name"] == "Get unread emails":
            node["type"] = "n8n-nodes-base.code"
            node["typeVersion"] = 2
            node.pop("credentials", None)
            emails = [{"id": f"synthetic-{i}", "from": {"text": "Test <test@example.invalid>"},
                       "subject": f"Synthetic subject {i}", "text": "Synthetic email body"}
                      for i in (1, 2)]
            source = "return " + json.dumps([{"json": email} for email in emails]) + ";"
            if scenario == "empty":
                source = "return [{json:{}}];"
            if scenario == "gmail-failure":
                source = "throw new Error('Synthetic Gmail failure');"
            node["parameters"] = {"jsCode": source}
        if node["name"] == "Ask Ollama":
            node["parameters"]["url"] = "http://mock-services:8080/ollama/" + scenario
            if scenario == "timeout":
                node["parameters"]["options"]["timeout"] = 200
        if node["name"] == "Post to Discord":
            node["parameters"]["url"] = "http://mock-services:8080/discord/" + scenario
        if node["type"] == "n8n-nodes-base.postgres":
            node["credentials"] = {"postgres": {"id": "MetricsTestWriter", "name": "Isolated metrics writer"}}
    # Fail closed if a fixture could access a real email account or external endpoint.
    assert not any(node["type"] == "n8n-nodes-base.gmail" for node in workflow["nodes"])
    for node in workflow["nodes"]:
        if node["type"] == "n8n-nodes-base.httpRequest":
            assert node["parameters"]["url"].startswith("http://mock-services:8080/")
    return workflow


def main():
    project = "homelab-integration-" + uuid.uuid4().hex[:10]
    env = os.environ.copy()
    secret_values = {name: secrets.token_hex(24) for name in (
        "TEST_DATABASE_PASSWORD", "TEST_WRITER_PASSWORD", "TEST_READER_PASSWORD",
        "TEST_N8N_KEY", "TEST_N8N_DATABASE_PASSWORD")}
    env.update(secret_values)
    compose = ["docker", "compose", "--project-name", project, "-f", str(ROOT / "compose.test.yaml")]

    def command(args, check=True):
        result = subprocess.run(compose + args, env=env, text=True, capture_output=True)
        if check and result.returncode:
            detail = (result.stdout + result.stderr)[-6000:]
            for value in secret_values.values():
                detail = detail.replace(value, "[redacted]")
            raise RuntimeError(detail)
        return result

    def sql(query):
        result = command(["exec", "-T", "metrics-postgres", "psql", "-X", "-At", "-U",
                          "homelab_owner", "-d", "homelab", "-v", "ON_ERROR_STOP=1", "-c", query])
        return json.loads(result.stdout.strip())

    with tempfile.TemporaryDirectory(prefix="homelab-n8n-tests-") as directory:
        artifacts = Path(directory)
        env["N8N_TEST_ARTIFACT_DIR"] = directory
        workflows = artifacts / "workflows"
        workflows.mkdir()
        base = json.loads((ROOT / "workflows/EmailDigestMetrics00001.json").read_text())
        for index, (scenario, *_expected) in enumerate(CASES, 1):
            (workflows / f"{index:02}.json").write_text(json.dumps(fixture(base, index, scenario)))
        credentials = [{"id": "MetricsTestWriter", "name": "Isolated metrics writer", "type": "postgres",
                        "data": {"host": "metrics-postgres", "port": 5432, "database": "homelab",
                                 "user": "metrics_writer", "password": env["TEST_WRITER_PASSWORD"],
                                 "ssl": "disable"}}]
        credential_file = artifacts / "credentials.json"
        credential_file.write_text(json.dumps(credentials))
        credential_file.chmod(0o600)
        print("Starting isolated n8n/PostgreSQL/mocks:", project, flush=True)
        try:
            command(["up", "-d", "--wait", "--wait-timeout", "60"])
            command(["exec", "-T", "n8n", "n8n", "import:credentials", "--input=/fixtures/credentials.json"])
            command(["exec", "-T", "n8n", "n8n", "import:workflow", "--separate", "--input=/fixtures/workflows/"])
            for index, (scenario, status, total, summarized, failed, error) in enumerate(CASES, 1):
                result = command(["exec", "-T", "n8n", "n8n", "execute", f"--id=MetricsTest{index:02}"], check=False)
                rows = sql("SELECT coalesce(json_agg(r), '[]') FROM (SELECT status, emails_total, "
                           "emails_summarized, emails_failed, error_code FROM metrics.workflow_runs "
                           f"WHERE workflow_key = 'integration-{scenario}') r;")
                expected = [{"status": status, "emails_total": total, "emails_summarized": summarized,
                             "emails_failed": failed, "error_code": error}]
                if rows != expected:
                    debug = ""
                    for match in re.finditer(r"(?m)^\{", result.stdout):
                        try:
                            execution, _ = json.JSONDecoder().raw_decode(result.stdout[match.start():])
                            data = execution.get("data", {}).get("resultData", {}).get("runData", {})
                            if data:
                                debug = json.dumps({name: data.get(name) for name in
                                    ("Validate and format", "Post to Discord", "Collect delivery result")}, indent=2)
                                break
                        except (ValueError, AttributeError):
                            continue
                    raise RuntimeError(f"{scenario}: expected {expected}, got {rows}\n"
                                       + (debug or (result.stdout + result.stderr)[-5000:]))
                if (result.returncode == 0) != (status == "succeeded"):
                    raise RuntimeError(f"{scenario}: wrong n8n completion status\n"
                                       + (result.stdout + result.stderr)[-3000:])
                print(f"PASS: {scenario} → {status}, one metrics row, {summarized}/{total} summarized", flush=True)
                if scenario == "success":
                    command(["exec", "-T", "n8n", "n8n", "execute", f"--id=MetricsTest{index:02}"])
                    repeated = sql("SELECT count(*) FROM metrics.workflow_runs WHERE workflow_key = 'integration-success';")
                    assert repeated == 1
                    print("PASS: duplicate start stops before Gmail/model/delivery and retains one row", flush=True)
            counts = json.loads(command(["exec", "-T", "mock-services", "node", "-e",
                "fetch('http://localhost:8080/counts').then(r=>r.json()).then(j=>console.log(JSON.stringify(j)))"]
            ).stdout.strip())
            for scenario, *_expected in CASES:
                count = counts.get(scenario, {"ollama": 0, "discord": 0})
                assert count["ollama"] == (0 if scenario in ("empty", "gmail-failure") else 1), (scenario, count)
                if scenario in ("success", "discord-failure"):
                    assert count["discord"] == 1, (scenario, count)
                elif scenario in ("multipart", "discord-partial"):
                    assert count["discord"] > 1, (scenario, count)
                else:
                    assert count["discord"] == 0, (scenario, count)
            assert sql("SELECT count(*) FROM metrics.workflow_runs WHERE status = 'running';") == 0
            print("PASS: no delivery for invalid/empty/failed summaries; multipart finalizes once", flush=True)
            print("PASS: all 12 n8n integration cases; no real email or Discord access", flush=True)
        finally:
            cleanup = command(["down", "--volumes", "--remove-orphans"], check=False)
            if cleanup.returncode:
                print("Test cleanup failed for project", project, flush=True)


if __name__ == "__main__":
    main()
