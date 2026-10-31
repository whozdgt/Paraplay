-- Music app: friends, public profiles, follow requests, block/report, "listening now".
-- Run ONCE: Supabase Dashboard > SQL Editor > New query > paste all of this > Run.
-- Safe to run again. If it shows an error, copy the message back to Claude.
-- Needs the earlier setup (profiles, playlists, playlist_tracks) to exist already.

-- ============ NEW COLUMNS ============
alter table public.profiles  add column if not exists listening_public boolean not null default false;
alter table public.profiles  add column if not exists show_counts      boolean not null default true;
alter table public.playlists add column if not exists shared           boolean not null default false;

-- The old "friends" setting is gone: a profile is Public or Private.
update public.profiles set visibility = 'private' where visibility not in ('public', 'private');

-- ============ OLD TABLES WITH THE SAME NAMES ============
-- If a table called follows, blocks, reports or now_playing already exists from an earlier try and doesn't have the
-- columns below, it is renamed out of the way (to <name>_old_<date>, nothing is deleted) and a fresh one is made.
do $$
declare t record;
begin
  for t in select * from (values
      ('follows',     array['follower','followee','status']),
      ('blocks',      array['blocker','blocked']),
      ('reports',     array['reporter','target','reason']),
      ('now_playing', array['user_id','title','artist','quality','updated_at'])
    ) as v(tbl, cols)
  loop
    if to_regclass('public.' || t.tbl) is not null and exists (
         select 1 from unnest(t.cols) as c(name)
         where not exists (select 1 from information_schema.columns
                           where table_schema = 'public' and table_name = t.tbl and column_name = c.name)) then
      execute format('alter table public.%I rename to %I', t.tbl, t.tbl || '_old_' || to_char(now(), 'YYMMDDHH24MISS'));
    end if;
  end loop;
end $$;

-- ============ TABLES ============
create table if not exists public.follows (
  follower   uuid not null references auth.users(id) on delete cascade,
  followee   uuid not null references auth.users(id) on delete cascade,
  status     text not null check (status in ('accepted', 'requested')),
  created_at timestamptz not null default now(),
  primary key (follower, followee),
  check (follower <> followee)
);
create index if not exists follows_followee_idx on public.follows (followee, status);

create table if not exists public.blocks (
  blocker    uuid not null references auth.users(id) on delete cascade,
  blocked    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);

create table if not exists public.reports (
  id         bigint generated always as identity primary key,
  reporter   uuid not null references auth.users(id) on delete cascade,
  target     uuid not null references auth.users(id) on delete cascade,
  reason     text not null check (char_length(reason) between 1 and 500),
  created_at timestamptz not null default now()
);

create table if not exists public.now_playing (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  title      text not null check (char_length(title)  <= 200),
  artist     text not null check (char_length(artist) <= 200),
  quality    text not null default '' check (char_length(quality) <= 40),
  updated_at timestamptz not null default now()
);

-- ============ ROW LEVEL SECURITY ============
-- People never read other people's rows directly. They go through the functions below,
-- which decide what each viewer may see. Direct access is limited to your own rows.
alter table public.follows     enable row level security;
alter table public.blocks      enable row level security;
alter table public.reports     enable row level security;
alter table public.now_playing enable row level security;

drop policy if exists "follows see own"   on public.follows;
drop policy if exists "follows remove"    on public.follows;
create policy "follows see own" on public.follows for select to authenticated
  using (follower = auth.uid() or followee = auth.uid());
create policy "follows remove"  on public.follows for delete to authenticated
  using (follower = auth.uid() or followee = auth.uid());
-- no insert/update policy: following goes through social_follow / social_respond, which set the status.

drop policy if exists "blocks see own" on public.blocks;
create policy "blocks see own" on public.blocks for select to authenticated using (blocker = auth.uid());
drop policy if exists "blocks remove"  on public.blocks;
create policy "blocks remove"  on public.blocks for delete to authenticated using (blocker = auth.uid());
-- blocking goes through social_block (it also removes follows both ways).

