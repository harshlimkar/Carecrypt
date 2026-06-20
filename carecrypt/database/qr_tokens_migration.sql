-- ============================================================
-- CareCrypt: QR Tokens Migration
-- Run this in Supabase SQL Editor
-- ============================================================

-- One-time QR tokens table
CREATE TABLE IF NOT EXISTS public.qr_tokens (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  token_id    TEXT UNIQUE NOT NULL,
  patient_id  TEXT NOT NULL,
  user_id     UUID REFERENCES public.users(id) ON DELETE CASCADE,
  prescription_id UUID,
  expires_at  TIMESTAMPTZ NOT NULL,
  used        BOOLEAN DEFAULT FALSE,
  used_at     TIMESTAMPTZ,
  used_by     UUID,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.qr_tokens ENABLE ROW LEVEL SECURITY;

-- Patients can create and view their own tokens
CREATE POLICY "Patients manage own tokens"
  ON public.qr_tokens
  FOR ALL
  USING (auth.uid() = user_id);

-- Pharmacists can read any token (to validate)
CREATE POLICY "Pharmacists can read tokens"
  ON public.qr_tokens
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'pharmacist'
    )
  );

-- Pharmacists can update (mark used) any token
CREATE POLICY "Pharmacists can use tokens"
  ON public.qr_tokens
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'pharmacist'
    )
  );

-- Atomic check-and-mark-used function (race-condition safe)
CREATE OR REPLACE FUNCTION public.use_qr_token(p_token_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_token RECORD;
BEGIN
  -- Lock the row for atomic read-modify-write
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
