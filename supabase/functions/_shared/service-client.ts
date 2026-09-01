import { createClient, } from '@supabase/supabase-js';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL',)!;
// Provided automatically in the Supabase Edge Functions runtime; never
// exposed to clients.
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY',)!;

// Use sparingly and only after the caller's access has already been
// verified with a user-scoped client (createUserClient) against normal
// RLS. This client bypasses RLS entirely.
export function createServiceClient() {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, },
  },);
}
