-- Add appointment_id to invoices so attended sessions can be linked back
ALTER TABLE invoices
  ADD COLUMN IF NOT EXISTS appointment_id uuid REFERENCES appointments(id) ON DELETE SET NULL;

-- Index for fast lookup by appointment
CREATE INDEX IF NOT EXISTS idx_invoices_appointment_id
  ON invoices (appointment_id);

-- No enum change needed — status is stored as text; 'awaiting_review' is
-- accepted by the existing text column automatically.
-- If you have a CHECK constraint on status, add 'awaiting_review' to it:
-- ALTER TABLE invoices
--   DROP CONSTRAINT IF EXISTS invoices_status_check;
-- ALTER TABLE invoices
--   ADD CONSTRAINT invoices_status_check
--   CHECK (status IN (
--     'pending', 'paid', 'partially_paid',
--     'insurance_claim', 'cancelled', 'awaiting_review'
--   ));
