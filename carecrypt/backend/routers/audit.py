"""Audit Router — security logs and honeypatient access alerts"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from supabase import create_client
from config import Settings

router = APIRouter()
settings = Settings()
supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

HONEYPOT_IDS = {"PAT-HONEYPOT-001", "PAT-HONEYPOT-002", "PAT-HONEYPOT-003"}


class AccessLogRequest(BaseModel):
    accessor_id: str
    patient_id: str
    action: str
    ip_address: Optional[str] = None
    metadata: Optional[dict] = None


@router.post("/log")
async def log_access(req: AccessLogRequest):
    """Log a patient data access event. Triggers alert if honeypatient accessed."""
    is_honeypot = req.patient_id in HONEYPOT_IDS
    severity = "CRITICAL" if is_honeypot else "INFO"

    supabase.from_("access_logs").insert({
        "accessor_id": req.accessor_id,
        "patient_id": req.patient_id,
        "action": req.action,
        "ip_address": req.ip_address,
        "is_honeypot": is_honeypot,
        "severity": severity,
        "metadata": req.metadata or {},
    }).execute()

    if is_honeypot:
        # Trigger security alert via Supabase RPC
        supabase.rpc("notify_security_admins", {
            "alert_type": "HONEYPATIENT_ACCESS",
            "accessor_id": req.accessor_id,
            "patient_id": req.patient_id,
            "severity": "CRITICAL",
            "message": f"🚨 HONEYPATIENT ACCESSED: {req.patient_id} by {req.accessor_id}",
        }).execute()

    return {"logged": True, "is_honeypot": is_honeypot, "severity": severity}


@router.get("/summary/{patient_id}")
async def get_audit_summary(patient_id: str):
    """Get access log summary for a patient."""
    result = supabase.from_("access_logs") \
        .select("*") \
        .eq("patient_id", patient_id) \
        .order("timestamp", desc=True) \
        .limit(50) \
        .execute()

    logs = result.data
    honeypot_count = sum(1 for l in logs if l.get("is_honeypot"))
    return {
        "total_events": len(logs),
        "honeypot_attempts": honeypot_count,
        "logs": logs,
    }
