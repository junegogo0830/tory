from fastapi import APIRouter

from .routes import archive, auth, community, course, health, location, profile, roadview

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(location.router)
api_router.include_router(archive.router)
api_router.include_router(course.router)
api_router.include_router(profile.router)
api_router.include_router(roadview.router)
api_router.include_router(community.router)
