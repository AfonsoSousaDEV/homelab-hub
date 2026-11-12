from __future__ import annotations

from collections.abc import Iterator
from datetime import datetime
from typing import Annotated, Protocol

import psycopg
from fastapi import Depends, FastAPI, Header, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql://homelab:homelab@localhost:5432/homelab"
    api_key: str = ""


class SummaryCreate(BaseModel):
    message_id: str | None = Field(default=None, max_length=500)
    subject: str = Field(min_length=1, max_length=500)
    sender: str = Field(min_length=1, max_length=500)
    summary: str = Field(min_length=1, max_length=20_000)
    model: str = Field(min_length=1, max_length=120)
    received_at: datetime | None = None


class Summary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    message_id: str | None = None
    subject: str
    sender: str
    summary: str
    model: str
    received_at: datetime | None = None
    created_at: datetime


class SummaryList(BaseModel):
    items: list[Summary]


class SummaryRepository(Protocol):
    def create(self, payload: SummaryCreate) -> int: ...
    def list(self, limit: int) -> list[Summary]: ...


class PostgresSummaryRepository:
    def __init__(self, database_url: str) -> None:
        self.database_url = database_url

    def create(self, payload: SummaryCreate) -> int:
        query = """
            INSERT INTO summaries
                (message_id, subject, sender, summary, model, received_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (message_id) DO UPDATE SET message_id = EXCLUDED.message_id
            RETURNING id
        """
        with psycopg.connect(self.database_url) as connection, connection.cursor() as cursor:
                cursor.execute(query, (
                    payload.message_id, payload.subject, payload.sender,
                    payload.summary, payload.model, payload.received_at,
                ))
                row = cursor.fetchone()
                if row is None:
                    raise RuntimeError("summary insert returned no id")
                return int(row[0])

    def list(self, limit: int) -> list[Summary]:
        query = """
            SELECT id, message_id, subject, sender, summary, model,
                   received_at, created_at
            FROM summaries ORDER BY created_at DESC LIMIT %s
        """
        with psycopg.connect(self.database_url) as connection, connection.cursor() as cursor:
                cursor.execute(query, (limit,))
                columns = [column.name for column in cursor.description]
                return [Summary(**dict(zip(columns, row))) for row in cursor.fetchall()]


settings = Settings()
app = FastAPI(title="Homelab Hub API", version="0.1.0")


def get_repository() -> Iterator[SummaryRepository]:
    yield PostgresSummaryRepository(settings.database_url)


def require_api_key(x_api_key: str | None = Header(default=None)) -> None:
    if not settings.api_key or x_api_key != settings.api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid API key")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/summaries", response_model=dict[str, int], status_code=status.HTTP_201_CREATED,
          dependencies=[Depends(require_api_key)])
def create_summary(
    payload: SummaryCreate,
    repository: Annotated[SummaryRepository, Depends(get_repository)],
) -> dict[str, int]:
    return {"id": repository.create(payload)}


@app.get("/api/summaries", response_model=SummaryList)
def list_summaries(
    repository: Annotated[SummaryRepository, Depends(get_repository)],
    limit: int = Query(default=20, ge=1, le=100),
) -> SummaryList:
    return SummaryList(items=repository.list(limit))
