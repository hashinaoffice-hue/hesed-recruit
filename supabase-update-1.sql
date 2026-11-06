-- 헤세드 채용공고 편집기 · 저장소 업데이트 1 (공고 잠금 · 이름 바꾸기)
-- 사용법: Supabase 대시보드 > SQL Editor > New query 에 이 파일 전체를 붙여넣고 Run.
-- 매장 비밀번호와 기존 공고는 그대로 둡니다. 여러 번 실행해도 괜찮습니다.

alter table public.posts add column if not exists locked boolean not null default false;

-- 목록에 잠금 여부를 함께 보낸다
create or replace function public.list_posts(p_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_pin(p_pin);
  return coalesce((select json_agg(json_build_object('id', id, 'title', title, 'createdAt', created_at, 'updatedAt', updated_at, 'updatedBy', updated_by, 'locked', locked)
    order by updated_at desc nulls last) from posts), '[]'::json);
end $$;

-- 잠긴 공고는 저장소에서 삭제를 거절한다
create or replace function public.delete_post(p_pin text, p_id text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_pin(p_pin);
  if exists (select 1 from posts where id = p_id and locked) then
    raise exception 'post_locked';
  end if;
  delete from posts where id = p_id;
  delete from locks where post_id = p_id;
end $$;

create or replace function public.set_post_locked(p_pin text, p_id text, p_locked boolean) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_pin(p_pin);
  update posts set locked = coalesce(p_locked, false) where id = p_id;
end $$;

create or replace function public.rename_post(p_pin text, p_id text, p_title text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _check_pin(p_pin);
  if coalesce(trim(p_title), '') = '' then raise exception 'empty_title'; end if;
  update posts set title = left(trim(p_title), 60) where id = p_id;
end $$;

grant execute on function public.set_post_locked(text, text, boolean), public.rename_post(text, text, text) to anon, authenticated;
