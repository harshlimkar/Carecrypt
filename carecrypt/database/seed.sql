-- ============================================================
-- CareCrypt Mock Data Seeder
-- Run AFTER schema.sql
-- ============================================================

-- NOTE: Users are created via Supabase Auth first, then this
-- seed adds profile rows. For testing, run via Supabase Dashboard.

-- ============================================================
-- STEP 1: Create Auth Users via Supabase Dashboard or CLI
-- ============================================================
-- supabase auth admin create-user patient1@gmail.com patient1@123
-- supabase auth admin create-user doctor1@gmail.com doctor1@123
-- supabase auth admin create-user lab1@gmail.com lab1@123
-- supabase auth admin create-user pharmacist1@gmail.com pharmacist1@123
-- supabase auth admin create-user nurse1@gmail.com nurse1@123

-- ============================================================
-- STEP 2: Seed user profiles (replace UUIDs with actual auth UIDs)
-- ============================================================

-- Placeholder UUIDs (replace with real Supabase Auth UIDs)
DO $$
DECLARE
    patient1_uid UUID := '00000000-0000-0000-0000-000000000001';
    patient2_uid UUID := '00000000-0000-0000-0000-000000000002';
    patient3_uid UUID := '00000000-0000-0000-0000-000000000003';
    doctor1_uid UUID  := '00000000-0000-0000-0000-000000000004';
    doctor2_uid UUID  := '00000000-0000-0000-0000-000000000005';
    lab1_uid UUID     := '00000000-0000-0000-0000-000000000006';
    pharm1_uid UUID   := '00000000-0000-0000-0000-000000000007';
    nurse1_uid UUID   := '00000000-0000-0000-0000-000000000008';

BEGIN

-- ── Users ────────────────────────────────────────────────
INSERT INTO public.users (id, email, role, display_name) VALUES
    (patient1_uid, 'patient1@gmail.com', 'patient', 'Alex Johnson'),
    (patient2_uid, 'patient2@gmail.com', 'patient', 'Maria Santos'),
    (patient3_uid, 'patient3@gmail.com', 'patient', 'Rohan Kumar'),
    (doctor1_uid,  'doctor1@gmail.com',  'doctor',  'Dr. Sarah Smith'),
    (doctor2_uid,  'doctor2@gmail.com',  'doctor',  'Dr. James Lee'),
    (lab1_uid,     'lab1@gmail.com',     'lab',     'Emma Wilson'),
    (pharm1_uid,   'pharmacist1@gmail.com', 'pharmacist', 'David Park'),
    (nurse1_uid,   'nurse1@gmail.com',   'nurse',   'Rita Nair')
ON CONFLICT (id) DO NOTHING;

-- ── Patients ─────────────────────────────────────────────
INSERT INTO public.patients (patient_id, user_id, name, full_name, date_of_birth, gender, blood_type, allergies, heart_rate, blood_pressure, blood_glucose, health_status) VALUES
    ('PAT001', patient1_uid, 'Alex Johnson', 'Alexander Johnson', '1988-03-15', 'male', 'A+', 'Penicillin', 72, '130/85', 98.5, 'Stable'),
    ('PAT002', patient2_uid, 'Maria Santos', 'Maria Elena Santos', '1975-07-22', 'female', 'O+', 'Sulfa drugs', 68, '118/75', 102.0, 'Stable'),
    ('PAT003', patient3_uid, 'Rohan Kumar', 'Rohan Vijay Kumar', '1995-11-08', 'male', 'B+', 'None known', 76, '122/80', 94.0, 'Good')
ON CONFLICT (patient_id) DO NOTHING;

