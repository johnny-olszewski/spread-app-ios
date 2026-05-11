import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * delete-user
 *
 * Authenticated Edge Function that hard-deletes the calling user's account
 * and all cascade-deleted data.
 *
 * The caller must supply a valid Bearer JWT in the Authorization header.
 * The function verifies the JWT using the service-role client, extracts the
 * user ID, and calls `auth.admin.deleteUser` which cascades deletes on all
 * RLS-protected tables via the foreign-key constraint on `auth.users`.
 *
 * Returns:
 *   200 { "success": true }  — user deleted
 *   401 { "error": "..." }   — missing or invalid JWT
 *   500 { "error": "..." }   — unexpected server error
 */
Deno.serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  };

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders, status: 204 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Missing Authorization header" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: "Server configuration error" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }

  // Create a user-context client to verify the JWT and extract the user ID.
  const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: userError } = await userClient.auth.getUser();

  if (userError || !user) {
    return new Response(
      JSON.stringify({ error: "Invalid or expired token" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
    );
  }

  // Use the service-role client to hard-delete the user.
  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);

  if (deleteError) {
    console.error("delete-user: failed to delete user", deleteError.message);
    return new Response(
      JSON.stringify({ error: "Failed to delete account" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }

  console.log("delete-user: deleted user", user.id);
  return new Response(
    JSON.stringify({ success: true }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
  );
});
