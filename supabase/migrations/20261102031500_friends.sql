-- Order Up! — perfis online e amigos.
-- Colar tudo no Supabase: SQL Editor > New query > Run.
-- As tabelas ficam fechadas (RLS sem regras); o jogo só usa as funções abaixo,
-- e cada perfil prova quem é com um segredo guardado no PC.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 16),
  friend_code text not null unique,
  secret_hash text not null,
  room_code text,
  status text,
  last_seen timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.friends (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, friend_id),
  check (profile_id <> friend_id)
);

alter table public.profiles enable row level security;
alter table public.friends enable row level security;

-- Perfil a partir do segredo (ou erro).
create or replace function public._me(p_secret text) returns public.profiles
language plpgsql security definer set search_path = public as $$
declare me public.profiles;
begin
  select * into me from profiles where secret_hash = encode(digest(p_secret, 'sha256'), 'hex');
  if me.id is null then raise exception 'perfil desconhecido'; end if;
  return me;
end $$;

-- Cria um perfil. Devolve o código de amigo e o segredo (o jogo guarda-o).
create or replace function public.create_profile(p_name text)
returns table(friend_code text, secret text)
language plpgsql security definer set search_path = public as $$
declare v_code text; v_secret text;
begin
  loop
    v_code := upper(substr(translate(encode(gen_random_bytes(8), 'base64'), '+/=0O1Il', ''), 1, 6));
    exit when char_length(v_code) = 6 and not exists (select 1 from profiles p where p.friend_code = v_code);
  end loop;
  v_secret := encode(gen_random_bytes(24), 'hex');
  insert into profiles(name, friend_code, secret_hash)
    values (left(trim(p_name), 16), v_code, encode(digest(v_secret, 'sha256'), 'hex'));
  return query select v_code, v_secret;
end $$;

create or replace function public.rename_profile(p_secret text, p_name text) returns void
language plpgsql security definer set search_path = public as $$
declare me public.profiles := _me(p_secret);
begin
  update profiles set name = left(trim(p_name), 16) where id = me.id;
end $$;

-- Diz que está online (e em que sala, se for host). O jogo chama a cada 30 s.
create or replace function public.heartbeat(p_secret text, p_room text, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare me public.profiles := _me(p_secret);
begin
  update profiles set last_seen = now(), room_code = nullif(p_room, ''), status = left(p_status, 40) where id = me.id;
end $$;

-- Adiciona um amigo pelo código (fica amigo dos dois lados).
create or replace function public.add_friend(p_secret text, p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare me public.profiles := _me(p_secret); other public.profiles;
begin
  select * into other from profiles where friend_code = upper(trim(p_code));
  if other.id is null then raise exception 'código não existe'; end if;
  if other.id = me.id then raise exception 'esse és tu'; end if;
  insert into friends values (me.id, other.id, now()) on conflict do nothing;
  insert into friends values (other.id, me.id, now()) on conflict do nothing;
  return other.name;
end $$;

create or replace function public.remove_friend(p_secret text, p_code text) returns void
language plpgsql security definer set search_path = public as $$
declare me public.profiles := _me(p_secret);
begin
  delete from friends f using profiles p
    where p.friend_code = upper(trim(p_code))
      and ((f.profile_id = me.id and f.friend_id = p.id) or (f.profile_id = p.id and f.friend_id = me.id));
end $$;

-- Lista de amigos: nome, código, se está online (visto há menos de 90 s) e a sala.
create or replace function public.list_friends(p_secret text)
returns table(name text, friend_code text, online boolean, room_code text, status text)
language plpgsql security definer set search_path = public as $$
declare me public.profiles := _me(p_secret);
begin
  return query
    select p.name, p.friend_code, p.last_seen > now() - interval '90 seconds',
      case when p.last_seen > now() - interval '90 seconds' then p.room_code end, p.status
    from friends f join profiles p on p.id = f.friend_id
    where f.profile_id = me.id
    order by 3 desc, 1;
end $$;

revoke all on function public._me(text) from public, anon, authenticated;
grant execute on function public.create_profile(text) to anon;
grant execute on function public.rename_profile(text, text) to anon;
grant execute on function public.heartbeat(text, text, text) to anon;
grant execute on function public.add_friend(text, text) to anon;
grant execute on function public.remove_friend(text, text) to anon;
grant execute on function public.list_friends(text) to anon;
