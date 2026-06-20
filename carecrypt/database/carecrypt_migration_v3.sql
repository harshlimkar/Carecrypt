-- ============================================================
-- CareCrypt Database Migration
-- Adds: new lab_reports columns, access_logs table
-- Run in Supabase SQL Editor
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- 1. Update lab_reports table
--    Add new columns for PostgreSQL-based encrypted storage
--    (replaces Supabase Storage bucket dependency)
-- ──────────────────────────────────────────────────────────
ALTER TABLE lab_reports
  ADD COLUMN IF NOT EXISTS patient_id         TEXT,
  ADD COLUMN IF NOT EXISTS encrypted_content  TEXT,        -- AES-256-GCM encrypted report JSON
  ADD COLUMN IF NOT EXISTS stego_image_b64    TEXT,        -- Base64 LSB-stego image (hidden in pixels)
  ADD COLUMN IF NOT EXISTS key_alias          TEXT,        -- Key alias used for encryption (client-side lookup)
  ADD COLUMN IF NOT EXISTS report_metadata    TEXT;        -- Unencrypted display metadata (test name, date, etc.)

-- ──────────────────────────────────────────────────────────
-- 2. Create access_logs table
--    Stores NFC and QR scan audit trails
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS access_logs (
  id               TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  access_type      TEXT NOT NULL,                          -- 'nfc_session' | 'qr_scan'
  patient_id       TEXT NOT NULL,
  accessed_by      TEXT NOT NULL,                          -- User ID of the accessor
  role             TEXT NOT NULL,                          -- 'doctor' | 'nurse' | 'pharmacy'
  records_viewed   TEXT[] DEFAULT '{}',                   -- Sections accessed
  records_modified TEXT[] DEFAULT '{}',                   -- Sections written
  start_time       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_time         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status           TEXT DEFAULT 'completed',              -- 'completed' | 'failed'
  metadata         JSONB DEFAULT '{}',
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast patient log queries
CREATE INDEX IF NOT EXISTS idx_access_logs_patient_id ON access_logs(patient_id);
CREATE INDEX IF NOT EXISTS idx_access_logs_accessed_by ON access_logs(accessed_by);
CREATE INDEX IF NOT EXISTS idx_access_logs_created_at ON access_logs(created_at DESC);

-- ──────────────────────────────────────────────────────────
-- 3. Row-Level Security for access_logs
-- ──────────────────────────────────────────────────────────
ALTER TABLE access_logs ENABLE ROW LEVEL SECURITY;

-- Patients can view their own access logs
CREATE POLICY "Patients can view own access logs"
  ON access_logs FOR SELECT
  USING (
    patient_id = (
      SELECT patient_id FROM patients WHERE user_id = auth.uid() LIMIT 1
    )
  );

-- Any authenticated user can insert (for NFC/QR logging from app)
CREATE POLICY "Authenticated users can insert access logs"
  ON access_logs FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- ──────────────────────────────────────────────────────────
-- 4. RLS for lab_reports (update to allow new columns)
-- ──────────────────────────────────────────────────────────
-- Patients can view their own lab reports
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'lab_reports' AND policyname = 'Patients view own lab reports'
  ) THEN
    CREATE POLICY "Patients view own lab reports"
      ON lab_reports FOR SELECT
      USING (
        patient_id = (
          SELECT patient_id FROM patients WHERE user_id = auth.uid() LIMIT 1
        )
      );
  END IF;
END $$;

-- ──────────────────────────────────────────────────────────
-- 5. Verify changes
-- ──────────────────────────────────────────────────────────
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'lab_reports'
ORDER BY ordinal_position;

SELECT table_name FROM information_schema.tables
WHERE table_name IN ('access_logs', 'lab_reports');
