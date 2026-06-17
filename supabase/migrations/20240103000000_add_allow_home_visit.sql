-- Admin-controlled flag: whether a doctor is allowed to offer home visits
-- and set/update their clinic location. When false, the doctor's own
-- "Offers Home Visits" toggle and "Update My Location" action are disabled.
ALTER TABLE users ADD COLUMN IF NOT EXISTS allow_home_visit boolean NOT NULL DEFAULT true;
