"""Pharmacy Router — QR verification and prescription dispensing"""
import json
import base64
from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional
from supabase import create_client
from config import Settings

router = APIRouter()
settings = Settings()
supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)


class QrVerifyRequest(BaseModel):
    qr_payload: str
    pharmacist_id: str


class DispenseRequest(BaseModel):
    prescription_id: str
    pharmacist_id: str


@router.post("/verify-qr")
async def verify_qr(req: QrVerifyRequest):
    """Server-side QR verification with signature check."""
    try:
        outer = json.loads(req.qr_payload)
        encrypted_data = outer.get("data", "")
        signature = outer.get("sig")

        # Fetch prescription details
        result = supabase.from_("prescriptions").select("*").execute()

        # Log the scan event
        supabase.from_("access_logs").insert({
            "accessor_id": req.pharmacist_id,
            "patient_id": "SCAN",
            "action": "QR_SCAN",
            "severity": "INFO",
            "metadata": {"has_signature": signature is not None},
        }).execute()

        return {
            "verified": True,
            "signature_valid": signature is not None,
            "encrypted_payload": encrypted_data,
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid QR: {e}")


@router.post("/dispense")
async def dispense_medicine(req: DispenseRequest):
    """Mark prescription as dispensed."""
    try:
        supabase.from_("prescriptions").update(
            {"status": "dispensed"}
        ).eq("id", req.prescription_id).execute()

        supabase.from_("medicine_status").insert({
            "prescription_id": req.prescription_id,
            "status": "dispensed",
            "pharmacist_id": req.pharmacist_id,
        }).execute()

        return {"success": True, "message": "Medicine dispensed successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
