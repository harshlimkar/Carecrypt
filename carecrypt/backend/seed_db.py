import os
import sys
import json
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Load env variables explicitly from the root .env file
dotenv_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
load_dotenv(dotenv_path)

# Add backend directory to path to import config
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from config import Settings

try:
    from supabase import create_client
except ImportError:
    print("Error: 'supabase' package is not installed. Run 'pip install supabase' first.")
    sys.exit(1)

settings = Settings()

if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
    print("Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in your .env file.")
    sys.exit(1)

print(f"Connecting to Supabase at: {settings.SUPABASE_URL}")
supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)

# Define mock users
test_users = [
    {"email": "patient1@gmail.com", "password": "Test@123", "role": "patient", "name": "Alex Johnson"},
    {"email": "patient2@gmail.com", "password": "Test@123", "role": "patient", "name": "Maria Santos"},
    {"email": "patient3@gmail.com", "password": "Test@123", "role": "patient", "name": "Rohan Kumar"},
    {"email": "harshlimkar23@gmail.com", "password": "harsh123", "role": "patient", "name": "Harsh Limkar"},
    {"email": "doctor@carecrypt.dev", "password": "doctor123", "role": "doctor", "name": "Dr. Sarah Smith"},
    {"email": "doctor2@gmail.com", "password": "Test@123", "role": "doctor", "name": "Dr. James Lee"},
    {"email": "lab@carecrypt.dev", "password": "lab123", "role": "lab", "name": "Emma Wilson"},
    {"email": "pharma@carecrypt.dev", "password": "pharma123", "role": "pharmacist", "name": "David Park"},
    {"email": "nurse@carecrypt.dev", "password": "nurse123", "role": "nurse", "name": "Rita Nair"},
]

# Fetch all existing auth users once to build a lookup mapping
def get_existing_auth_users():
    existing = {}
    try:
        print("Fetching existing Auth users list from Supabase...")
        users_list = supabase.auth.admin.list_users()
        for u in users_list:
            if u.email:
                existing[u.email] = u.id
    except Exception as e:
        print(f"Warning: Failed to fetch existing users: {e}")
    return existing

