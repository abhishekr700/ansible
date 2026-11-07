-- Read-only role for the agents on agent-devbox (prod-db skill), foodies-app Supabase project.
-- Run as postgres: supabase-ro-role.py next to this file does it and sets the password (step 2), or use the SQL editor.
-- Safe to re-run. Re-run after a migration adds a table you want visible (new tables stay hidden: fail closed).

-- 1. Role: login only, nothing inherited, read-only sessions, bounded queries.
do $$ begin
  if not exists (select from pg_roles where rolname = 'foodies_ro') then
    create role foodies_ro login noinherit nocreatedb nocreaterole noreplication;
  end if;
end $$;
alter role foodies_ro set default_transaction_read_only = on;
alter role foodies_ro set statement_timeout = '30s';
alter role foodies_ro set idle_in_transaction_session_timeout = '60s';
alter role foodies_ro connection limit 3;

-- 2. Password. supabase-ro-role.py sets it as a SCRAM hash. By hand: a separate query, then delete it from the
--    SQL editor history/snippets:
--    openssl rand -hex 24      (hex: no URL-encoding needed in the connection string)
-- alter role foodies_ro password '<hex>';

-- 3. Grants. Left out on purpose:
--    "Account" (Google OAuth access/refresh/id tokens), "Session" (session tokens), "VerificationToken".
--    "User" is granted whole, emails included (2026-11-08, the user's call).
grant usage on schema public to foodies_ro;
grant select on public."UserPair", public."Place", public."Dish", public."Rating",
                public."Comment", public."RatingConfig", public."_prisma_migrations", public."User" to foodies_ro;

-- 4. Check (all should be false except user_email and rating_ok):
select has_table_privilege('foodies_ro', 'public."Account"', 'select')           as account,
       has_table_privilege('foodies_ro', 'public."Session"', 'select')           as session,
       has_column_privilege('foodies_ro', 'public."User"', 'email', 'select')    as user_email,
       has_table_privilege('foodies_ro', 'auth.users', 'select')                 as auth_users,
       has_table_privilege('foodies_ro', 'storage.objects', 'select')            as storage,
       has_table_privilege('foodies_ro', 'public."Rating"', 'select')            as rating_ok;
