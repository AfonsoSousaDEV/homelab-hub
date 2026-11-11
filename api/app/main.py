from fastapi import FastAPI


app = FastAPI(title="Homelab Hub API")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