def main():
    print("=== CARECRYPT DATABASE SEEDER ===")
    
    # 1. Fetch existing users to avoid timeouts in loop
    existing_users = get_existing_auth_users()
    
    # 2. Create Auth Users and retrieve their IDs
    uids = {}
    for user_info in test_users:
        email = user_info["email"]
        password = user_info["password"]
        
        if email in existing_users:
            print(f"User {email} already exists (ID: {existing_users[email]})")
            uids[email] = existing_users[email]
        else:
            try:
                print(f"Creating Auth User: {email}...")
                res = supabase.auth.admin.create_user({
                    "email": email,
                    "password": password,
                    "email_confirm": True
                })
                uids[email] = res.user.id
            except Exception as e:
                print(f"Failed to get/create user {email}: {e}")
                sys.exit(1)
            
    print("\nSuccessfully mapped all Auth User IDs:")
    for email, uid in uids.items():
        print(f"  {email} -> {uid}")

    # 2. Insert User Profiles into public.users
    print("\nSeeding public.users table...")
    for user_info in test_users:
        email = user_info["email"]
        uid = uids[email]
        try:
            supabase.table("users").upsert({
                "id": uid,
                "email": email,
                "role": user_info["role"],
                "display_name": user_info["name"]
            }).execute()
        except Exception as e:
            print(f"Error seeding user profile for {email}: {e}")
            print("Please ensure database/schema.sql has been run in the Supabase SQL Editor first!")
            sys.exit(1)

    # 3. Seed Patients
    print("\nSeeding public.patients table...")
    patients_data = [
        {
            "patient_id": "PAT001",
            "user_id": uids["patient1@gmail.com"],
            "name": "Alex Johnson",
            "full_name": "Alexander Johnson",
            "date_of_birth": "1988-03-15",
            "gender": "male",
            "blood_type": "A+",
            "allergies": "Penicillin",
            "heart_rate": 72,
            "blood_pressure": "130/85",
            "blood_glucose": 98.5,
            "health_status": "Stable"
        },
        {
            "patient_id": "PAT002",
            "user_id": uids["patient2@gmail.com"],
            "name": "Maria Santos",
            "full_name": "Maria Elena Santos",
            "date_of_birth": "1975-07-22",
            "gender": "female",
            "blood_type": "O+",
            "allergies": "Sulfa drugs",
            "heart_rate": 68,
            "blood_pressure": "118/75",
            "blood_glucose": 102.0,
            "health_status": "Stable"
        },
        {
            "patient_id": "PAT003",
            "user_id": uids["patient3@gmail.com"],
            "name": "Rohan Kumar",
            "full_name": "Rohan Vijay Kumar",
            "date_of_birth": "1995-11-08",
            "gender": "male",
            "blood_type": "B+",
            "allergies": "None known",
            "heart_rate": 76,
            "blood_pressure": "122/80",
            "blood_glucose": 94.0,
            "health_status": "Good"
        },
        {
            "patient_id": "PAT004",
            "user_id": uids["harshlimkar23@gmail.com"],
            "name": "Harsh Limkar",
            "full_name": "Harsh Limkar",
            "date_of_birth": "2000-01-01",
            "gender": "male",
            "blood_type": "O+",
            "allergies": "None known",
            "heart_rate": 72,
            "blood_pressure": "120/80",
            "blood_glucose": 96.0,
            "health_status": "Stable"
        },
        # Honeypots (No user_id)
        {
            "patient_id": "PAT-HONEYPOT-001",
            "user_id": None,
            "name": "Thomas Decoy",
            "full_name": "Thomas A. Decoy",
            "date_of_birth": "1970-01-01",
            "gender": "male",
            "blood_type": "AB+",
            "health_status": "Stable"
        },
        {
            "patient_id": "PAT-HONEYPOT-002",
            "user_id": None,
            "name": "Anna Trap",
            "full_name": "Anna M. Trap",
            "date_of_birth": "1980-06-15",
            "gender": "female",
            "blood_type": "O-",
            "health_status": "Stable"
        }
    ]
    for p in patients_data:
        supabase.table("patients").upsert(p, on_conflict="patient_id").execute()

    # 4. Seed Diagnosis
    print("Seeding public.diagnosis table...")
    diagnoses_data = [
        {"patient_id": "PAT001", "doctor_id": uids["doctor@carecrypt.dev"], "diagnosis": "Essential Hypertension", "notes": "Managed with ACE inhibitors. Monitor BP weekly.", "status": "chronic"},
        {"patient_id": "PAT001", "doctor_id": uids["doctor@carecrypt.dev"], "diagnosis": "Type 2 Diabetes Mellitus", "notes": "HbA1c trending down. Continue metformin.", "status": "active"},
        {"patient_id": "PAT002", "doctor_id": uids["doctor@carecrypt.dev"], "diagnosis": "Hypothyroidism", "notes": "TSH normalized on levothyroxine 50mcg.", "status": "chronic"},
        {"patient_id": "PAT002", "doctor_id": uids["doctor2@gmail.com"], "diagnosis": "Vitamin D Deficiency", "notes": "Supplement 2000 IU daily.", "status": "active"},
        {"patient_id": "PAT003", "doctor_id": uids["doctor2@gmail.com"], "diagnosis": "Seasonal Allergic Rhinitis", "notes": "Prescribe cetirizine during pollen season.", "status": "active"},
        {"patient_id": "PAT004", "doctor_id": uids["doctor@carecrypt.dev"], "diagnosis": "Routine Checkup", "notes": "Vitals are stable and healthy.", "status": "resolved"}
    ]
    for d in diagnoses_data:
        supabase.table("diagnosis").insert(d).execute()

    # 5. Seed Prescriptions
    print("Seeding public.prescriptions table...")
    prescriptions_data = [
        {
            "patient_id": "PAT001",
            "doctor_id": uids["doctor@carecrypt.dev"],
            "medicines": ["Lisinopril 10mg", "Metformin 500mg", "Aspirin 75mg"],
            "instructions": "Lisinopril: Once daily morning. Metformin: Twice daily with food. Aspirin: Once daily.",
            "status": "pending"
        },
        {
            "patient_id": "PAT001",
            "doctor_id": uids["doctor@carecrypt.dev"],
            "medicines": ["Amlodipine 5mg", "Atorvastatin 20mg"],
            "instructions": "Both once daily at bedtime.",
            "status": "dispensed"
        },
        {
            "patient_id": "PAT002",
            "doctor_id": uids["doctor@carecrypt.dev"],
            "medicines": ["Levothyroxine 50mcg", "Cholecalciferol 2000IU"],
            "instructions": "Levothyroxine: Fasting in the morning. Vitamin D with dinner.",
            "status": "pending"
        },
        {
            "patient_id": "PAT003",
            "doctor_id": uids["doctor2@gmail.com"],
            "medicines": ["Cetirizine 10mg", "Fluticasone Nasal Spray"],
            "instructions": "Cetirizine once daily. Nasal spray 2 puffs each nostril twice daily.",
            "status": "pending"
        },
        {
            "patient_id": "PAT004",
            "medicines": ["Vitamin D3 2000IU"],
            "instructions": "Take one tablet weekly with food.",
            "doctor_id": uids["doctor@carecrypt.dev"],
            "status": "pending"
        }
    ]
    
    rx_ids = []
    for rx in prescriptions_data:
        res = supabase.table("prescriptions").insert(rx).execute()
        if res.data:
            rx_ids.append(res.data[0]["id"])

    # 6. Seed Lab Requests
    print("Seeding public.lab_requests table...")
    lab_requests_data = [
        {"patient_id": "PAT001", "doctor_id": uids["doctor@carecrypt.dev"], "lab_id": uids["lab@carecrypt.dev"], "test_type": "HbA1c", "urgency": "normal", "notes": "Monitor diabetes control", "status": "approved"},
        {"patient_id": "PAT001", "doctor_id": uids["doctor@carecrypt.dev"], "lab_id": uids["lab@carecrypt.dev"], "test_type": "Renal Function Panel", "urgency": "normal", "notes": "ACE inhibitor monitoring", "status": "pending"},
        {"patient_id": "PAT002", "doctor_id": uids["doctor@carecrypt.dev"], "lab_id": uids["lab@carecrypt.dev"], "test_type": "Thyroid Panel (TSH, T3, T4)", "urgency": "normal", "notes": "3-month follow-up", "status": "approved"},
        {"patient_id": "PAT003", "doctor_id": uids["doctor2@gmail.com"], "lab_id": uids["lab@carecrypt.dev"], "test_type": "Allergy Panel", "urgency": "normal", "notes": "Identify allergens", "status": "completed"}
    ]
    
    lab_req_ids = []
    for lr in lab_requests_data:
        res = supabase.table("lab_requests").insert(lr).execute()
        if res.data:
            lab_req_ids.append((lr["test_type"], res.data[0]["id"]))

    # 7. Seed Lab Reports
    print("Seeding public.lab_reports table...")
    allergy_req_id = next((rid for ttype, rid in lab_req_ids if ttype == "Allergy Panel"), None)
    if allergy_req_id:
        supabase.table("lab_reports").insert({
            "request_id": allergy_req_id,
            "sha256_hash": "a3f9c2b8e1d4a7f6c5b3e2d1a9f8c7b6e5d4a3f2c1b9e8d7a6f5c4b3e2d1a9f8",
            "stego_image_url": "https://placeholder.supabase.co/storage/v1/object/public/lab-reports/sample_report.png",
            "verified": True,
            "encrypted_by": uids["lab@carecrypt.dev"]
        }).execute()

    # 8. Seed Nurse Logs
    print("Seeding public.nurse_logs table...")
    nurse_logs_data = [
        {"patient_id": "PAT001", "nurse_id": uids["nurse@carecrypt.dev"], "action": "MEDICINE_GIVEN", "notes": "Lisinopril 10mg administered - morning dose"},
        {"patient_id": "PAT001", "nurse_id": uids["nurse@carecrypt.dev"], "action": "MEDICINE_GIVEN", "notes": "Metformin 500mg administered - with breakfast"},
        {"patient_id": "PAT001", "nurse_id": uids["nurse@carecrypt.dev"], "action": "INJECTION_GIVEN", "notes": "Insulin 10 units - subcutaneous"},
        {"patient_id": "PAT002", "nurse_id": uids["nurse@carecrypt.dev"], "action": "MEDICINE_GIVEN", "notes": "Levothyroxine 50mcg - fasting dose"},
        {"patient_id": "PAT002", "nurse_id": uids["nurse@carecrypt.dev"], "action": "TREATMENT_COMPLETED", "notes": "Morning vitals completed. BP 118/75, HR 68"}
    ]
    for nl in nurse_logs_data:
        supabase.table("nurse_logs").insert(nl).execute()

    # 9. Seed Medicine Status
    print("Seeding public.medicine_status table...")
    dispensed_rx = supabase.table("prescriptions").select("id").eq("status", "dispensed").limit(1).execute()
    if dispensed_rx.data:
        supabase.table("medicine_status").insert({
            "prescription_id": dispensed_rx.data[0]["id"],
            "status": "dispensed",
            "dispensed_at": datetime.now().isoformat(),
            "pharmacist_id": uids["pharma@carecrypt.dev"]
        }).execute()

    # 10. Seed AI Analysis
    print("Seeding public.ai_analysis table...")
    supabase.table("ai_analysis").insert({
        "patient_id": "PAT001",
        "safety_scores": [
            {"medicine": "Lisinopril 10mg", "safety_percent": 89, "risk_level": "safe", "warnings": [], "recommendation": "Continue as prescribed"},
            {"medicine": "Metformin 500mg", "safety_percent": 92, "risk_level": "safe", "warnings": [], "recommendation": "Safe with current dosage"},
            {"medicine": "Aspirin 75mg", "safety_percent": 68, "risk_level": "warning", "warnings": ["Monitor for GI bleeding with long-term use"], "recommendation": "Take with food"},
            {"medicine": "Amlodipine 5mg", "safety_percent": 91, "risk_level": "safe", "warnings": [], "recommendation": "Monitor blood pressure"},
            {"medicine": "Atorvastatin 20mg", "safety_percent": 88, "risk_level": "safe", "warnings": [], "recommendation": "Take at night for best efficacy"}
        ],
        "interactions": ["Aspirin + Lisinopril: Potential reduction of antihypertensive effect at high aspirin doses"],
        "overall_recommendation": "Overall prescription is appropriate. Monitor for GI side effects with Aspirin. Annual liver function check recommended for Atorvastatin.",
        "model_used": "llama3"
    }).execute()

    # 11. Seed Notifications
    print("Seeding public.notifications table...")
    notifications_data = [
        {
            "user_id": uids["patient1@gmail.com"],
            "type": "lab_request",
            "message": "Dr. Smith has requested an HbA1c test. Please approve or reject.",
            "metadata": {"test_type": "HbA1c"}
        },
        {
            "user_id": uids["patient1@gmail.com"],
            "type": "report_uploaded",
            "message": "Your lab report is ready. Results have been encrypted and secured.",
            "metadata": {"report_type": "Allergy Panel"}
        },
        {
            "user_id": uids["patient1@gmail.com"],
            "type": "prescription_generated",
            "message": "New prescription issued by Dr. Smith. Visit pharmacy to collect.",
            "metadata": {"medicines": ["Lisinopril 10mg", "Metformin 500mg"]}
        },
        {
            "user_id": uids["harshlimkar23@gmail.com"],
            "type": "prescription_generated",
            "message": "New prescription issued by Dr. Smith. Visit pharmacy to collect.",
            "metadata": {"medicines": ["Vitamin D3 2000IU"]}
        }
    ]
    for n in notifications_data:
        supabase.table("notifications").insert(n).execute()

    print("\nDatabase Seeding Completed Successfully!")
    print("\nYou can now log in using these accounts:")
    print("-------------------------------------------------------")
    print("Role        | Email                  | Password")
    print("-------------------------------------------------------")
    print("Patient 1   | patient1@gmail.com     | Test@123")
    print("Patient 2   | harshlimkar23@gmail.com| harsh123")
    print("Doctor      | doctor@carecrypt.dev   | doctor123")
    print("Lab Tech    | lab@carecrypt.dev      | lab123")
    print("Pharmacist  | pharma@carecrypt.dev   | pharma123")
    print("Nurse       | nurse@carecrypt.dev    | nurse123")
    print("-------------------------------------------------------")

if __name__ == "__main__":
    main()
