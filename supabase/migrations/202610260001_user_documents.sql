-- PackSmart 使用者資料：每趟行程（含打包清單）或每個常備用品一列 JSON。
-- 擁有者一律取自登入身分（auth.uid()），不接受用戶端傳入。PD-062、docs/supabase-plan.md。

create table public.user_documents (
  owner_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('trip', 'library')),
  id uuid not null,
  revision bigint not null check (revision > 0),
  payload jsonb,
  deleted boolean not null default false,
  mutation_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, kind, id),
  -- 刪除時只留 tombstone；否則 payload 必須是對應 kind 的 version 1 文件，且 ID 一致。
  constraint document_shape check (coalesce(
    (deleted and payload is null) or
    (not deleted
      and jsonb_typeof(payload) = 'object'
      and payload->>'version' = '1'
      and octet_length(payload::text) <= 1048576
      and ((kind = 'trip' and jsonb_typeof(payload->'trip') = 'object'
              and lower(payload->'trip'->>'id') = id::text
              and coalesce(jsonb_typeof(payload->'trip'->'packingItems'), 'array') = 'array')
        or (kind = 'library' and jsonb_typeof(payload->'library') = 'object'
              and lower(payload->'library'->>'id') = id::text))),
    false)),
  -- 健康類物品（含藥品）只有在使用者另外同意時才能上傳；用戶端忘了剔除也會被擋下。
  constraint health_requires_consent check (
    payload is null
    or coalesce((payload->>'healthSyncConsent')::boolean, false)
    or not (jsonb_path_exists(payload, '$.trip.packingItems[*] ? (@.categoryRaw == "health")')
            or payload->'library'->>'categoryRaw' = 'health'))
);

alter table public.user_documents enable row level security;
revoke all on public.user_documents from public, anon, authenticated;
grant select on public.user_documents to authenticated;
create policy read_own_documents on public.user_documents for select to authenticated
  using (owner_id = (select auth.uid()));

-- 唯一的寫入路徑：比對 revision（compare-and-swap），版本不同就回傳衝突，不會靜默覆蓋。
-- 同一個 mutation_id 重送視為重試，不會重複寫入。
create function public.sync_document(
  p_kind text, p_id uuid, p_expected_revision bigint,
  p_payload jsonb, p_deleted boolean, p_mutation_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  doc public.user_documents;
begin
  if actor is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if p_kind not in ('trip', 'library') or p_id is null or p_mutation_id is null
     or p_expected_revision is null or p_expected_revision < 0 or p_deleted is null then
    raise exception 'invalid mutation' using errcode = '22023';
  end if;

  if p_expected_revision = 0 then
    insert into public.user_documents (owner_id, kind, id, revision, payload, deleted, mutation_id)
    values (actor, p_kind, p_id, 1, p_payload, p_deleted, p_mutation_id)
    on conflict (owner_id, kind, id) do nothing;
  end if;

  select * into doc from public.user_documents
  where owner_id = actor and kind = p_kind and id = p_id
  for update;
  if not found then raise exception 'document missing' using errcode = 'P0002'; end if;

  if doc.mutation_id = p_mutation_id then
    if doc.payload is distinct from p_payload or doc.deleted is distinct from p_deleted then
      raise exception 'mutation id reused with different content' using errcode = '22023';
    end if;
    return jsonb_build_object('status', 'applied', 'document', to_jsonb(doc));
  end if;
  if doc.revision <> p_expected_revision then
    return jsonb_build_object('status', 'conflict', 'document', to_jsonb(doc));
  end if;

  update public.user_documents
  set payload = p_payload, deleted = p_deleted, revision = revision + 1,
      mutation_id = p_mutation_id, updated_at = now()
  where owner_id = actor and kind = p_kind and id = p_id
  returning * into doc;
  return jsonb_build_object('status', 'applied', 'document', to_jsonb(doc));
end;
$$;

revoke all on function public.sync_document(text, uuid, bigint, jsonb, boolean, uuid) from public, anon;
grant execute on function public.sync_document(text, uuid, bigint, jsonb, boolean, uuid) to authenticated;
