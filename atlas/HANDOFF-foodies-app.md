# Handoff: deploy foodies-app on Atlas from the GitLab registry

Written 2026-11-08. Read this whole file, then `AGENTS.md` (repo rules: check/diff first, the user approves runs
on hosts, no host firewall or network changes on remote hosts).

## Goal
Atlas runs foodies-app from the prebuilt image instead of cloning the repo and building it on the host:

```
registry.gitlab.com/abhishekr700/foodies-app:main-<sha>
```

Done means: the playbook pulls a pinned `main-<sha>` tag, the container is **healthy**, the site works through its
public URL, and a second run shows `changed=0`.

## Background
- foodies-app (Next.js 16, Prisma, Supabase Postgres) lives on GitLab. On each merge to `main`, GitLab CI tests it
  and publishes a multi-arch image (amd64 + arm64) tagged `latest`, `main` and `main-<short sha>`. The first one is
  `main-f02f7f66` (2026-11-07). How the pipeline works: `docs/ci.md` in the foodies-app repo.
- The registry is private. Atlas has no credentials for it yet.
- Atlas is **arm64** (`aarch64`) with a public IP, user `ubuntu`. The inventory is gitignored (`inventory.yaml`).

## What's there now (checked read-only, 2026-11-08)
- Container `foodies-app`, image `foodies-app-app` (built on the host by compose), up 2 weeks, **unhealthy**.
- Code at `/opt/containers/foodies-app`, at `4a768b8`, cloned from `https://github.com/abhishekr700/foodies-app.git`.
- **Port 3000 is published on `0.0.0.0` and `[::]`.** Docker bypasses ufw. From the user's laptop,
  `http://<public IP>:3000` and a TCP connect to `:3306` both timed out (2026-11-08), so something upstream (the
  provider's firewall?) probably blocks them. Don't rely on that layer: bind it narrowly anyway (step 4). IPv6 wasn't tested. Also on the host: Pangolin (`pangolin`, `gerbil`, `traefik`,
  `newt`) handles 80/443, plus `ghost` and `mariadb` (3306 is also on `0.0.0.0`; out of scope, but tell the user).
- **The healthcheck is broken:** compose runs `wget`, and the image (`node:20-slim`) has none (`no-wget` from
  `docker exec`). That's the cause of "unhealthy".

The ansible side is **uncommitted** in the user's working tree. Don't discard it; build on it:
- `atlas/setup-foodies-app.yaml` (untracked): clones `git@github.com:abhishekr700/foodies-app.git`, copies
  `{{ local_env_folder }}/foodies-app.env.production` to `.env.production`, runs `docker_compose_v2` with `build: always`.
- `atlas/setup-atlas.yaml`: `import_playbook`s it at the end (no tag yet).
- `host_vars/atlas.yml`: adds `atlas_containers_folder: /opt/containers`.
  Other uncommitted changes in the tree (bifrost, projects) aren't part of this. Leave them alone.

## Plan (check each step with the user)
1. **Read-only first.** Find out how Pangolin reaches the app (a newt/Pangolin resource pointing at
   `localhost:3000`, the host IP, or a docker network?). That decides step 4. Ask the user if it isn't clear.
2. **Registry credential.** The user creates a project deploy token in GitLab (foodies-app, *Settings → Repository →
   Deploy tokens*) with **only `read_registry`**. Keep it out of the repo and out of Terraform state: put it in a
   gitignored file next to the other env files in `local_env_folder`, or in an env var, and read it with a lookup.
   Log in on Atlas with `community.docker.docker_login` (registry `registry.gitlab.com`) as `ubuntu`, `no_log: true`.
3. **Compose from Ansible, not from the repo.** Template a compose file into `{{ atlas_containers_folder }}/foodies-app/`
   with `image: registry.gitlab.com/abhishekr700/foodies-app:{{ foodies_app_image_tag }}` and the same env file. Put
   `foodies_app_image_tag` in `host_vars/atlas.yml`, pinned to a `main-<sha>`, not `latest`. Upgrading means
   changing that one line. Run `docker_compose_v2` with `pull: missing` (the tag is fixed) and no `build`. Then the
   git clone task can go, along with Atlas's need for any GitHub access.
4. **Don't publish 3000 to the world.** Depending on step 1: `127.0.0.1:3000:3000`, or no `ports:` and a shared
   docker network with Pangolin/newt. Check the site still works through the proxy. (A compose change, not a
   firewall change, so it's within the repo rules. Still show it to the user first: it changes how the app is
   reached.)
5. **Healthcheck that works with the image:**
   `["CMD", "node", "-e", "fetch('http://localhost:3000/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]`
   Put it in the Ansible compose template. Optionally fix the repo's `docker-compose.yml` too, through a GitLab MR.
6. **Tag it.** `tags: foodies-app` on the `import_playbook` in `setup-atlas.yaml`, so it can run alone.
7. **Run.** `ansible-playbook -i inventory.yaml atlas/setup-atlas.yaml --tags foodies-app --check --diff`, show the
   user, wait for approval. After the real run, check: `docker ps` shows `healthy` and the new image,
   `curl -fsS localhost:3000/api/health` on Atlas, the public URL in a browser or with curl, and from outside that
   `:3000` no longer answers. Then a second run for `changed=0`.
8. **Clean up, with the user's OK.** The old checkout `/opt/containers/foodies-app` (it holds `.env.production`,
   so make sure the new layout has it first), and the old `foodies-app-app` image.

## Decisions already made (don't reopen)
- CI is GitLab, not GitHub Actions. The registry is GitLab's.
- Deploy pinned `main-<sha>` tags, not `latest`.
- Scoped `read_registry` deploy token, not a personal access token.

## Not in scope
- Auto-deploy on merge (watchtower, webhooks, CI pushing to Atlas). If it comes up, it's a separate decision: CI
  would need credentials for Atlas.
- MariaDB's public 3306, Ghost, Pangolin config.

## Status
- 2026-11-08: written. Not started.
