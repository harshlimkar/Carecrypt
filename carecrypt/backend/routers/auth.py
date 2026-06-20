"""Stub routers for auth, patients, and lab"""
from fastapi import APIRouter

router = APIRouter()

@router.get("/status")
async def status():
    return {"status": "ok"}
