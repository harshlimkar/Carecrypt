import os
import sys
from dotenv import load_dotenv

dotenv_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
load_dotenv(dotenv_path)

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from config import Settings
from supabase import create_client

settings = Settings()
supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

patient_id = "PAT001"

queries = [
    ("patients", lambda: supabase.table("patients").select("*").eq("patient_id", patient_id).single().execute()),
    ("diagnosis", lambda: supabase.table("diagnosis").select("*").eq("patient_id", patient_id).order("created_at", desc=True).execute()),
    ("prescriptions", lambda: supabase.table("prescriptions").select("*").eq("patient_id", patient_id).order("created_at", desc=True).execute()),
    ("lab_reports", lambda: supabase.table("lab_reports").select("*, lab_requests!inner(patient_id)").eq("lab_requests.patient_id", patient_id).order("created_at", desc=True).execute()),
    ("nurse_logs", lambda: supabase.table("nurse_logs").select("*").eq("patient_id", patient_id).order("timestamp", desc=True).limit(10).execute()),
    ("access_logs", lambda: supabase.table("access_logs").select("*").eq("patient_id", patient_id).order("timestamp", desc=True).limit(20).execute()),
    ("ai_analysis", lambda: supabase.table("ai_analysis").select("*").eq("patient_id", patient_id).order("created_at", desc=True).limit(1).execute()),
]

print("Executing all Patient Dashboard queries...")
for name, query_func in queries:
    try:
        res = query_func()
        print(f"  [SUCCESS] {name}: {len(res.data) if isinstance(res.data, list) else 1} rows returned")
    except Exception as e:
        print(f"  [FAILED] {name} query failed:")
        print(f"    {e}")
