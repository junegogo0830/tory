from fastapi import APIRouter

from .routes import archive, course, health, location

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(location.router)
api_router.include_router(archive.router)
api_router.include_router(course.router)
