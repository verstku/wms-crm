from typing import Annotated

from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.schemas.health import HealthResponse
from app.services.health import is_database_available

router = APIRouter()


@router.get(
    "/health",
    responses={503: {"model": HealthResponse, "description": "Database is unavailable"}},
)
def health(response: Response, session: Annotated[Session, Depends(get_db)]) -> HealthResponse:
    if is_database_available(session):
        return HealthResponse(status="ok", db="ok")
    response.status_code = 503
    return HealthResponse(status="error", db="error")