drop policy if exists "reports add" on public.reports;
create policy "reports add" on public.reports for insert to authenticated
  with check (reporter = auth.uid() and target <> auth.uid());
-- nobody can read reports through the app; read them in the Supabase dashboard.

drop policy if exists "now playing own" on public.now_playing;
create policy "now playing own" on public.now_playing for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============ LOCK DOWN THE OLDER TABLES ============
-- Whatever rules were there before, replace them with "you can only touch your own rows".
-- That way nobody can read another person's profile, playlists or songs directly, only through the
-- functions below (which hide everything a Private profile keeps back).
do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies
           where schemaname = 'public' and tablename in ('profiles', 'playlists', 'playlist_tracks') loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public.profiles        enable row level security;
alter table public.playlists       enable row level security;
alter table public.playlist_tracks enable row level security;

create policy "profiles own read"   on public.profiles for select to authenticated using (id = auth.uid());
create policy "profiles own insert" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles own update" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy "playlists own" on public.playlists for all to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid());
create policy "playlist tracks own" on public.playlist_tracks for all to authenticated
  using (exists (select 1 from public.playlists p where p.id = playlist_id and p.owner = auth.uid()))
  with check (exists (select 1 from public.playlists p where p.id = playlist_id and p.owner = auth.uid()));

-- ============ HELPERS ============
create or replace function public.is_blocked(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.blocks where (blocker = a and blocked = b) or (blocker = b and blocked = a));
$$;

-- May `viewer` see the private parts (bio, playlists, listening) of `own_id`?
-- Yes if it is their own profile, or the profile is Public, or the viewer is an accepted follower.
-- Never if either has blocked the other.
create or replace function public.can_see(viewer uuid, own_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select viewer = own_id or (
    not public.is_blocked(viewer, own_id) and (
      exists (select 1 from public.profiles p where p.id = own_id and p.visibility = 'public')
      or exists (select 1 from public.follows f where f.follower = viewer and f.followee = own_id and f.status = 'accepted')
    )
  );
$$;

-- ============ FUNCTIONS THE APP CALLS ============
-- Find people: only profiles that chose "Appear in search". Name, @username and picture only.
create or replace function public.social_search(q text) returns table (
  id uuid, username text, display_name text, avatar_path text, visibility text, state text
) language sql stable security definer set search_path = public as $$
  select p.id, p.username, p.display_name, p.avatar_path, p.visibility,
         coalesce((select f.status from public.follows f where f.follower = auth.uid() and f.followee = p.id), 'none')
  from public.profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.discoverable
    and not public.is_blocked(auth.uid(), p.id)
    and char_length(trim(q)) >= 2
    and (p.username ilike '%' || replace(replace(trim(q), '%', ''), '_', '\_') || '%'
         or p.display_name ilike '%' || replace(replace(trim(q), '%', ''), '_', '\_') || '%')
  order by (lower(p.username) = lower(trim(q))) desc, p.username
  limit 20;
$$;

-- One profile, as the caller is allowed to see it. Private parts come back empty unless can_see.
create or replace function public.social_profile(uname text) returns table (
  id uuid, username text, display_name text, avatar_path text, visibility text,
  bio text, banner_path text, followers int, following int, playlists int,
  state text, listening boolean, blocked boolean, locked boolean
) language plpgsql stable security definer set search_path = public as $$
declare p public.profiles; me uuid := auth.uid(); see boolean;
begin
  if me is null then return; end if;
  select * into p from public.profiles where lower(profiles.username) = lower(uname);
  if not found then return; end if;
  if p.id <> me and public.is_blocked(me, p.id) then return; end if;
  see := public.can_see(me, p.id);
  return query select
    p.id, p.username, p.display_name, p.avatar_path, p.visibility,
    case when see then p.bio end,
    case when see then p.banner_path end,
    case when see and (p.show_counts or p.id = me) then (select count(*)::int from public.follows f where f.followee = p.id and f.status = 'accepted') end,
    case when see and (p.show_counts or p.id = me) then (select count(*)::int from public.follows f where f.follower = p.id and f.status = 'accepted') end,
    case when see and (p.show_playlists or p.id = me) then (select count(*)::int from public.playlists pl where pl.owner = p.id and pl.shared) end,
    coalesce((select f.status from public.follows f where f.follower = me and f.followee = p.id), 'none'),
    (see and p.listening_public and exists (select 1 from public.now_playing n where n.user_id = p.id and n.updated_at > now() - interval '5 minutes')),
    exists (select 1 from public.blocks b where b.blocker = me and b.blocked = p.id),
    not see;
end $$;

-- Shared playlists of a profile (only if you may see it and they chose to show playlists).
create or replace function public.social_playlists(owner_id uuid) returns table (
  id uuid, name text, updated_at timestamptz, tracks int
) language sql stable security definer set search_path = public as $$
  select pl.id, pl.name, pl.updated_at, (select count(*)::int from public.playlist_tracks t where t.playlist_id = pl.id)
  from public.playlists pl
  join public.profiles p on p.id = pl.owner
  where pl.owner = owner_id and pl.shared
    and public.can_see(auth.uid(), owner_id)
    and (p.show_playlists or p.id = auth.uid())
  order by pl.updated_at desc;
$$;

create or replace function public.social_playlist_tracks(pid uuid) returns table (
  "position" int, title text, artist text, album text, duration_ms int
) language sql stable security definer set search_path = public as $$
  select t."position", t.title, t.artist, t.album, t.duration_ms
  from public.playlist_tracks t
  join public.playlists pl on pl.id = t.playlist_id
  join public.profiles p on p.id = pl.owner
  where t.playlist_id = pid and pl.shared
    and public.can_see(auth.uid(), pl.owner)
    and (p.show_playlists or p.id = auth.uid())
  order by t."position";
$$;

-- Follow: public profile = accepted at once, private = a request.
create or replace function public.social_follow(target uuid) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); st text; vis text;
begin
  if me is null or target = me or public.is_blocked(me, target) then return 'none'; end if;
  select visibility into vis from public.profiles where id = target;
  if vis is null then return 'none'; end if;
  st := case when vis = 'public' then 'accepted' else 'requested' end;
  insert into public.follows (follower, followee, status) values (me, target, st)
    on conflict (follower, followee) do nothing;
  return (select status from public.follows where follower = me and followee = target);
