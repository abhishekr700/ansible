# Projects are read, not managed: Terraform can't change their settings, and a destroy
# can't delete or archive them. It only removes what's below.
data "gitlab_project" "repo" {
  for_each            = var.repos
  path_with_namespace = "${var.gitlab_namespace}/${each.key}"
}

locals {
  github_host_key = "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" # from api.github.com/meta, 2026-11-07
}

# GitLab protects the default branch on import (Maintainers push and merge), so adopt that rule
# instead of creating a second one.
import {
  for_each = var.repos
  to       = gitlab_branch_protection.main[each.key]
  id       = "${data.gitlab_project.repo[each.key].id}:${data.gitlab_project.repo[each.key].default_branch}"
}

# Push: no one. A write deploy key acts with the rights of the user who added it (you, a Maintainer),
# so "maintainer" let the agent push to main (tested 2026-11-07). Merge: Maintainers (you).
# Re-run the push test in README.md if you change this.
resource "gitlab_branch_protection" "main" {
  for_each = var.repos
  project  = data.gitlab_project.repo[each.key].id
  branch   = data.gitlab_project.repo[each.key].default_branch
  # gitlab.com wants the allowed_to_* form; plain access levels work on the Free tier.
  allowed_to_push  = [{ access_level = "no one" }]
  allowed_to_merge = [{ access_level = "maintainer" }]
  allow_force_push = false
}

# One key shared by all repos. Write access, but only to unprotected branches.
resource "gitlab_deploy_key" "agent" {
  for_each = var.repos
  project  = data.gitlab_project.repo[each.key].id
  title    = "agent-devbox (hermes)"
  key      = trimspace(file("${path.module}/${var.agent_deploy_key_path}"))
  can_push = true
}

# GitLab -> GitHub, protected branches only, so GitHub only ever gets what you merged.
# GitLab generates the SSH key; add its public half to the GitHub repo as a deploy key with write
# access (README.md has the command to fetch it).
resource "gitlab_project_push_mirror" "github" {
  for_each                = var.mirror_repos
  project                 = data.gitlab_project.repo[each.key].id
  url                     = "ssh://git@github.com/${var.github_owner}/${each.key}.git"
  auth_method             = "ssh_public_key"
  host_keys               = [local.github_host_key]
  only_protected_branches = true
  # If main on GitHub got a commit GitLab doesn't have, skip it instead of overwriting it.
  keep_divergent_refs = true
  enabled             = true

  depends_on = [gitlab_branch_protection.main]
}