-- ── HONEYPATIENT Records (Security Traps) ────────────────
INSERT INTO public.patients (patient_id, user_id, name, full_name, date_of_birth, gender, blood_type, health_status) VALUES
    ('PAT-HONEYPOT-001', NULL, 'Thomas Decoy', 'Thomas A. Decoy', '1970-01-01', 'male', 'AB+', 'Stable'),
    ('PAT-HONEYPOT-002', NULL, 'Anna Trap', 'Anna M. Trap', '1980-06-15', 'female', 'O-', 'Stable'),
    ('PAT-HONEYPOT-003', NULL, 'Victor Canary', 'Victor B. Canary', '1965-12-25', 'male', 'A-', 'Stable')
ON CONFLICT (patient_id) DO NOTHING;

-- ── Diagnoses ────────────────────────────────────────────
INSERT INTO public.diagnosis (patient_id, doctor_id, diagnosis, notes, status) VALUES
    ('PAT001', doctor1_uid, 'Essential Hypertension', 'Managed with ACE inhibitors. Monitor BP weekly.', 'chronic'),
    ('PAT001', doctor1_uid, 'Type 2 Diabetes Mellitus', 'HbA1c trending down. Continue metformin.', 'active'),
    ('PAT002', doctor1_uid, 'Hypothyroidism', 'TSH normalized on levothyroxine 50mcg.', 'chronic'),
    ('PAT002', doctor2_uid, 'Vitamin D Deficiency', 'Supplement 2000 IU daily.', 'active'),
    ('PAT003', doctor2_uid, 'Seasonal Allergic Rhinitis', 'Prescribe cetirizine during pollen season.', 'active');

-- ── Prescriptions ────────────────────────────────────────
INSERT INTO public.prescriptions (patient_id, doctor_id, medicines, instructions, status) VALUES
    ('PAT001', doctor1_uid, ARRAY['Lisinopril 10mg', 'Metformin 500mg', 'Aspirin 75mg'], 
     'Lisinopril: Once daily morning. Metformin: Twice daily with food. Aspirin: Once daily.', 'pending'),
    ('PAT001', doctor1_uid, ARRAY['Amlodipine 5mg', 'Atorvastatin 20mg'], 
     'Both once daily at bedtime.', 'dispensed'),
    ('PAT002', doctor1_uid, ARRAY['Levothyroxine 50mcg', 'Cholecalciferol 2000IU'], 
     'Levothyroxine: Fasting in the morning. Vitamin D with dinner.', 'pending'),
    ('PAT003', doctor2_uid, ARRAY['Cetirizine 10mg', 'Fluticasone Nasal Spray'], 
     'Cetirizine once daily. Nasal spray 2 puffs each nostril twice daily.', 'pending');

-- ── Lab Requests ─────────────────────────────────────────
INSERT INTO public.lab_requests (patient_id, doctor_id, lab_id, test_type, urgency, notes, status) VALUES
    ('PAT001', doctor1_uid, lab1_uid, 'HbA1c', 'normal', 'Monitor diabetes control', 'approved'),
    ('PAT001', doctor1_uid, lab1_uid, 'Renal Function Panel', 'normal', 'ACE inhibitor monitoring', 'pending'),
    ('PAT002', doctor1_uid, lab1_uid, 'Thyroid Panel (TSH, T3, T4)', 'normal', '3-month follow-up', 'approved'),
    ('PAT003', doctor2_uid, lab1_uid, 'Allergy Panel', 'normal', 'Identify allergens', 'completed');

-- ── Lab Reports ──────────────────────────────────────────
INSERT INTO public.lab_reports (request_id, sha256_hash, stego_image_url, verified, encrypted_by) 
SELECT 
    id, 
    'a3f9c2b8e1d4a7f6c5b3e2d1a9f8c7b6e5d4a3f2c1b9e8d7a6f5c4b3e2d1a9f8',
    'https://placeholder.supabase.co/storage/v1/object/public/lab-reports/sample_report.png',
    true,
    lab1_uid
FROM public.lab_requests WHERE test_type = 'Allergy Panel' LIMIT 1;

