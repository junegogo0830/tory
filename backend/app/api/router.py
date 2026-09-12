from fastapi import APIRouter

from .routes import archive, auth, community, course, discovery, health, highlight, image, location, map as map_routes, profile, roadview, weather

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(location.router)
api_router.include_router(archive.router)
api_router.include_router(course.router)
api_router.include_router(profile.router)
api_router.include_router(roadview.router)
api_router.include_router(community.router)
api_router.include_router(weather.router)
api_router.include_router(highlight.router)
api_router.include_router(map_routes.router)
api_router.include_router(image.router)
api_router.include_router(discovery.router)
