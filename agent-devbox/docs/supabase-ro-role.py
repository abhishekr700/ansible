"""Create or rotate the foodies_ro Supabase role from the laptop (see agent-devbox/Readme.md, "Read-only production DB").

    python3 -I agent-devbox/docs/supabase-ro-role.py ENV_FILE OUT_FILE [SQL_FILE]

ENV_FILE: the app's production env file; its DIRECT_URL (admin, session pooler) is used to connect.
SQL_FILE: run first if given (foodies-readonly-role.sql, for a first setup or new grants). Leave it out to only rotate.
OUT_FILE: gets the new read-only connection string (mode 0600); feed it to FOODIES_RO_URL, then delete it.

The password is generated here and sent as a SCRAM-SHA-256 verifier, so the plain text never reaches Supabase
(or its statement logs), and no secret is passed on a command line.
"""
import base64, hashlib, hmac, os, re, secrets, subprocess, sys
from urllib.parse import urlsplit

envfile, outfile, *sql = sys.argv[1:]
u = urlsplit(re.search(r'^DIRECT_URL="([^"]+)"', open(envfile).read(), re.M).group(1))
ref = u.username.split(".", 1)[1]
env = dict(os.environ, PGPASSWORD=u.password, PGHOST=u.hostname, PGPORT=str(u.port or 5432),
           PGUSER=u.username, PGDATABASE=u.path[1:], PGSSLMODE="require")


def psql(*args, **kw):
    r = subprocess.run(["psql", "-X", "-v", "ON_ERROR_STOP=1", *args], env=env, text=True, **kw)
    if r.returncode:
        sys.exit(r.returncode)


if sql:
    psql("-f", sql[0])

pw = secrets.token_hex(24)
salt = os.urandom(16)
salted = hashlib.pbkdf2_hmac("sha256", pw.encode(), salt, 4096)
client_key = hmac.new(salted, b"Client Key", "sha256").digest()
server_key = hmac.new(salted, b"Server Key", "sha256").digest()
b64 = lambda x: base64.b64encode(x).decode()
verifier = f"SCRAM-SHA-256$4096:{b64(salt)}${b64(hashlib.sha256(client_key).digest())}:{b64(server_key)}"
psql(input=f"alter role foodies_ro password '{verifier}';\n")

fd = os.open(outfile, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
os.write(fd, f"postgresql://foodies_ro.{ref}:{pw}@{u.hostname}:5432/postgres".encode())
os.close(fd)
print("wrote", outfile)
