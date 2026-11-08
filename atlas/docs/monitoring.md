# Monitoring on atlas

Prometheus, Pushgateway and Grafana run on atlas. They hold the backup metrics behind the Grafana "Homelab backups"
dashboard and the homelab map (`02Projects/19HomelabMap`).

## What runs where
- **Compose project:** `/opt/containers/monitoring` (`atlas/setup-monitoring.yaml`, imported from `setup-atlas.yaml`
  with tag `monitoring`).
- **Data:** everything is under `/opt/containers/monitoring/data/`, so moving hosts means copying one folder.
- **Versions:** pinned with digests in `host_vars/atlas.yml`. Bump the version and the digest together.

| Service | Bind on atlas | Tailnet (`tailscale serve`) | Notes |
|---|---|---|---|
| Prometheus | `127.0.0.1:9090` | `http://atlas.taila8099.ts.net:9090` | 90-day retention. No auth: any untagged tailnet device can query it |
| Pushgateway | `127.0.0.1:9091` | `http://atlas.taila8099.ts.net:9091` | Backup hosts push here |
| Grafana | `127.0.0.1:3010` | `http://atlas.taila8099.ts.net:3010` | Login `admin`. Anonymous access is off |

- **Tailnet access:**
  - Nothing binds `0.0.0.0`, because Docker bypasses ufw.
  - `tailscale serve` routes by hostname, so use the MagicDNS name, not the Tailscale IP.
  - `tag:agent` (agent-devbox) can only reach atlas:443, so it can't reach any of these.
- **Grafana admin password:** generated once into `{{ local_env_folder }}/grafana-atlas-admin-password` on the
  laptop (outside the repo). Grafana reads it only on first start. To change it later, run
  `grafana cli admin reset-admin-password` in the container.
- **Publishing through Pangolin later:** rebind Grafana to `172.17.0.1` (see the comment in the compose template).

## Backup metrics flow
cron → `backup-run` on the backup host → POST to the Pushgateway → Prometheus scrapes it → the recording rule
`homelab:backup_status` (0 green, 1 yellow, 2 red) → the Grafana dashboard and the homelab map.

- **The wrapper:** `proxmox-blr-ws/files/backup-run`.
  - It pushes start and end, the exit code, the duration and the borg sizes.
  - It always exits with the script's own exit code, and it ignores push failures.
- **The rules:** `atlas/templates/monitoring/homelab-backups.rules.yml.j2`.
  - Red: a failed exit, a success older than 3× the interval, or no data at all.
  - Yellow: a success older than 1.5× the interval, a borg warning, or running longer than 2× the typical run plus
    15 min.
- **The dashboard:** `atlas/files/monitoring/grafana/dashboards/homelab-backups.json`.
- **The metric contract** (names and labels): `01Ideas/live-homelab-map/backup-metrics-contract.md`.

## Add a backup job
1. On the backup host's cron task, wrap the script the way the existing cron lines do:
   `backup-run --backup <name> --kind borg|rclone --target <target> --interval <seconds> -- <script>`.
   The host needs `backup_run_pushgateway_url` in its host_vars, and the wrapper install tasks from
   `proxmox-blr-ws/setup-proxmox-blr-ws-crons.yaml`.
2. Add the job to `monitoring_expected_backups` in `host_vars/atlas.yml`, so that missing data shows red.
3. Run the atlas playbook with `--tags monitoring` to update the rules. The dashboard picks up new backups by
   itself.

## Check it
- `curl -s http://atlas.taila8099.ts.net:9091/metrics | grep '^backup_'` shows the latest push per job.
- `curl -s 'http://atlas.taila8099.ts.net:9090/api/v1/query?query=homelab:backup_status'` shows the status per
  job.
- After a playbook change, run it a second time and expect `changed=0`.
