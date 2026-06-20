# CareCrypt — API Reference

Base URL: `http://localhost:8000` (dev) | `https://api.carecrypt.app` (prod)

---

## Authentication

All endpoints require a valid Supabase JWT in the `Authorization` header:

```
Authorization: Bearer <supabase_access_token>
```

---

## AI Analysis

### POST `/api/ai/analyze`
Analyze a prescription for drug safety using Llama3.

**Request:**
```json
{
  "medicines": ["Paracetamol 500mg", "Ibuprofen 400mg"],
  "diagnoses": ["Headache", "Fever"],
  "medical_history": ["Hypertension"],
  "allergies": ["Penicillin"],
  "patient_id": "uuid-optional"
}
```

**Response:**
```json
{
  "medicines": [
    {
      "medicine": "Paracetamol 500mg",
      "safety_percent": 98.0,
      "risk_level": "safe",
      "warnings": [],
      "recommendation": "Safe to administer"
    }
  ],
  "interactions": ["Ibuprofen + Aspirin can increase bleeding risk"],
  "duplicates": [],
  "allergy_conflicts": [],
  "overall_recommendation": "Prescription is clinically appropriate",
  "model_used": "llama3"
}
```

**Risk Levels:**
| Level | Range | Color |
|-------|-------|-------|
| `safe` | 80–100% | Green |
| `warning` | 60–79% | Amber |
| `danger` | 0–59% | Red |

---

### GET `/api/ai/health`
Check Ollama connectivity.

**Response:**
```json
{ "status": "online", "models": ["llama3"] }
```

---

## Pharmacy

### POST `/api/pharmacy/verify-qr`
Server-side verification of a CareCrypt prescription QR code.

**Request:**
```json
{
  "qr_payload": "{\"data\":\"AES_ENCRYPTED...\",\"sig\":\"ED25519_SIG...\",\"app\":\"CareCrypt\"}",
  "pharmacist_id": "uuid"
}
```

**Response:**
```json
{
  "verified": true,
  "signature_valid": true,
  "encrypted_payload": "AES_ENCRYPTED_DATA"
}
```

---

### POST `/api/pharmacy/dispense`
Mark a prescription as dispensed.

**Request:**
```json
{
  "prescription_id": "uuid",
  "pharmacist_id": "uuid"
}
```

**Response:**
```json
{ "success": true, "message": "Medicine dispensed successfully" }
```

---

## Audit & Security

### POST `/api/audit/log`
Log a patient data access event. Automatically triggers CRITICAL alert if a honeypatient is accessed.

**Request:**
```json
{
  "accessor_id": "user-uuid",
  "patient_id": "patient-uuid",
  "action": "VIEW_RECORDS",
  "ip_address": "192.168.1.1",
  "metadata": { "screen": "doctor_patient_access" }
}
```

**Response:**
```json
{
  "logged": true,
  "is_honeypot": false,
  "severity": "INFO"
}
```

> ⚠️ If `is_honeypot: true` is returned, a `CRITICAL` security alert has been sent to all admins via Supabase RPC.

---

### GET `/api/audit/summary/{patient_id}`
Get access log summary for a patient.

**Response:**
```json
{
  "total_events": 42,
  "honeypot_attempts": 0,
  "logs": [...]
}
```

---

## Honeypatient IDs

These patient IDs are security traps. Any access triggers an immediate alert:

| ID | Purpose |
|----|---------|
| `PAT-HONEYPOT-001` | Doctor honeypot |
| `PAT-HONEYPOT-002` | Pharmacist honeypot |
| `PAT-HONEYPOT-003` | Nurse honeypot |

---

## Security Architecture

```
QR Code Flow:
  Doctor → Prescribe → AES-256-GCM encrypt → Ed25519 sign
  Patient → Show QR (5min expiry, biometric gate)
  Pharmacist → Scan → Ed25519 verify → AES decrypt → Dispense

NFC Flow:
  Doctor/Nurse → Initiate NFC → X25519 key exchange
  Patient device → Write NDEF tag with publicKey + patientId
  Doctor → Derive shared secret → Encrypted session

Lab Report Flow:
  Lab → Pick report → AES-256-GCM encrypt → SHA-256 hash
       → LSB steganography (embed in cover image)
       → Upload to Supabase Storage
       → Notify patient via FCM + Supabase Realtime
```
