# Handoff: auto-update foodies-app on Atlas with What's Up Docker (WUD)

Written 2026-11-08. Read this whole file, then `AGENTS.md` (check/diff first, the user approves runs on hosts, no
host firewall or network changes on remote hosts), then `atlas/HANDOFF-foodies-app.md` for how the app runs now.

## Goal
When GitLab CI publishes a new foodies-app image, Atlas picks it up without the user bumping a tag by hand.
WUD (https://getwud.github.io/wud/) watches the registry and triggers the update. It pulls from Atlas, so CI needs
no credentials for Atlas.

Done means: a merge to foodies-app `main` ends with Atlas running the new image, **healthy**, with no manual step,
and the setup stays in Ansible (a second run `changed=0`).

## How foodies-app runs now (2026-11-08)
- `atlas/setup-foodies-app.yaml` templates `/opt/containers/foodies-app/docker-compose.yml` from
  `atlas/templates/foodies-app/docker-compose.yml.j2`, image
  `registry.gitlab.com/abhishekr700/foodies-app:{{ foodies_app_image_tag }}`, pinned in `host_vars/atlas.yml`.
- CI tags each `main` build `latest`, `main` and `main-<short sha>` (multi-arch; Atlas is arm64).
- Registry login on Atlas: deploy token `atlas-registry-pull` (`read_registry` only, expires 2027-11-08), secret in
  `{{ local_env_folder }}/foodies-app-registry-token`. WUD can reuse it.
- Port 3000 is bound to `172.17.0.1` only; Pangolin's newt reaches it there. Don't change that.

## Problems to solve first (decide with the user)
1. **Pinned tags vs auto-update.** The earlier decision was pinned `main-<sha>`, not `latest`. WUD orders tags by
   semver, and `main-<sha>` has no order, so WUD can't tell which sha is newer. Options:
   - CI also pushes an ordered tag (e.g. `1.0.<pipeline iid>`), WUD watches only those (`wud.tag.include` regex).
     Keeps "every deploy is a specific, traceable image". Needs a foodies-app CI change (GitLab MR).
   - WUD watches the digest of the floating `main` tag. No CI change, but reverses the pinned-tag decision.
   Recommend the first; confirm with the user.
2. **Ansible vs WUD both own the tag.** If WUD rewrites the compose file or recreates the container, the next
   Ansible run puts the pinned tag back (a downgrade). Pick one owner: e.g. Ansible templates the tag only on first
   deploy, or the template reads the current tag, or WUD only notifies and something else bumps `host_vars`.
3. **Which WUD trigger.** `docker` trigger (recreates the container) or `dockercompose` (edits the compose file).
   Check how each interacts with point 2 and with `container_name`/`env_file`. Verify against WUD's docs; don't
   assume.
4. **Bad releases.** CI tests before publishing, but a broken image still goes live automatically. At minimum,
   notify on each update (WUD has Telegram/ntfy/etc. triggers) and keep rollback = set the old tag and run Ansible.

## Security (apply without asking)
- WUD needs the Docker socket, which is root-equivalent on Atlas. Mount it read-only if the chosen trigger allows;
  pin the WUD image by version (and digest if practical), not `latest`.
- Limit WUD to foodies-app: `WUD_WATCHBYDEFAULT=false` and a `wud.watch=true` label on foodies-app only. Atlas also
  runs Pangolin, Ghost and MariaDB; don't auto-update those.
- Registry creds: the existing `read_registry` token only, via `no_log`, never in the repo.
- WUD's web UI: don't publish it to the world. No `ports:`, or bind to the tailnet / `172.17.0.1` and reach it via
  Pangolin with auth. Ask the user.

## Plan
1. Settle problems 1–4 with the user.
2. If problem 1 is the ordered tag: the foodies-app CI change, through a GitLab MR (`docs/ci.md` in that repo).
3. `atlas/setup-wud.yaml` (or a tasks file in the foodies-app play), template its compose under
   `{{ atlas_containers_folder }}/wud/`, vars in `host_vars/atlas.yml`, `import_playbook` with `tags: wud`.
4. `--check --diff`, show the user, wait. Real run, then a second run for `changed=0`.
5. Test end to end: merge a trivial foodies-app change, watch WUD pick it up, check `docker ps` healthy on the new
   tag and `https://remember.food/api/health`. Then check that an Ansible run doesn't revert it.

## Not in scope
- Auto-updating other containers on Atlas.
- Pushing from CI to Atlas.

## Status
- 2026-11-08: written. Not started.
- 2026-11-08: decisions made with the user:
  1. Ordered tags: CI also pushes `1.0.$CI_PIPELINE_IID`. WUD follows `^1\.0\.\d+$`.
  2. WUD owns the running tag. `setup-foodies-app.yaml` reads the deployed compose file and keeps a `1.0.N` there if
     it's newer than `foodies_app_image_tag`. Rollback: `-e foodies_app_image_tag=1.0.<n> -e foodies_app_force_tag=true`.
     It recreates only when Ansible changed the compose file (`recreate: never` otherwise), because the config
     hash is stale after WUD recreates the container.
  3. The `dockercompose` trigger (WUD 9.8.0) edits only the `image:` line (comments kept) and recreates the
     container through the Docker API, copying its config. `ROLLBACK=true` restores it on a failed healthcheck.
     Telegram events: available, success, failure, rollback.
  4. UI through Pangolin with auth: bound to `172.17.0.1:3009`. The user adds the Pangolin resource.
  Built: `atlas/setup-wud.yaml`, `atlas/templates/wud/docker-compose.yml.j2`, foodies labels and tag logic, host_vars,
  imported with `tags: wud`. Secrets: `{{ local_env_folder }}/wud-atlas.env` (0600: admin login, session secret,
  Telegram bot reused from hermes) + the existing registry token. Tag logic tested locally, 8 cases. `--check --diff` is clean.
  foodies-app CI change on branch `ci/ordered-version-tag` (not pushed yet).
  Next: MR → merge → first `1.0.N` → set `foodies_app_image_tag: 1.0.N` → real run, second run `changed=0` →
  Pangolin resource → end-to-end test (merge a trivial change and watch WUD deploy it).
- 2026-11-08: **switched to the simpler design (user's call), replacing the 1–2 above:** Ansible deploys the
  floating `main` tag, and WUD watches its digest (`wud.watch.digest=true`) with the `docker` trigger
  (`PRUNE`, `ROLLBACK`). WUD never edits files, so Ansible and WUD don't share anything: no tag-choosing logic, no CI
  change (the `ci/ordered-version-tag` branch was dropped). Rollback: `foodies_app_image_tag: main-<sha>` + run, then
  back to `main`. The reversal of the earlier pinned-tag decision is deliberate. Revisit (ordered tags or Renovate) if
  traceability starts to matter. `--check --diff` is clean.
  Next: real run (recreates foodies-app once for the labels; `main` = the same digest as `main-f02f7f66`), second run
  `changed=0`, Pangolin resource → `http://172.17.0.1:3009` with auth, end-to-end test with a trivial merge.
- 2026-11-08: tailnet access added with `tailscale serve --bg --http=3009 http://172.17.0.1:3009` (tasks in
  `setup-wud.yaml`), so it's `http://atlas:3009`. Not a Docker bind on the Tailscale IP: Docker doesn't wait for
  tailscaled at boot, and that bind can fail. Not `0.0.0.0`: Atlas is public and Docker bypasses ufw. The idempotency
  check was tested locally against the assumed `serve status --json` shape; confirm with the second real run.
- 2026-11-08 14:18: **real run done.** foodies-app recreated on `:main`, healthy. WUD 9.8.0 is up: "1 containers
  watched, 0 errors". Triggers `docker.foodies` (prune, rollback) and `telegram.tg` (available, success, failure,
  rollback) are registered. `tailscale serve` is on: `http://atlas:3009` returns 200 from the Mac; public `:3009` doesn't
  answer; `remember.food/api/health` 200. Second run `changed=0` (the serve step skips, so the JSON-shape assumption
  holds).
  Left: the user adds the Pangolin resource → `http://172.17.0.1:3009` with auth. End-to-end test: merge a trivial
  foodies-app change and watch WUD (within 5 min of publish) recreate it, stay healthy, and send Telegram. Commit
  when the user asks.
- 2026-11-08: **end-to-end test passed.** foodies-app MR !4 merged at 14:39 IST → pipeline done at 14:42 → WUD
  recreated the container at 14:45:39 on the new `main` digest, healthy, config preserved (ports, env, labels,
  network), old digest pruned. Ansible `--check` `changed=0`. The user confirmed the Telegram messages arrived (WUD doesn't log
  sends at the default log level). **Handoff complete.**
