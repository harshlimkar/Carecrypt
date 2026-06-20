"""AI Analysis Router — Drug safety analysis via Ollama/Llama3"""
import httpx
import json
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional

router = APIRouter()


class PrescriptionAnalysisRequest(BaseModel):
    medicines: List[str]
    diagnoses: List[str] = []
    medical_history: List[str] = []
    allergies: List[str] = []
    patient_id: Optional[str] = None


class MedicineSafetyScore(BaseModel):
    medicine: str
    safety_percent: float
    risk_level: str  # safe, warning, danger
    warnings: List[str]
    recommendation: str


class AnalysisResponse(BaseModel):
    medicines: List[MedicineSafetyScore]
    interactions: List[str]
    duplicates: List[str]
    allergy_conflicts: List[str]
    overall_recommendation: str
    model_used: str


OLLAMA_URL = "http://localhost:11434"
MODEL = "llama3"

# Fallback safety database (used when Ollama is offline)
FALLBACK_SAFETY = {
    "paracetamol": 98.0, "acetaminophen": 98.0,
    "amoxicillin": 94.0, "ibuprofen": 72.0,
    "aspirin": 68.0, "metformin": 92.0,
    "lisinopril": 89.0, "atorvastatin": 91.0,
    "amlodipine": 90.0, "levothyroxine": 93.0,
    "cetirizine": 95.0, "omeprazole": 88.0,
}


def _build_prompt(req: PrescriptionAnalysisRequest) -> str:
    return f"""You are a clinical pharmacology AI. Analyze this prescription for safety.

DIAGNOSES: {', '.join(req.diagnoses) or 'Not specified'}
MEDICAL HISTORY: {', '.join(req.medical_history) or 'None'}
ALLERGIES: {', '.join(req.allergies) or 'None known'}
PRESCRIBED MEDICINES: {', '.join(req.medicines)}

Respond ONLY with valid JSON:
{{
  "medicines": [
    {{
      "name": "MedicineName",
      "safetyPercent": 95,
      "riskLevel": "safe",
      "warnings": [],
      "recommendation": "Continue as prescribed"
    }}
  ],
  "interactions": ["interaction description"],
  "duplicates": ["duplicate medications"],
  "allergyConflicts": ["allergy conflicts"],
  "overallRecommendation": "Clinical recommendation"
}}

Risk levels: safe (80-100%), warning (60-79%), danger (0-59%).
"""


def _fallback_scores(medicines: List[str]) -> AnalysisResponse:
    scores = []
    for med in medicines:
        key = med.lower().split()[0]
        safety = FALLBACK_SAFETY.get(key, 85.0)
        risk = "safe" if safety >= 80 else "warning" if safety >= 60 else "danger"
        scores.append(MedicineSafetyScore(
            medicine=med,
            safety_percent=safety,
            risk_level=risk,
            warnings=["High risk — consult pharmacist"] if risk == "danger" else [],
            recommendation="Safe to administer" if risk == "safe" else "Monitor closely",
        ))
    return AnalysisResponse(
        medicines=scores,
        interactions=[],
        duplicates=[],
        allergy_conflicts=[],
        overall_recommendation="AI offline — using cached safety profiles.",
        model_used="fallback",
    )


@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_prescription(req: PrescriptionAnalysisRequest):
    """Analyze a prescription for drug safety using Llama3 via Ollama."""
    prompt = _build_prompt(req)
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{OLLAMA_URL}/api/generate",
                json={"model": MODEL, "prompt": prompt, "stream": False, "format": "json",
                      "options": {"temperature": 0.1}},
            )
        data = response.json()
        raw = data.get("response", "{}")
        parsed = json.loads(raw)

        meds = [
            MedicineSafetyScore(
                medicine=m.get("name", ""),
                safety_percent=float(m.get("safetyPercent", 85)),
                risk_level=m.get("riskLevel", "safe"),
                warnings=m.get("warnings", []),
                recommendation=m.get("recommendation", ""),
            )
            for m in parsed.get("medicines", [])
        ]

        return AnalysisResponse(
            medicines=meds,
            interactions=parsed.get("interactions", []),
            duplicates=parsed.get("duplicates", []),
            allergy_conflicts=parsed.get("allergyConflicts", []),
            overall_recommendation=parsed.get("overallRecommendation", ""),
            model_used=MODEL,
        )
    except Exception:
        # Graceful fallback when Ollama is offline
        return _fallback_scores(req.medicines)


@router.get("/health")
async def ai_health():
    """Check if Ollama is reachable."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{OLLAMA_URL}/api/tags")
        models = [m["name"] for m in resp.json().get("models", [])]
        return {"status": "online", "models": models}
    except Exception:
        return {"status": "offline", "fallback": "enabled"}
