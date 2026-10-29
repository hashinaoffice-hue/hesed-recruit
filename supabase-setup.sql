-- 헤세드 채용공고 편집기 · Supabase 저장소 설정
-- 사용법: Supabase 대시보드 > SQL Editor > New query 에 이 파일 전체를 붙여넣고,
--         아래 [매장 비밀번호] 한 곳만 원하는 값으로 바꾼 뒤 Run 을 누르세요.
-- 표는 브라우저에서 직접 열 수 없게 잠그고(RLS), 비밀번호를 확인하는 함수로만 읽고 씁니다.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.app_settings (
  id int primary key default 1 check (id = 1),
  pin_hash text not null
);
create table if not exists public.posts (
  id text primary key,
  title text not null default '',
  doc jsonb not null,
  created_at bigint,
  updated_at bigint,
  updated_by text
);
create table if not exists public.images (
  id text primary key,
  data text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.locks (
  post_id text primary key,
  holder text not null,
  holder_name text not null default '',
  expires_at timestamptz not null
);

alter table public.app_settings enable row level security;
alter table public.posts enable row level security;
alter table public.images enable row level security;
alter table public.locks enable row level security;

-- ▼▼▼ [매장 비밀번호] 'hesed-1234' 를 직원들과 나눌 비밀번호로 바꾸세요 (6자 이상 권장) ▼▼▼
insert into public.app_settings (id, pin_hash)
values (1, extensions.crypt('hesed-1234', extensions.gen_salt('bf')))
on conflict (id) do update set pin_hash = excluded.pin_hash;
-- ▲▲▲ 비밀번호를 바꾸고 싶을 때는 이 문장만 다시 실행하면 됩니다 ▲▲▲

create or replace function public._check_pin(p_pin text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if p_pin is null or not exists (select 1 from app_settings where id = 1 and pin_hash = crypt(p_pin, pin_hash)) then
    raise exception 'wrong_pin';
  end if;
end $$;

create or replace function public.check_pin(p_pin text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  return exists (select 1 from app_settings where id = 1 and pin_hash = crypt(p_pin, pin_hash));
end $$;

create or replace function public.list_posts(p_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_pin(p_pin);
  return coalesce((select json_agg(json_build_object('id', id, 'title', title, 'createdAt', created_at, 'updatedAt', updated_at, 'updatedBy', updated_by)
    order by updated_at desc nulls last) from posts), '[]'::json);
end $$;

create or replace function public.get_post(p_pin text, p_id text) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_pin(p_pin);
  return (select json_build_object('title', title, 'doc', doc, 'createdAt', created_at, 'updatedAt', updated_at, 'updatedBy', updated_by) from posts where id = p_id);
end $$;

create or replace function public.save_post(p_pin text, p_id text, p_title text, p_doc jsonb, p_by text, p_created bigint, p_updated bigint) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_pin(p_pin);
  insert into posts (id, title, doc, created_at, updated_at, updated_by)
  values (p_id, coalesce(p_title, ''), p_doc, p_created, p_updated, p_by)
  on conflict (id) do update set title = excluded.title, doc = excluded.doc, updated_at = excluded.updated_at, updated_by = excluded.updated_by;
end $$;

create or replace function public.delete_post(p_pin text, p_id text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_pin(p_pin);
  delete from posts where id = p_id;
  delete from locks where post_id = p_id;
end $$;

-- 한 공고를 한 사람만 편집하도록 짧게 잠근다 (같은 기기는 다시 잡을 수 있음)
create or replace function public.acquire_lock(p_pin text, p_post text, p_holder text, p_name text, p_ttl int) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare cur locks%rowtype;
begin
  perform _check_pin(p_pin);
  select * into cur from locks where post_id = p_post for update;
  if found and cur.holder <> p_holder and cur.expires_at > now() then
    return json_build_object('acquired', false, 'name', cur.holder_name);
  end if;
  insert into locks (post_id, holder, holder_name, expires_at)
  values (p_post, p_holder, coalesce(p_name, ''), now() + make_interval(secs => greatest(10, least(p_ttl, 600))))
  on conflict (post_id) do update set holder = excluded.holder, holder_name = excluded.holder_name, expires_at = excluded.expires_at;
  return json_build_object('acquired', true);
end $$;

create or replace function public.put_image(p_pin text, p_id text, p_data text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_pin(p_pin);
  insert into images (id, data) values (p_id, p_data) on conflict (id) do nothing;
end $$;

create or replace function public.get_image(p_pin text, p_id text) returns text
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_pin(p_pin);
  return (select data from images where id = p_id);
end $$;

revoke all on function public._check_pin(text) from public, anon, authenticated;
grant execute on function public.check_pin(text), public.list_posts(text), public.get_post(text, text),
  public.save_post(text, text, text, jsonb, text, bigint, bigint), public.delete_post(text, text),
  public.acquire_lock(text, text, text, text, int), public.put_image(text, text, text), public.get_image(text, text)
  to anon, authenticated;
