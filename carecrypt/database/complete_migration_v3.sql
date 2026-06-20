-- =============================================================================
-- CARECRYPT CONSOLIDATED MIGRATION (ROUND 3)
-- Copy and run this entire script in the Supabase SQL Editor:
-- https://supabase.com/dashboard/project/rucxpxxqujwgriknnxbh/sql/new
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. UPDATE lab_reports TABLE (PostgreSQL Encrypted Storage Fallback)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.lab_reports
  ADD COLUMN IF NOT EXISTS patient_id          TEXT,
  ADD COLUMN IF NOT EXISTS encrypted_content   TEXT,        -- AES-256-GCM encrypted report JSON
  ADD COLUMN IF NOT EXISTS stego_image_b64     TEXT,        -- Base64 LSB-stego image
  ADD COLUMN IF NOT EXISTS key_alias           TEXT,        -- Key alias used for encryption
  ADD COLUMN IF NOT EXISTS report_metadata     TEXT;        -- Unencrypted display metadata

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. CREATE access_logs TABLE (NFC & QR Audit Logging)
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS public.access_logs CASCADE;

CREATE TABLE public.access_logs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  accessor_id      UUID REFERENCES public.users(id) ON DELETE SET NULL, -- OLD (backward compatibility)
  patient_id       TEXT NOT NULL,
  action           TEXT NOT NULL DEFAULT 'ACCESS',                       -- OLD (backward compatibility)
  ip_address       TEXT,                                                 -- OLD (backward compatibility)
  is_honeypot      BOOLEAN DEFAULT FALSE,                                -- OLD (backward compatibility)
  severity         TEXT DEFAULT 'INFO',                                  -- OLD (backward compatibility)
  timestamp        TIMESTAMPTZ DEFAULT NOW(),                            -- OLD (backward compatibility)
  
  -- New audit log columns
  access_type      TEXT,                                                 -- 'nfc_session' | 'qr_scan'
  accessed_by      TEXT,                                                 -- User ID of doctor/nurse/pharmacist
  role             TEXT,                                                 -- 'doctor' | 'nurse' | 'pharmacy'
  records_viewed   TEXT[] DEFAULT '{}',
  records_modified TEXT[] DEFAULT '{}',
  start_time       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_time         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status           TEXT DEFAULT 'completed',                             -- 'completed' | 'failed' | 'dispensed' | etc.
  metadata         JSONB DEFAULT '{}',
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_access_logs_patient_id ON public.access_logs(patient_id);
CREATE INDEX IF NOT EXISTS idx_access_logs_accessed_by ON public.access_logs(accessed_by);
CREATE INDEX IF NOT EXISTS idx_access_logs_created_at ON public.access_logs(created_at DESC);

ALTER TABLE public.access_logs ENABLE ROW LEVEL SECURITY;

-- Security Policies for access_logs
DROP POLICY IF EXISTS "Patients can view own access logs" ON public.access_logs;
CREATE POLICY "Patients can view own access logs"
  ON public.access_logs FOR SELECT
  USING (
    patient_id = (
      SELECT patient_id FROM public.patients WHERE user_id = auth.uid() LIMIT 1
    )
  );

DROP POLICY IF EXISTS "Authenticated users can insert access logs" ON public.access_logs;
CREATE POLICY "Authenticated users can insert access logs"
  ON public.access_logs FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- RLS Policy for lab_reports
DROP POLICY IF EXISTS "Patients view own lab reports" ON public.lab_reports;
CREATE POLICY "Patients view own lab reports"
  ON public.lab_reports FOR SELECT
  USING (
    patient_id = (
      SELECT patient_id FROM public.patients WHERE user_id = auth.uid() LIMIT 1
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. CREATE qr_tokens TABLE (One-Time QR Token Verification)
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS public.qr_tokens CASCADE;

CREATE TABLE public.qr_tokens (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  token_id        TEXT UNIQUE NOT NULL,
  patient_id      TEXT NOT NULL,
  user_id         UUID REFERENCES public.users(id) ON DELETE CASCADE,
  prescription_id UUID,
  expires_at      TIMESTAMPTZ NOT NULL,
  used            BOOLEAN DEFAULT FALSE,
  used_at         TIMESTAMPTZ,
  used_by         UUID,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.qr_tokens ENABLE ROW LEVEL SECURITY;

-- Security Policies for qr_tokens
DROP POLICY IF EXISTS "Patients manage own tokens" ON public.qr_tokens;
CREATE POLICY "Patients manage own tokens"
  ON public.qr_tokens FOR ALL
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Pharmacists can read tokens" ON public.qr_tokens;
CREATE POLICY "Pharmacists can read tokens"
  ON public.qr_tokens FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'pharmacist'
    )
  );

DROP POLICY IF EXISTS "Pharmacists can use tokens" ON public.qr_tokens;
CREATE POLICY "Pharmacists can use tokens"
  ON public.qr_tokens FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'pharmacist'
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. ATOMIC TOKEN USE FUNCTION (use_qr_token Stored Procedure)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.use_qr_token(p_token_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_token RECORD;
BEGIN
  -- Lock token row atomically to prevent race conditions
  SELECT * INTO v_token
  FROM public.qr_tokens
  WHERE token_id = p_token_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'QR code not found or invalid');
  END IF;

  IF v_token.used THEN
    RETURN jsonb_build_object('success', false, 'error', 'QR Already Used — This QR code has already been scanned');
  END IF;

  IF v_token.expires_at < NOW() THEN
    RETURN jsonb_build_object('success', false, 'error', 'QR Expired — Please ask patient to generate a new QR code');
  END IF;

  -- Mark as used atomically
  UPDATE public.qr_tokens
  SET
    used      = TRUE,
    used_at   = NOW(),
    used_by   = auth.uid()
  WHERE token_id = p_token_id;

  RETURN jsonb_build_object(
    'success',          true,
    'patient_id',       v_token.patient_id,
    'prescription_id',  v_token.prescription_id,
    'user_id',          v_token.user_id
  );
END;
$$;

-- Verify migration columns and tables
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'lab_reports'
ORDER BY ordinal_position;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. DIAGNOSIS FOREIGN KEY RELATIONSHIP (Fixes PGRST200 join relation error)
-- ─────────────────────────────────────────────────────────────────────────────
-- Clean up any orphaned diagnosis records first to prevent constraint violations
DELETE FROM public.diagnosis
WHERE patient_id NOT IN (SELECT patient_id FROM public.patients);

-- Add foreign key constraint to patients(patient_id)
ALTER TABLE public.diagnosis
  DROP CONSTRAINT IF EXISTS fk_diagnosis_patient_id;

ALTER TABLE public.diagnosis
  ADD CONSTRAINT fk_diagnosis_patient_id
  FOREIGN KEY (patient_id)
  REFERENCES public.patients(patient_id)
  ON DELETE CASCADE;
