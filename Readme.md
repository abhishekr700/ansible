# Abhishek's Ansible Playbooks

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