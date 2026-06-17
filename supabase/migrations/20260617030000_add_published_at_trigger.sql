-- ============================================================
-- Auto-set published_at when status transitions draft → published
-- on store_categories and store_products.
-- Leaves published_at unchanged on any other update.
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_published_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.status = 'draft' AND NEW.status = 'published' THEN
    NEW.published_at = now();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_categories_published_at
BEFORE UPDATE OF status ON public.store_categories
FOR EACH ROW EXECUTE FUNCTION public.set_published_at();

CREATE TRIGGER trg_products_published_at
BEFORE UPDATE OF status ON public.store_products
FOR EACH ROW EXECUTE FUNCTION public.set_published_at();
