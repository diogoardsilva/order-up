-- Order Up! — contas online (v2): utilizador + palavra-passe, progresso na conta e amigos.
-- Colar tudo no Supabase: SQL Editor > New query > Run. Pode correr-se mais do que uma vez.
--
-- O que mudou desde a v1: o Supabase guarda o pgcrypto no esquema "extensions",
-- por isso as funções agora procuram lá (era o erro "gen_random_bytes does not exist").
-- As tabelas da v1 (profiles/friends, ainda vazias) são apagadas.
--
-- Segurança: as tabelas ficam fechadas (RLS ligado, sem regras); o jogo só chama
-- as funções ou_* com a chave pública. As palavras-passe ficam com bcrypt e
-- as sessões só guardam o hash do token.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- Limpeza da v1 (só se for mesmo a tabela da v1).
drop function if exists public._me(text);
drop function if exists public.create_profile(text);
drop function if exists public.rename_profile(text, text);
drop function if exists public.heartbeat(text, text, text);
drop function if exists public.add_friend(text, text);
drop function if exists public.remove_friend(text, text);
drop function if exists public.list_friends(text);
do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'profiles' and column_name = 'secret_hash') then
    drop table if exists public.friends cascade;
    drop table public.profiles cascade;
  end if;
end $$;

create table if not exists public.ou_accounts (
  id uuid primary key default gen_random_uuid(),
  username text not null,
  name text not null check (char_length(name) between 1 and 16),
  password_hash text not null,
  friend_code text not null unique,
  progress jsonb not null default '{}'::jsonb,
  room_code text,
  status text,
  last_seen timestamptz not null default now(),
  failed_logins int not null default 0,
  locked_until timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists ou_accounts_username on public.ou_accounts (lower(username));

create table if not exists public.ou_sessions (
  token_hash text primary key,
  account_id uuid not null references public.ou_accounts(id) on delete cascade,
  device text,
  created_at timestamptz not null default now(),
  last_used timestamptz not null default now()
);

create table if not exists public.ou_friends (
  account_id uuid not null references public.ou_accounts(id) on delete cascade,
  friend_id uuid not null references public.ou_accounts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (account_id, friend_id),
  check (account_id <> friend_id)
);

alter table public.ou_accounts enable row level security;
alter table public.ou_sessions enable row level security;
alter table public.ou_friends enable row level security;
revoke all on public.ou_accounts, public.ou_sessions, public.ou_friends from anon, authenticated;

-- Junta dois progressos: estatísticas pelo máximo, conquistas por união
-- (fica a data mais antiga); o boneco e o resto vêm do mais recente (b).
create or replace function public._ou_merge(a jsonb, b jsonb) returns jsonb
language sql immutable set search_path = public as $$
  select coalesce(a, '{}'::jsonb) || coalesce(b, '{}'::jsonb) || jsonb_build_object(
    'stats', coalesce((
      select jsonb_object_agg(k, greatest(
        case when jsonb_typeof(a->'stats'->k) = 'number' then (a->'stats'->>k)::numeric else 0 end,
        case when jsonb_typeof(b->'stats'->k) = 'number' then (b->'stats'->>k)::numeric else 0 end))
      from (select jsonb_object_keys(coalesce(a->'stats', '{}'::jsonb)) k
            union select jsonb_object_keys(coalesce(b->'stats', '{}'::jsonb))) keys), '{}'::jsonb),
    'unlocked', coalesce(b->'unlocked', '{}'::jsonb) || coalesce(a->'unlocked', '{}'::jsonb))
$$;

-- Token novo para um dispositivo. Devolve o token (o jogo guarda-o) e os dados da conta.
create or replace function public._ou_session(p_account uuid, p_device text)
returns table(token text, username text, name text, friend_code text, progress jsonb)
language plpgsql security definer set search_path = public, extensions as $$
declare v_token text := encode(extensions.gen_random_bytes(32), 'hex');
begin
  insert into ou_sessions(token_hash, account_id, device)
    values (encode(extensions.digest(v_token, 'sha256'), 'hex'), p_account, left(coalesce(p_device, ''), 40));
  return query select v_token, a.username, a.name, a.friend_code, a.progress from ou_accounts a where a.id = p_account;
end $$;

-- Conta a partir do token (ou erro).
create or replace function public._ou_me(p_token text) returns public.ou_accounts
language plpgsql security definer set search_path = public, extensions as $$
declare me public.ou_accounts; v_hash text := encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');
begin
  select a.* into me from ou_sessions s join ou_accounts a on a.id = s.account_id where s.token_hash = v_hash;
  if me.id is null then raise exception 'sessão terminada'; end if;
  update ou_sessions set last_used = now() where token_hash = v_hash;
  return me;
end $$;

-- Cria uma conta. O nome de utilizador é o que se escreve para entrar (3 a 20
-- letras/números), o nome é o que aparece no jogo.
create or replace function public.ou_register(p_username text, p_password text, p_name text, p_progress jsonb, p_device text)
returns table(token text, username text, name text, friend_code text, progress jsonb)
language plpgsql security definer set search_path = public, extensions as $$
declare v_user text := trim(p_username); v_code text; v_id uuid;
begin
  if v_user !~ '^[A-Za-z0-9_.-]{3,20}$' then raise exception 'nome de utilizador inválido'; end if;
  if char_length(coalesce(p_password, '')) < 4 then raise exception 'palavra-passe curta'; end if;
  if exists (select 1 from ou_accounts a where lower(a.username) = lower(v_user)) then
    raise exception 'utilizador já existe';
  end if;
  loop
    v_code := upper(substr(translate(encode(extensions.gen_random_bytes(8), 'base64'), '+/=0O1Il', ''), 1, 6));
    exit when char_length(v_code) = 6 and not exists (select 1 from ou_accounts a where a.friend_code = v_code);
  end loop;
  insert into ou_accounts as a (username, name, password_hash, friend_code, progress)
    values (v_user, coalesce(nullif(left(trim(p_name), 16), ''), left(v_user, 16)),
            extensions.crypt(p_password, extensions.gen_salt('bf', 8)), v_code, coalesce(p_progress, '{}'::jsonb))
    returning a.id into v_id;
  return query select * from _ou_session(v_id, p_device);
end $$;

-- Entra numa conta que já existe (noutro PC, Mac, Legion Go...). Com a
-- palavra-passe errada não devolve nada (e à 5.ª seguida bloqueia 1 minuto).
create or replace function public.ou_login(p_username text, p_password text, p_device text)
returns table(token text, username text, name text, friend_code text, progress jsonb)
language plpgsql security definer set search_path = public, extensions as $$
declare acc public.ou_accounts;
begin
  select * into acc from ou_accounts a where lower(a.username) = lower(trim(p_username));
  if acc.id is null then raise exception 'utilizador não existe'; end if;
  if acc.locked_until is not null and acc.locked_until > now() then raise exception 'espera um minuto'; end if;
  if acc.password_hash <> extensions.crypt(coalesce(p_password, ''), acc.password_hash) then
    update ou_accounts a set
      locked_until = case when a.failed_logins + 1 >= 5 then now() + interval '1 minute' end,
      failed_logins = case when a.failed_logins + 1 >= 5 then 0 else a.failed_logins + 1 end
      where a.id = acc.id;
    return;
  end if;
  update ou_accounts a set failed_logins = 0, locked_until = null where a.id = acc.id;
  return query select * from _ou_session(acc.id, p_device);
end $$;

create or replace function public.ou_logout(p_token text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  delete from ou_sessions where token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');
end $$;

-- Lê o progresso guardado na conta.
create or replace function public.ou_load(p_token text)
returns table(username text, name text, friend_code text, progress jsonb)
language plpgsql security definer set search_path = public, extensions as $$
declare me public.ou_accounts := _ou_me(p_token);
begin
  return query select me.username, me.name, me.friend_code, me.progress;
end $$;

-- Junta o progresso deste PC ao da conta e devolve o resultado.
create or replace function public.ou_save(p_token text, p_name text, p_progress jsonb) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare me public.ou_accounts := _ou_me(p_token); v jsonb;
begin
  if pg_column_size(p_progress) > 200000 then raise exception 'progresso grande demais'; end if;
  v := _ou_merge(me.progress, p_progress);
  update ou_accounts a set progress = v, name = coalesce(nullif(left(trim(p_name), 16), ''), a.name) where a.id = me.id;
  return v;
end $$;

-- Diz que está online (e em que sala, se for host). O jogo chama a cada 30 s.
create or replace function public.ou_heartbeat(p_token text, p_room text, p_status text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare me public.ou_accounts := _ou_me(p_token);
begin
  update ou_accounts a set last_seen = now(), room_code = nullif(left(p_room, 16), ''), status = left(p_status, 40)
    where a.id = me.id;
end $$;

-- Adiciona um amigo pelo código ou pelo nome de utilizador (fica amigo dos dois lados).
create or replace function public.ou_add_friend(p_token text, p_code text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare me public.ou_accounts := _ou_me(p_token); other public.ou_accounts;
begin
  select * into other from ou_accounts a
    where a.friend_code = upper(replace(trim(p_code), '-', '')) or lower(a.username) = lower(trim(p_code))
    limit 1;
  if other.id is null then raise exception 'código não existe'; end if;
  if other.id = me.id then raise exception 'esse és tu'; end if;
  insert into ou_friends values (me.id, other.id, now()) on conflict do nothing;
  insert into ou_friends values (other.id, me.id, now()) on conflict do nothing;
  return other.name;
end $$;

create or replace function public.ou_remove_friend(p_token text, p_code text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare me public.ou_accounts := _ou_me(p_token);
begin
  delete from ou_friends f using ou_accounts p
    where p.friend_code = upper(trim(p_code))
      and ((f.account_id = me.id and f.friend_id = p.id) or (f.account_id = p.id and f.friend_id = me.id));
end $$;

-- Lista de amigos: nome, código, se está online (visto há menos de 90 s), a sala e o boneco.
create or replace function public.ou_list_friends(p_token text)
returns table(name text, friend_code text, online boolean, room_code text, status text, look jsonb)
language plpgsql security definer set search_path = public, extensions as $$
declare me public.ou_accounts := _ou_me(p_token);
begin
  return query
    select p.name, p.friend_code, p.last_seen > now() - interval '90 seconds',
      case when p.last_seen > now() - interval '90 seconds' then p.room_code end, p.status,
      coalesce(p.progress->'look', '{}'::jsonb)
    from ou_friends f join ou_accounts p on p.id = f.friend_id
    where f.account_id = me.id
    order by 3 desc, 1;
end $$;

-- Só as funções ou_* se podem chamar com a chave do jogo.
revoke all on function public._ou_merge(jsonb, jsonb) from public, anon, authenticated;
revoke all on function public._ou_session(uuid, text) from public, anon, authenticated;
revoke all on function public._ou_me(text) from public, anon, authenticated;
revoke all on function public.ou_register(text, text, text, jsonb, text) from public;
revoke all on function public.ou_login(text, text, text) from public;
revoke all on function public.ou_logout(text) from public;
revoke all on function public.ou_load(text) from public;
revoke all on function public.ou_save(text, text, jsonb) from public;
revoke all on function public.ou_heartbeat(text, text, text) from public;
revoke all on function public.ou_add_friend(text, text) from public;
revoke all on function public.ou_remove_friend(text, text) from public;
revoke all on function public.ou_list_friends(text) from public;
grant execute on function public.ou_register(text, text, text, jsonb, text) to anon, authenticated;
grant execute on function public.ou_login(text, text, text) to anon, authenticated;
grant execute on function public.ou_logout(text) to anon, authenticated;
grant execute on function public.ou_load(text) to anon, authenticated;
grant execute on function public.ou_save(text, text, jsonb) to anon, authenticated;
grant execute on function public.ou_heartbeat(text, text, text) to anon, authenticated;
grant execute on function public.ou_add_friend(text, text) to anon, authenticated;
grant execute on function public.ou_remove_friend(text, text) to anon, authenticated;
grant execute on function public.ou_list_friends(text) to anon, authenticated;

-- Atualiza a API para ver as funções novas logo.
notify pgrst, 'reload schema';
