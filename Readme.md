# Abhishek's Ansible Playbooks

## Install roles

```sh
ansible-galaxy install stefangweichinger.ansible_rclone
```

## Run Playbooks

```sh
ansible-playbook -i inventory.yaml bifrost/setup-bifrost.yaml
```

## Backup Script Generation

```bash
source venv/bin/activate
pip install pyyaml jinja2
python templates/generate_backup_scripts.py --config /Users/abhishekranjan/1Personal/05NAS/crons/backup-cron-template-config.yaml
```


### 📘 Playbook Naming Convention

To maintain consistency and readability across the project, all Ansible playbook filenames should use **hyphen-separated lowercase naming**.

#### ✅ Preferred format

- `setup-database.yml`
- `deploy-webserver.yml`
- `create-user-accounts.yml`

#### ❌ Avoid

- `setup_database.yml` (snake_case)
- `SetupDatabase.yml` (CamelCase)
- `setupDatabase.yml` (mixed case)

**Why hyphen-case?**

- Aligns with common Ansible community practices.
- Improves readability in file listings and CLI usage.
- Consistent with Ansible Galaxy role naming.

Stick to this convention for clean, professional, and maintainable playbooks.

---

Let me know if you want to include rules for roles, tasks, or variables too.

### Project Setup Commands

```sh
ansible-playbook -i inventory.yaml prometheus/projects/setup-expense-tracker.yaml

ansible-playbook -i inventory.yaml prometheus/projects/setup-expense-importer.yaml

ansible-playbook -i inventory.yaml prometheus/projects/setup-sos-app.yaml

```
