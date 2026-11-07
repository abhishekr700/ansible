# terraform/gitlab

Lets the agents on `agent-devbox` push branches to your repos, without letting them merge.
This is option A: one SSH **deploy key**, no bot account, no API token on the VM.

```
agent (VM) --push agent/* + deploy key--> GitLab --you merge (phone/web)--> main
                                             |  push mirror, protected branches only
                                             v
                                          GitHub --> Ansible deploys / Actions (unchanged)
```

`ansible` is deliberately not in `var.repos`: it configures every host, so the dev agent doesn't get to push to it.

## What it manages, per repo in `var.repos`
- **Default-branch protection:** push `no one`, merge `maintainer` (you), no force-push. It's adopted with an `import` block,
  because GitLab protects the default branch on import. This blocks **your** direct pushes too, by choice: on GitLab Free
  a write deploy key acts with its creator's rights, so with push `maintainer` the agent could push to main (tested).
  Your own changes go through MRs as well (`git push -o merge_request.create`). Re-run the step 9 test after any change.
- **The deploy key** (`agent-deploy-key.pub`, can_push): it can clone and push any unprotected branch, but it has
  no API access, so it can't merge or change settings.
- **A push mirror to GitHub** (only for `var.mirror_repos`): over SSH with GitHub's host key pinned, protected
  branches only, and `keep_divergent_refs`, so a commit made directly on GitHub is skipped, not overwritten.

Projects are read with a data source, not managed. A `destroy` can't touch them.

## What it can't do (accepted)
- The agent can't open merge requests through the API or read review comments. It tries
  `git push -o merge_request.create`. Whether that works with a deploy key is **unconfirmed**; if it doesn't, you open
  the MR from the banner GitLab shows. You pass review feedback on over Telegram.
- The key can delete or overwrite other unprotected branches, including yours. Keep anything precious on main.
- The rules in `~hermes/.hermes/SOUL.md` and `~hermes/.claude/CLAUDE.md` are instructions. Branch protection is the
  only enforcement.

## Setup, in order
1. **You:** on gitlab.com (2FA on), go to New project, then Import project, then GitHub, and import the repos in `variables.tf` into your
   personal namespace. Keep their visibility.
2. **You:** create a personal access token with the `api` scope and add `export GITLAB_TOKEN=...` to the same zsh env file as
   the Tailscale creds.
3. Generate the key on the VM and fetch its public half here:
   `ansible-playbook -i inventory.yaml agent-devbox/setup-agent-devbox.yaml --tags git`
4. `cp terraform.tfvars.example terraform.tfvars`, then set `gitlab_namespace` and pick **one** repo in `mirror_repos`.
5. `zsh -ic 'terraform -chdir=terraform/gitlab init && terraform -chdir=terraform/gitlab plan'`. Check that it shows
   4 imports, 4 deploy keys and 1 mirror, then **you** apply.
6. Mirror key to GitHub: GitLab generated a key pair for the mirror. Get the public half:
   ```sh
   zsh -ic 'curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
     https://gitlab.com/api/v4/projects/<project-id>/remote_mirrors/<mirror-id>/public_key'
   ```
   The ids are in `terraform output`. Add it in the GitHub repo under Settings, Deploy keys, with **Allow write access** on.
7. Test: merge something into main on GitLab, then check that it reaches GitHub. Look at `last_error` in the mirror settings if
   it doesn't. Then add the other repos to `mirror_repos` and repeat steps 5 and 6.
8. Switch your laptop clones to GitLab: `git remote set-url origin git@gitlab.com:<you>/<repo>.git`. Don't push to GitHub
   directly anymore, or the mirror stops updating that branch.
9. Agent test, as hermes on the VM: clone a repo, push an `agent/test` branch (it should be accepted), then try
   `git push origin HEAD:main` (it should be rejected).

## Status
- 2026-11-07: applied with the 4 repos (`ansible` excluded on purpose); a second plan showed no changes.
- Tested from the VM as hermes: clone OK; push to main **rejected**; `agent/*` push OK and
  `-o merge_request.create` **does** open an MR with a deploy key; the author is `hermes (agent-devbox)`.
- An empty test commit `7944b8b` is on main in email-filter-script (from the push=maintainer test); it's harmless.
- Mirrors: all 4 repos push main to GitHub over SSH; the mirror keys were added as GitHub deploy keys with `gh`, and each sync
  finished (2026-11-07). A second plan showed no changes. The commits carry a `Co-authored-by` line for the user (`agent_git_coauthor`).
- Next: switch laptop clones to GitLab (step 8); check the first real merge reaches GitHub and that expenseTracker's Actions build still runs.
