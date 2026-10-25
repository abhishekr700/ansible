# agent-devbox backups

The VM can be rebuilt from code, so a backup only protects what lives inside it: `~hermes/.hermes`
(config, memory, sessions) and anything the agent created.

## What exists today (checked 2026-10-25)

- No backup jobs and no Proxmox Backup Server on `proxmox-blr-ws`.
- The only backup-capable storage is `local` (`/var/lib/vz`, 58 GB free). It's on the **same NVMe** as
  the VM, so it protects against mistakes inside the VM, not against losing the disk.
- `zfspooloffsite` is healthy but isn't registered as PVE storage, and it holds the offsite photo backups.

## Plan: weekly vzdump to `local`, keep 4 (apply yourself)

On `proxmox-blr-ws` as root:

```sh
pvesh create /cluster/backup \
  --id agent-devbox \
  --vmid 120 \
  --storage local \
  --schedule 'sun 03:30' \
  --mode snapshot \
  --compress zstd \
  --prune-backups keep-last=4 \
  --notes-template '{{guestname}}' \
  --enabled 1
```

- `snapshot` mode uses the guest agent to freeze the filesystem, so the backup is consistent while the VM keeps running.
- Expect a few GB per backup (thin disk, zstd).
- Check it: `pvesh get /cluster/backup/agent-devbox`. Run once now: `vzdump 120 --storage local --mode snapshot --compress zstd`.
- Remove it: `pvesh delete /cluster/backup/agent-devbox`.
- Restore: `qmrestore /var/lib/vz/dump/vzdump-qemu-120-<date>.vma.zst 120 --storage local-lvm --force`
  (destroys the current VM 120). Afterwards `terraform plan` may show drift; review it before applying.

## Options for an off-disk copy (your call)

- Register a **new dataset** on `zfspooloffsite` as a `dir` storage for backups only
  (`zfs create zfspooloffsite/pve-backups` + `pvesm add dir ...`). This touches the pool, which is why it isn't in the plan.
- Or add `/var/lib/vz/dump/vzdump-qemu-120-*` to an existing rclone/cloud cron.
- Or back up only `~hermes/.hermes` with `tar` from inside the VM to atlas or a cloud bucket. It's smaller,
  but it needs credentials on the VM, which this design avoids.
