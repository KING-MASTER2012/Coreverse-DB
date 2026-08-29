// POST   /teams                                  -> create team (caller becomes owner)
// PATCH  /teams/{teamId}                          -> rename team (owner only)
// DELETE /teams/{teamId}                          -> delete team (owner only)
// GET    /teams/{teamId}/members                  -> list members
// POST   /teams/{teamId}/members/{userId}         -> { action: promote|demote|remove }
// POST   /teams/{teamId}/join-requests            -> request to join
// POST   /teams/{teamId}/invites                  -> { user_id } (owner/admin only)
// POST   /teams/{teamId}/ownership-transfer       -> { user_id } (owner only, target consents)
// POST   /teams/{teamId}/leave                    -> leave team (owner cannot)
//
// All authorization (who's the owner/admin, capacity, consent) is enforced
// inside the Postgres functions themselves via auth.uid() -- this handler
// only validates request shape and forwards the caller's JWT.

import { serve } from "@std/http/server";
import { createUserClient } from "../_shared/supabase-client.ts";
import { errorResponse, jsonResponse, statusForPgError } from "../_shared/http.ts";
import {
  CreateTeamSchema,
  InviteSchema,
  MemberActionSchema,
  OwnershipTransferSchema,
  RenameTeamSchema,
  UuidSchema,
} from "./schemas.ts";

serve(async (req) => {
  const url = new URL(req.url);
  const segments = url.pathname
    .replace(/^\/functions\/v1\/teams\/?/, "")
    .split("/")
    .filter(Boolean);

  const supabase = createUserClient(req);

  try {
    // POST /teams
    if (segments.length === 0 && req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const parsed = CreateTeamSchema.safeParse(body);
      if (!parsed.success) return errorResponse("invalid_body", parsed.error.message, 400);

      const { data, error } = await supabase
        .schema("identity")
        .rpc("create_team", { p_name: parsed.data.name });

      if (error) return errorResponse("rpc_error", error.message, statusForPgError(error.code));
      return jsonResponse({ id: data }, 201);
    }

    const teamIdParsed = segments.length >= 1 ? UuidSchema.safeParse(segments[0]) : null;
    if (segments.length >= 1 && (!teamIdParsed || !teamIdParsed.success)) {
      return errorResponse("invalid_team_id", `"${segments[0]}" is not a valid UUID.`, 400);
    }
    const teamId = teamIdParsed?.data;

    // PATCH/DELETE /teams/{teamId}
    if (segments.length === 1 && req.method === "PATCH") {
      const body = await req.json().catch(() => ({}));
      const parsed = RenameTeamSchema.safeParse(body);
      if (!parsed.success) return errorResponse("invalid_body", parsed.error.message, 400);

      const { error } = await supabase
        .schema("identity")
        .rpc("rename_team", { p_team_id: teamId, p_name: parsed.data.name });

      if (error) return errorResponse("rpc_error", error.message, statusForPgError(error.code));
      return jsonResponse({ ok: true });
    }

    if (segments.length === 1 && req.method === "DELETE") {
      const { error } = await supabase
        .schema("identity")
        .rpc("delete_team", { p_team_id: teamId });

      if (error) return errorResponse("rpc_error", error.message, statusForPgError(error.code));
      return new Response(null, { status: 204 });
    }

    // GET /teams/{teamId}/members
    if (segments.length === 2 && segments[1] === "members" && req.method === "GET") {
      const { data, error } = await supabase
        .schema("identity")
        .from("team_members")
        .select("user_id, role, joined_at")
        .eq("team_id", teamId);

      if (error) return errorResponse("query_error", error.message, 500);
      return jsonResponse(data);
    }

    // POST /teams/{teamId}/members/{userId}
    if (segments.length === 3 && segments[1] === "members" && req.method === "POST") {
      const targetParsed = UuidSchema.safeParse(segments[2]);
      if (!targetParsed.success) {
        return errorResponse("invalid_user_id", `"${segments[2]}" is not a valid UUID.`, 400);
      }

      const body = await req.json().catch(() => ({}));
      const parsed = MemberActionSchema.safeParse(body);
      if (!parsed.success) return errorResponse("invalid_body", parsed.error.message, 400);

      const rpcName = {
        promote: "promote_to_admin",
        demote: "demote_to_member",
        remove: "remove_member",
      }[parsed.data.action];

      const { error } = await supabase
        .schema("identity")
        .rpc(rpcName, { p_team_id: teamId, p_target: targetParsed.data });

      if (error) return errorResponse("rpc_error", error.message, statusForPgError(error.code));
      return jsonResponse({ ok: true });
    }

    // POST /teams/{teamId}/join-requests
    if (segments.length === 2 && segments[1] === "join-requests" && req.method === "POST") {
      const { data, error } = await supabase
        .schema("identity")
        .rpc("request_to_join", { p_team_id: teamId });

      if (error) return errorResponse("rpc_error", error.message, statusForPgError(error.code));
      return jsonResponse({ id: data }, 201);
    }

    // POST /teams/{teamId}/invites
    if (segments.length === 2 && segments[1] === "invites" && req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const parsed = InviteSchema.safeParse(body);
      if (!parsed.success) return errorResponse("invalid_body", parsed.error.message, 400);

      const { data, error } = await supabase
        .schema("identity")
        .rpc("invite_to_team", { p_team_id: teamId, p_user_id: parsed.data.user_id });

      if (error) return errorResponse("rpc_error", error.message, statusForPgError(error.code));
      return jsonResponse({ id: data }, 201);
    }

    // POST /teams/{teamId}/ownership-transfer
    if (segments.length === 2 && segments[1] === "ownership-transfer" && req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const parsed = OwnershipTransferSchema.safeParse(body);
      if (!parsed.success) return errorResponse("invalid_body", parsed.error.message, 400);

      const { data, error } = await supabase
        .schema("identity")
        .rpc("offer_ownership", { p_team_id: teamId, p_user_id: parsed.data.user_id });

      if (error) return errorResponse("rpc_error", error.message, statusForPgError(error.code));
      return jsonResponse({ id: data }, 201);
    }

    // POST /teams/{teamId}/leave
    if (segments.length === 2 && segments[1] === "leave" && req.method === "POST") {
      const { error } = await supabase
        .schema("identity")
        .rpc("leave_team", { p_team_id: teamId });

      if (error) return errorResponse("rpc_error", error.message, statusForPgError(error.code));
      return new Response(null, { status: 204 });
    }

    return errorResponse("not_found", "Unknown teams route.", 404);
  } catch (err) {
    return errorResponse(
      "internal_error",
      err instanceof Error ? err.message : "Unexpected error.",
      500,
    );
  }
});
