-- Enable pgTAP for database testing.
-- Supabase convention: install extensions in the "extensions" schema.

create extension if not exists pgtap
with schema extensions;
