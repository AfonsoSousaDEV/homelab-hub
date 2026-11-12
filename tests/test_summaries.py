from datetime import UTC, datetime

from fastapi.testclient import TestClient

from api.app import main


class FakeRepository:
    def create(self, payload: main.SummaryCreate) -> int:
        return 42

    def list(self, limit: int) -> list[main.Summary]:
        return [main.Summary(
            id=42, message_id="email-1", subject="Teste", sender="teste@example.com",
            summary="- Tudo bem", model="qwen3:4b",
            received_at=datetime(2026, 11, 11, tzinfo=UTC),
            created_at=datetime(2026, 11, 11, tzinfo=UTC),
        )][:limit]


def test_post_requires_api_key(monkeypatch) -> None:
    monkeypatch.setattr(main.settings, "api_key", "secret")
    response = TestClient(main.app).post("/api/summaries", json={})
    assert response.status_code == 401


def test_create_and_list_summary(monkeypatch) -> None:
    monkeypatch.setattr(main.settings, "api_key", "secret")
    main.app.dependency_overrides[main.get_repository] = lambda: FakeRepository()
    client = TestClient(main.app)
    created = client.post(
        "/api/summaries", headers={"X-API-Key": "secret"},
        json={"message_id": "email-1", "subject": "Teste", "sender": "teste@example.com",
              "summary": "- Tudo bem", "model": "qwen3:4b"},
    )
    listed = client.get("/api/summaries?limit=20")
    main.app.dependency_overrides.clear()
    assert created.status_code == 201
    assert created.json() == {"id": 42}
    assert listed.status_code == 200
    assert listed.json()["items"][0]["id"] == 42
