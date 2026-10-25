-- 管理後台：日常支援透過下列函式，以管理員自己的 PackSmart 帳號登入後呼叫，不需要 service_role key。
-- 每個函式都會確認呼叫者在 admin_users 名單、登入時通過 MFA（aal2），並在同一個交易裡寫入稽核紀錄。
-- Dashboard 擁有者仍可直接存取資料表，這部分無法由資料庫阻擋，靠人員限制（docs/supabase-plan.md）。

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'support' check (role in ('support')),
  created_at timestamptz not null default now()
);

-- 稽核紀錄不設外鍵：使用者或管理員刪除帳號後，紀錄仍保留。
create table public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid not null,
  target_user_id uuid,
  action text not null check (action in ('find_user', 'view_documents', 'update_document', 'delete_document', 'delete_user')),
  document_kind text,
  document_id uuid,
  reason text not null check (char_length(btrim(reason)) >= 5),
  created_at timestamptz not null default now()
);

-- 兩張表對 App 完全不開放；只有下面的 security definer 函式能讀寫。
alter table public.admin_users enable row level security;
alter table public.admin_audit_log enable row level security;
revoke all on public.admin_users, public.admin_audit_log from public, anon, authenticated;

create function private.require_admin(p_action text, p_target uuid, p_kind text, p_id uuid, p_reason text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null or not exists (select 1 from public.admin_users where user_id = actor) then
    raise exception 'admin required' using errcode = '42501';
  end if;
  if coalesce(auth.jwt()->>'aal', '') <> 'aal2' then
    raise exception 'mfa required' using errcode = '42501';
  end if;
  if p_reason is null or char_length(btrim(p_reason)) < 5 then
    raise exception 'reason required' using errcode = '22023';
  end if;
  insert into public.admin_audit_log (actor_id, target_user_id, action, document_kind, document_id, reason)
  values (actor, p_target, p_action, p_kind, p_id, btrim(p_reason));
  return actor;
end;
$$;
revoke all on function private.require_admin(text, uuid, text, uuid, text) from public, anon, authenticated;

-- 以 Email 找使用者（處理使用者回報時用）。
create function public.admin_find_user(p_email text, p_reason text)
returns table (user_id uuid, email text, created_at timestamptz, trip_count bigint, library_count bigint)
language plpgsql security definer set search_path = '' as $$
declare
  target uuid;
begin
  select u.id into target from auth.users u where lower(u.email) = lower(btrim(p_email));
  perform private.require_admin('find_user', target, null, null, p_reason);
  return query
    select u.id, u.email::text, u.created_at,
      (select count(*) from public.user_documents d where d.owner_id = u.id and d.kind = 'trip' and not d.deleted),
      (select count(*) from public.user_documents d where d.owner_id = u.id and d.kind = 'library' and not d.deleted)
    from auth.users u where u.id = target;
end;
$$;

-- 查看某位使用者的全部資料（含 tombstone）；查看本身也會留紀錄。
create function public.admin_list_documents(p_user uuid, p_reason text)
returns setof public.user_documents
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin('view_documents', p_user, null, null, p_reason);
  return query select * from public.user_documents where owner_id = p_user order by kind, updated_at desc;
end;
$$;

-- 修改或刪除使用者的一份資料；和 App 一樣比對 revision，避免蓋掉使用者剛同步的版本。
create function public.admin_update_document(
  p_user uuid, p_kind text, p_id uuid, p_expected_revision bigint,
  p_payload jsonb, p_deleted boolean, p_reason text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  doc public.user_documents;
begin
  perform private.require_admin(case when p_deleted then 'delete_document' else 'update_document' end,
    p_user, p_kind, p_id, p_reason);
  select * into doc from public.user_documents
  where owner_id = p_user and kind = p_kind and id = p_id
  for update;
  if not found then raise exception 'document missing' using errcode = 'P0002'; end if;
  if doc.revision <> p_expected_revision then
    return jsonb_build_object('status', 'conflict', 'document', to_jsonb(doc));
  end if;
  update public.user_documents
  set payload = case when p_deleted then null else p_payload end, deleted = p_deleted,
      revision = revision + 1, mutation_id = gen_random_uuid(), updated_at = now()
  where owner_id = p_user and kind = p_kind and id = p_id
  returning * into doc;
  return jsonb_build_object('status', 'applied', 'document', to_jsonb(doc));
end;
$$;

-- 刪除使用者帳號前的授權與紀錄；實際刪除由 admin-delete-user Edge Function 呼叫 Auth Admin API。
-- 不能用這個流程刪除管理員帳號。
create function public.admin_authorize_user_deletion(p_user uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin('delete_user', p_user, null, null, p_reason);
  if not exists (select 1 from auth.users where id = p_user) then
    raise exception 'user missing' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.admin_users where user_id = p_user) then
    raise exception 'cannot delete an admin account' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.admin_find_user(text, text),
  public.admin_list_documents(uuid, text),
  public.admin_update_document(uuid, text, uuid, bigint, jsonb, boolean, text),
  public.admin_authorize_user_deletion(uuid, text)
  from public, anon;
grant execute on function public.admin_find_user(text, text),
  public.admin_list_documents(uuid, text),
  public.admin_update_document(uuid, text, uuid, bigint, jsonb, boolean, text),
  public.admin_authorize_user_deletion(uuid, text)
  to authenticated;