-- ── Nurse Logs ───────────────────────────────────────────
INSERT INTO public.nurse_logs (patient_id, nurse_id, action, notes) VALUES
    ('PAT001', nurse1_uid, 'MEDICINE_GIVEN', 'Lisinopril 10mg administered - morning dose'),
    ('PAT001', nurse1_uid, 'MEDICINE_GIVEN', 'Metformin 500mg administered - with breakfast'),
    ('PAT001', nurse1_uid, 'INJECTION_GIVEN', 'Insulin 10 units - subcutaneous'),
    ('PAT002', nurse1_uid, 'MEDICINE_GIVEN', 'Levothyroxine 50mcg - fasting dose'),
    ('PAT002', nurse1_uid, 'TREATMENT_COMPLETED', 'Morning vitals completed. BP 118/75, HR 68');

-- ── Medicine Status ──────────────────────────────────────
INSERT INTO public.medicine_status (prescription_id, status, dispensed_at, pharmacist_id)
SELECT id, 'dispensed', NOW() - INTERVAL '2 days', pharm1_uid
FROM public.prescriptions WHERE status = 'dispensed' LIMIT 1;

-- ── AI Analysis ──────────────────────────────────────────
INSERT INTO public.ai_analysis (patient_id, safety_scores, interactions, overall_recommendation, model_used)
VALUES (
    'PAT001',
    '[
        {"medicine": "Lisinopril 10mg", "safety_percent": 89, "risk_level": "safe", "warnings": [], "recommendation": "Continue as prescribed"},
        {"medicine": "Metformin 500mg", "safety_percent": 92, "risk_level": "safe", "warnings": [], "recommendation": "Safe with current dosage"},
        {"medicine": "Aspirin 75mg", "safety_percent": 68, "risk_level": "warning", "warnings": ["Monitor for GI bleeding with long-term use"], "recommendation": "Take with food"},
        {"medicine": "Amlodipine 5mg", "safety_percent": 91, "risk_level": "safe", "warnings": [], "recommendation": "Monitor blood pressure"},
        {"medicine": "Atorvastatin 20mg", "safety_percent": 88, "risk_level": "safe", "warnings": [], "recommendation": "Take at night for best efficacy"}
    ]'::jsonb,
    ARRAY['Aspirin + Lisinopril: Potential reduction of antihypertensive effect at high aspirin doses'],
    'Overall prescription is appropriate. Monitor for GI side effects with Aspirin. Annual liver function check recommended for Atorvastatin.',
    'llama3'
);

-- ── Sample Notifications ─────────────────────────────────
INSERT INTO public.notifications (user_id, type, message, metadata) VALUES
    (patient1_uid, 'lab_request', 'Dr. Smith has requested an HbA1c test. Please approve or reject.',
     '{"request_id": "placeholder", "doctor_id": "placeholder", "test_type": "HbA1c"}'::jsonb),
    (patient1_uid, 'report_uploaded', 'Your lab report is ready. Results have been encrypted and secured.',
     '{"report_type": "Allergy Panel"}'::jsonb),
    (patient1_uid, 'prescription_generated', 'New prescription issued by Dr. Smith. Visit pharmacy to collect.',
     '{"medicines": ["Lisinopril 10mg", "Metformin 500mg"]}'::jsonb);

-- ── Sample Access Logs ───────────────────────────────────
INSERT INTO public.access_logs (accessor_id, patient_id, action, is_honeypot, severity) VALUES
    (doctor1_uid, 'PAT001', 'VIEW_PATIENT', false, 'INFO'),
    (patient1_uid, 'PAT001', 'VIEW_DASHBOARD', false, 'INFO'),
    (nurse1_uid, 'PAT001', 'VIEW_TREATMENT', false, 'INFO'),
    (patient1_uid, 'PAT001', 'VIEW_PRESCRIPTIONS', false, 'INFO'),
    (pharm1_uid, 'PAT001', 'SCAN_QR', false, 'INFO');

END $$;
