import { createClient } from "npm:@supabase/supabase-js@2";

// 管理員刪除某位使用者的帳號。先以管理員自己的 token 呼叫 admin_authorize_user_deletion：
// 資料庫確認管理員名單、MFA 與原因，並寫入稽核紀錄；通過後才用 service_role 刪除 Auth user。
Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return new Response(null, { status: 401 });

  const url = Deno.env.get("SUPABASE_URL");
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY");
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !publicKey || !secret) return new Response(null, { status: 503 });

  const body = await request.json().catch(() => null);
  const target = typeof body?.user_id === "string" ? body.user_id : "";
  const reason = typeof body?.reason === "string" ? body.reason : "";
  if (!target || !reason) return new Response(null, { status: 400 });

  const caller = createClient(url, publicKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });
  const { error: authorizationError } = await caller.rpc("admin_authorize_user_deletion", {
    p_user: target,
    p_reason: reason,
  });
  if (authorizationError) {
    const status = authorizationError.code === "42501" ? 403 : authorizationError.code === "P0002" ? 404 : 400;
    return new Response(null, { status });
  }

  const admin = createClient(url, secret, { auth: { persistSession: false } });
  const { error: deletionError } = await admin.auth.admin.deleteUser(target);
  if (deletionError) return new Response(null, { status: 500 });
  return Response.json({ deleted: true }, { headers: { "Cache-Control": "no-store" } });
});
