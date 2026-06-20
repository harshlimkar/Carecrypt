-- ============================================================
-- CareCrypt Supabase PostgreSQL Schema
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- USERS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('patient', 'doctor', 'lab', 'pharmacist', 'nurse')),
    display_name TEXT NOT NULL,
    public_key TEXT,           -- Ed25519 public key (base64)
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PATIENTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id TEXT UNIQUE NOT NULL,  -- e.g. PAT001
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    full_name TEXT,
    date_of_birth DATE,
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    blood_type TEXT,
    allergies TEXT,
    emergency_contact TEXT,
    avatar_url TEXT,
    heart_rate INTEGER DEFAULT 72,
    blood_pressure TEXT DEFAULT '120/80',
    blood_glucose DECIMAL DEFAULT 96.0,
    health_status TEXT DEFAULT 'Stable',
    encrypted_medical_history TEXT,   -- AES-256-GCM encrypted
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- DIAGNOSIS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.diagnosis (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id TEXT NOT NULL,
    doctor_id UUID REFERENCES public.users(id),
    diagnosis TEXT NOT NULL,
    encrypted_diagnosis TEXT,        -- AES-256-GCM encrypted
    notes TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'chronic')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PRESCRIPTIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.prescriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id TEXT NOT NULL,
    doctor_id UUID REFERENCES public.users(id),
    medicines TEXT[] NOT NULL DEFAULT '{}',
    instructions TEXT,
    encrypted_rx TEXT,               -- AES-256-GCM encrypted payload
    ed25519_signature TEXT,          -- Doctor's Ed25519 signature
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'dispensed', 'completed', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- LAB REQUESTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.lab_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id TEXT NOT NULL,
    doctor_id UUID REFERENCES public.users(id),
    lab_id UUID REFERENCES public.users(id),
    test_type TEXT NOT NULL,
    urgency TEXT DEFAULT 'normal' CHECK (urgency IN ('normal', 'urgent', 'stat')),
    notes TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- LAB REPORTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.lab_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID REFERENCES public.lab_requests(id) ON DELETE CASCADE,
    encrypted_report TEXT,           -- AES-256-GCM ciphertext (JSON)
    sha256_hash TEXT NOT NULL,       -- SHA-256 of original report
    stego_image_url TEXT,            -- Supabase Storage URL of stego image
    encrypted_by UUID REFERENCES public.users(id),
    verified BOOLEAN DEFAULT FALSE,
    verification_key_alias TEXT,     -- Key alias for decryption
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MEDICINE STATUS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.medicine_status (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prescription_id UUID REFERENCES public.prescriptions(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'dispensed', 'completed')),
    dispensed_at TIMESTAMPTZ,
    pharmacist_id UUID REFERENCES public.users(id),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- NURSE LOGS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.nurse_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id TEXT NOT NULL,
    nurse_id UUID REFERENCES public.users(id),
    action TEXT NOT NULL,            -- e.g. MEDICINE_GIVEN, INJECTION_GIVEN, TREATMENT_COMPLETED
    notes TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- NOTIFICATIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,              -- lab_request, report_uploaded, prescription_generated, etc.
    message TEXT NOT NULL,
    read BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ACCESS LOGS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.access_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    accessor_id UUID REFERENCES public.users(id),
    patient_id TEXT NOT NULL,
    action TEXT NOT NULL,
    ip_address TEXT,
    is_honeypot BOOLEAN DEFAULT FALSE,
    severity TEXT DEFAULT 'INFO' CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    metadata JSONB DEFAULT '{}',
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AI ANALYSIS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ai_analysis (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prescription_id UUID REFERENCES public.prescriptions(id),
    patient_id TEXT,
    safety_scores JSONB DEFAULT '[]',   -- Array of {medicine, safety_percent, risk_level, warnings, recommendation}
    interactions TEXT[] DEFAULT '{}',
    duplicates TEXT[] DEFAULT '{}',
    allergy_conflicts TEXT[] DEFAULT '{}',
    overall_recommendation TEXT,
    model_used TEXT DEFAULT 'llama3',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_diagnosis_patient ON public.diagnosis(patient_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_patient ON public.prescriptions(patient_id);
CREATE INDEX IF NOT EXISTS idx_lab_requests_patient ON public.lab_requests(patient_id);
CREATE INDEX IF NOT EXISTS idx_lab_requests_status ON public.lab_requests(status);
CREATE INDEX IF NOT EXISTS idx_nurse_logs_patient ON public.nurse_logs(patient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, read);
CREATE INDEX IF NOT EXISTS idx_access_logs_patient ON public.access_logs(patient_id);
CREATE INDEX IF NOT EXISTS idx_access_logs_honeypot ON public.access_logs(is_honeypot) WHERE is_honeypot = TRUE;

-- ============================================================
-- STORED FUNCTIONS
-- ============================================================

-- Notify users by patient_id
CREATE OR REPLACE FUNCTION notify_user_by_patient_id(
    p_patient_id TEXT,
    p_type TEXT,
    p_message TEXT,
    p_metadata JSONB DEFAULT '{}'
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    SELECT user_id INTO v_user_id FROM public.patients WHERE patient_id = p_patient_id;
    IF v_user_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, type, message, metadata)
        VALUES (v_user_id, p_type, p_message, p_metadata);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Notify lab request approved
CREATE OR REPLACE FUNCTION notify_lab_request_approved(
    request_id UUID,
    patient_id TEXT
) RETURNS VOID AS $$
BEGIN
    -- Notify lab technicians
    INSERT INTO public.notifications (user_id, type, message, metadata)
    SELECT id, 'lab_approved', 'Lab request approved. Patient ready for testing.', 
           jsonb_build_object('request_id', request_id, 'patient_id', patient_id)
    FROM public.users WHERE role = 'lab';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Notify security admins (honeypatient access)
CREATE OR REPLACE FUNCTION notify_security_admins(
    alert_type TEXT,
    accessor_id UUID,
    patient_id TEXT,
    severity TEXT,
    message TEXT
) RETURNS VOID AS $$
BEGIN
    -- In production: integrate with PagerDuty / SIEM
    -- For now, log to access_logs and notify all doctors
    INSERT INTO public.notifications (user_id, type, message, metadata)
    SELECT id, 'security_alert', message,
           jsonb_build_object('alert_type', alert_type, 'accessor_id', accessor_id, 'patient_id', patient_id, 'severity', severity)
    FROM public.users WHERE role = 'doctor';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diagnosis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.access_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nurse_logs ENABLE ROW LEVEL SECURITY;

-- Patients can view their own records
CREATE POLICY patient_own_data ON public.patients
    FOR SELECT USING (user_id = auth.uid());

-- Doctors can view all non-honeypot patient records
CREATE POLICY doctor_view_patients ON public.patients
    FOR SELECT USING (
        EXISTS(SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('doctor', 'nurse', 'lab', 'pharmacist'))
        AND patient_id NOT LIKE 'PAT-HONEYPOT%'
    );

-- Users can only see their own notifications
CREATE POLICY own_notifications ON public.notifications
    FOR ALL USING (user_id = auth.uid());

-- Access logs visible to patient (own) and doctors/admin
CREATE POLICY access_logs_visibility ON public.access_logs
    FOR SELECT USING (
        patient_id IN (SELECT patient_id FROM public.patients WHERE user_id = auth.uid())
        OR EXISTS(SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'doctor')
    );