end $$;

-- Accept or decline a request someone sent you.
create or replace function public.social_respond(from_user uuid, accept boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if accept then
    update public.follows set status = 'accepted' where follower = from_user and followee = auth.uid() and status = 'requested';
  else
    delete from public.follows where follower = from_user and followee = auth.uid() and status = 'requested';
  end if;
end $$;

create or replace function public.social_block(target uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or target = me then return; end if;
  insert into public.blocks (blocker, blocked) values (me, target) on conflict do nothing;
  delete from public.follows where (follower = me and followee = target) or (follower = target and followee = me);
end $$;

-- Who I follow (accepted or still waiting), and requests waiting for me.
create or replace function public.social_following() returns table (
  id uuid, username text, display_name text, avatar_path text, state text
) language sql stable security definer set search_path = public as $$
  select p.id, p.username, p.display_name, p.avatar_path, f.status
  from public.follows f join public.profiles p on p.id = f.followee
  where f.follower = auth.uid() and not public.is_blocked(auth.uid(), p.id)
  order by p.username;
$$;

create or replace function public.social_requests() returns table (
  id uuid, username text, display_name text, avatar_path text
) language sql stable security definer set search_path = public as $$
  select p.id, p.username, p.display_name, p.avatar_path
  from public.follows f join public.profiles p on p.id = f.follower
  where f.followee = auth.uid() and f.status = 'requested' and not public.is_blocked(auth.uid(), p.id)
  order by f.created_at;
$$;

-- What the people I follow are playing right now (only those who switched "Show what I'm listening to" on),
-- plus the last thing each one played in the last day.
create or replace function public.social_activity() returns table (
  id uuid, username text, display_name text, avatar_path text,
  title text, artist text, quality text, live boolean, played_at timestamptz
) language sql stable security definer set search_path = public as $$
  select p.id, p.username, p.display_name, p.avatar_path, n.title, n.artist, n.quality,
         (n.updated_at > now() - interval '5 minutes'), n.updated_at
  from public.follows f
  join public.profiles p on p.id = f.followee
  join public.now_playing n on n.user_id = p.id
  where f.follower = auth.uid() and f.status = 'accepted'
    and p.listening_public
    and n.updated_at > now() - interval '1 day'
    and not public.is_blocked(auth.uid(), p.id)
  order by n.updated_at desc
  limit 30;
$$;

-- Someone's "listening now" for their profile page, same rules as the profile.
create or replace function public.social_listening(uid uuid) returns table (title text, artist text, quality text)
language sql stable security definer set search_path = public as $$
  select n.title, n.artist, n.quality from public.now_playing n
  join public.profiles p on p.id = n.user_id
  where n.user_id = uid and p.listening_public and public.can_see(auth.uid(), uid)
    and n.updated_at > now() - interval '5 minutes';
$$;

-- Playlists that people I follow chose to share (for the Friends page).
create or replace function public.social_friend_playlists() returns table (
  id uuid, name text, tracks int, updated_at timestamptz, owner_id uuid, username text, display_name text
) language sql stable security definer set search_path = public as $$
  select pl.id, pl.name, (select count(*)::int from public.playlist_tracks t where t.playlist_id = pl.id),
         pl.updated_at, p.id, p.username, p.display_name
  from public.follows f
  join public.profiles p on p.id = f.followee
  join public.playlists pl on pl.owner = p.id and pl.shared
  where f.follower = auth.uid() and f.status = 'accepted'
    and p.show_playlists
    and not public.is_blocked(auth.uid(), p.id)
  order by pl.updated_at desc
  limit 30;
$$;

-- People I blocked (so I can unblock them; a blocked profile cannot be opened).
create or replace function public.social_blocked() returns table (
  id uuid, username text, display_name text, avatar_path text
) language sql stable security definer set search_path = public as $$
  select p.id, p.username, p.display_name, p.avatar_path
  from public.blocks b join public.profiles p on p.id = b.blocked
  where b.blocker = auth.uid()
  order by p.username;
$$;

-- ============ WHO MAY CALL WHAT ============
revoke all on function public.is_blocked(uuid, uuid)            from public, anon, authenticated;
revoke all on function public.can_see(uuid, uuid)               from public, anon, authenticated;
revoke all on function public.social_search(text)               from public, anon;
revoke all on function public.social_profile(text)              from public, anon;
revoke all on function public.social_playlists(uuid)            from public, anon;
revoke all on function public.social_playlist_tracks(uuid)      from public, anon;
revoke all on function public.social_follow(uuid)               from public, anon;
revoke all on function public.social_respond(uuid, boolean)     from public, anon;
revoke all on function public.social_block(uuid)                from public, anon;
revoke all on function public.social_following()                from public, anon;
revoke all on function public.social_requests()                 from public, anon;
revoke all on function public.social_activity()                 from public, anon;
revoke all on function public.social_listening(uuid)            from public, anon;
revoke all on function public.social_friend_playlists()         from public, anon;
revoke all on function public.social_blocked()                  from public, anon;

grant execute on function public.social_search(text)            to authenticated;
grant execute on function public.social_profile(text)           to authenticated;
grant execute on function public.social_playlists(uuid)         to authenticated;
grant execute on function public.social_playlist_tracks(uuid)   to authenticated;
grant execute on function public.social_follow(uuid)            to authenticated;
grant execute on function public.social_respond(uuid, boolean)  to authenticated;
grant execute on function public.social_block(uuid)             to authenticated;
grant execute on function public.social_following()             to authenticated;
grant execute on function public.social_requests()              to authenticated;
grant execute on function public.social_activity()             to authenticated;
grant execute on function public.social_listening(uuid)         to authenticated;
grant execute on function public.social_friend_playlists()      to authenticated;
grant execute on function public.social_blocked()               to authenticated;
-- is_blocked and can_see are internal helpers only; the functions above run as the owner and may call them.

-- make the API notice the new columns and functions straight away
notify pgrst, 'reload schema';
