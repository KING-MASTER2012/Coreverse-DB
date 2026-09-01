// GET   /profiles/me
// PATCH /profiles/me
//
// Both operate on the caller's own row only. GET resolves it via
// supabase.auth.getUser() (reading the forwarded JWT); PATCH goes through
// RLS (profiles_self_update: id = auth.uid()) as a normal PostgREST
// update -- profile writes don't need a SECURITY DEFINER function since
// "can I edit my own row" is a simple RLS predicate, unlike the team
// role/consent logic.

import { serve, } from '@std/http/server';
import { createUserClient, } from '../_shared/supabase-client.ts';
import { errorResponse, jsonResponse, } from '../_shared/http.ts';
import { UpdateProfileSchema, } from './schemas.ts';

function withAvatarUrl(
  supabase: ReturnType<typeof createUserClient>,
  row: { avatar_path: string | null; [key: string]: unknown },
) {
  const { avatar_path, ...rest } = row;
  const avatar_url = avatar_path
    ? supabase.storage.from('avatars',).getPublicUrl(avatar_path,).data.publicUrl
    : null;
  return { ...rest, avatar_url, };
}

serve(async (req,) => {
  const url = new URL(req.url,);
  const path = url.pathname.replace(/^\/functions\/v1\/profiles\/?/, '',);

  if (path !== 'me') {
    return errorResponse('not_found', 'Unknown profiles route.', 404,);
  }

  const supabase = createUserClient(req,);

  try {
    const { data: userData, error: authError, } = await supabase.auth.getUser();
    if (authError || !userData?.user) {
      return errorResponse('unauthorized', 'A valid session is required.', 401,);
    }
    const userId = userData.user.id;

    if (req.method === 'GET') {
      const { data, error, } = await supabase
        .schema('identity',)
        .from('profiles',)
        .select('id, full_name, avatar_path, created_at, updated_at',)
        .eq('id', userId,)
        .maybeSingle();

      if (error) return errorResponse('query_error', error.message, 500,);
      if (!data) return errorResponse('not_found', 'No profile found for this user.', 404,);
      return jsonResponse(withAvatarUrl(supabase, data,),);
    }

    if (req.method === 'PATCH') {
      const body = await req.json().catch(() => ({}));
      const parsed = UpdateProfileSchema.safeParse(body,);
      if (!parsed.success) return errorResponse('invalid_body', parsed.error.message, 400,);

      const { data, error, } = await supabase
        .schema('identity',)
        .from('profiles',)
        .update(parsed.data,)
        .eq('id', userId,)
        .select('id, full_name, avatar_path, created_at, updated_at',)
        .maybeSingle();

      if (error) return errorResponse('query_error', error.message, 500,);
      if (!data) return errorResponse('not_found', 'No profile found for this user.', 404,);
      return jsonResponse(withAvatarUrl(supabase, data,),);
    }

    return errorResponse('method_not_allowed', 'Only GET and PATCH are supported.', 405,);
  } catch (err) {
    return errorResponse(
      'internal_error',
      err instanceof Error ? err.message : 'Unexpected error.',
      500,
    );
  }
},);
