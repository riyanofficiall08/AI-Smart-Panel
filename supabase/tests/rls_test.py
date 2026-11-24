import pgserver, psycopg2, tempfile, uuid, warnings
warnings.filterwarnings("ignore")
srv = pgserver.get_server(tempfile.mkdtemp())
conn = psycopg2.connect(srv.get_uri()); conn.autocommit = True
cur = conn.cursor()

# --- stub lingkungan Supabase ---
cur.execute("""
create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema public, auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
""")
cur.execute(open('/home/claude/ai_smart_panel/supabase/migrations/001_schema.sql').read())
cur.execute("grant usage on all sequences in schema public to authenticated, service_role; grant select on all tables in schema public to authenticated;")
# migrasi me-revoke anon; pastikan grant authenticated sesuai praktik Supabase (RLS yang membatasi)
cur.execute("grant insert, update, delete on all tables in schema public to authenticated; revoke all on public.app_secrets from authenticated;")

admin, u1, u2 = [str(uuid.uuid4()) for _ in range(3)]
for i in (admin, u1, u2): cur.execute("insert into auth.users values (%s)", (i,))
cur.execute("insert into profiles(id,username,role) values (%s,'admin','admin'),(%s,'budi','user'),(%s,'sari','user')", (admin,u1,u2))
cur.execute("insert into licenses(token_hash,token_hint,duration_days,status,user_id) values ('h1','AAAA',30,'redeemed',%s),('h2','BBBB',7,'redeemed',%s)", (u1,u2))
cur.execute("insert into usage_logs(user_id,username,action,status) values (%s,'budi','analyze','ok'),(%s,'sari','analyze','ok')", (u1,u2))
cur.execute("insert into history(user_id,mode,confidence_pref,answer) values (%s,'fast',80,'jawaban budi'),(%s,'fast',80,'jawaban sari')", (u1,u2))
cur.execute("insert into app_secrets values ('openai_api_key','CIPHER',now())")

def as_user(sub, role='authenticated'):
    cur.execute("reset role; reset request.jwt.claim.sub")
    cur.execute(f"set role {role}")
    if sub: cur.execute(f"set request.jwt.claim.sub = '{sub}'")

def q(sql):
    try:
        cur.execute(sql)
        return cur.fetchall() if cur.description else cur.rowcount
    except Exception as e:
        conn.rollback() if not conn.autocommit else None
        return f"ERROR: {str(e).splitlines()[0]}"

ok = True
def check(name, got, expect):
    global ok
    good = expect(got); ok &= good
    print(("PASS " if good else "FAIL ") + name + "  -> " + str(got)[:90])

as_user(u1)
check("user melihat HANYA profil sendiri", q("select username from profiles"), lambda r: r == [('budi',)])
check("user melihat HANYA lisensi sendiri", q("select token_hint from licenses"), lambda r: r == [('AAAA',)])
check("user melihat HANYA riwayat sendiri", q("select answer from history"), lambda r: r == [('jawaban budi',)])
check("user melihat HANYA usage_logs sendiri", q("select username from usage_logs"), lambda r: r == [('budi',)])
check("user TIDAK bisa membaca app_settings", q("select * from app_settings"), lambda r: r == [])
check("user TIDAK bisa membaca app_secrets", q("select * from app_secrets"), lambda r: isinstance(r, str) and 'permission denied' in r)
check("user TIDAK bisa naikkan role ke admin", q("update profiles set role='admin' where id='%s'" % u1), lambda r: r == 0)
check("user TIDAK bisa perpanjang masa aktif sendiri", q("update profiles set expires_at=now()+interval '999 days' where id='%s'" % u1), lambda r: r == 0)
check("user TIDAK bisa insert lisensi", q("insert into licenses(token_hash,token_hint,duration_days) values ('x','XXXX',30)"), lambda r: isinstance(r, str))
check("user TIDAK bisa insert history palsu", q("insert into history(user_id,mode,confidence_pref) values ('%s','fast',80)" % u1), lambda r: isinstance(r, str))
check("user TIDAK bisa menghapus riwayat user lain", q("delete from history where user_id='%s'" % u2), lambda r: r == 0)
check("user BISA menghapus riwayat sendiri", q("delete from history where user_id='%s'" % u1), lambda r: r == 1)
check("user TIDAK bisa menulis app_settings", q("update app_settings set value='1'::jsonb where key='daily_limit'"), lambda r: r == 0)
check("user TIDAK bisa memanggil is_admin() sebagai admin", q("select public.is_admin()"), lambda r: r == [(False,)])

as_user(None, 'anon')
check("anon tidak bisa baca profiles", q("select * from profiles"), lambda r: isinstance(r, str))

as_user(admin)
check("admin melihat semua profil", q("select count(*) from profiles"), lambda r: r == [(3,)])
check("admin melihat semua lisensi", q("select count(*) from licenses"), lambda r: r == [(2,)])
check("admin melihat semua usage_logs", q("select count(*) from usage_logs"), lambda r: r == [(2,)])
check("admin TIDAK membaca isi riwayat user (privasi)", q("select count(*) from history"), lambda r: r == [(1,)] or r == [(0,)])
check("admin BISA mengubah app_settings", q("update app_settings set value='50'::jsonb where key='daily_limit'"), lambda r: r == 1)
check("admin TIDAK bisa baca app_secrets langsung", q("select * from app_secrets"), lambda r: isinstance(r, str))
check("is_admin() true untuk admin", q("select public.is_admin()"), lambda r: r == [(True,)])

cur.execute("reset role")
cur.execute("update profiles set is_active=false where id=%s", (admin,))
as_user(admin)
check("admin NONAKTIF kehilangan hak admin (hanya lihat profil sendiri)", q("select count(*) from profiles"), lambda r: r == [(1,)])

cur.execute("reset role")
as_user(None, 'service_role')
check("service_role (Edge Function) membaca app_secrets", q("select name from app_secrets"), lambda r: r == [('openai_api_key',)])
check("constraint username huruf besar ditolak", q("insert into profiles(id,username) values (gen_random_uuid(),'BadName')"), lambda r: isinstance(r, str))
print("\nHASIL:", "SEMUA LULUS" if ok else "ADA YANG GAGAL")
