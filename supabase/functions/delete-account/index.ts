import { createClient } from "npm:@supabase/supabase-js@2";

// 使用者刪除自己的雲端帳號。不接受請求傳入的 user ID，一律以驗證過的 token 決定帳號；
// user_documents 以外鍵 cascade 一起刪除。service_role key 只存在這個伺服器環境。
Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return new Response(null, { status: 401 });

  const url = Deno.env.get("SUPABASE_URL");
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY");
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !publicKey || !secret) return new Response(null, { status: 503 });

  const auth = createClient(url, publicKey, { auth: { persistSession: false } });
  const { data: { user }, error } = await auth.auth.getUser(authorization.slice(7));
  if (error || !user) return new Response(null, { status: 401 });

  const admin = createClient(url, secret, { auth: { persistSession: false } });
  const { error: deletionError } = await admin.auth.admin.deleteUser(user.id);
  if (deletionError) return new Response(null, { status: 500 });
  return Response.json({ deleted: true }, { headers: { "Cache-Control": "no-store" } });
});
