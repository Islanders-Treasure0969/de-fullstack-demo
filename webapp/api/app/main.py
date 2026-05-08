"""Phase 5 FastAPI service. Reads from the Postgres operational mart."""

from fastapi import FastAPI

app = FastAPI(title="de-fullstack-demo API", version="0.1.0")


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}
