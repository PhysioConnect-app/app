-- Add image_urls column to store_products to support multiple images per product.
-- The legacy image_url column is kept for backward-compat; image_url is always
-- kept in sync with image_urls[0] by the application layer.

ALTER TABLE public.store_products
  ADD COLUMN IF NOT EXISTS image_urls text[] NOT NULL DEFAULT '{}';
