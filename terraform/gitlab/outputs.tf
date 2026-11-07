output "projects" {
  description = "Project ids and default branches, for the mirror key lookup in README.md."
  value = {
    for k, p in data.gitlab_project.repo : k => {
      id             = p.id
      default_branch = p.default_branch
      ssh_url        = p.ssh_url_to_repo
    }
  }
}

output "mirror_ids" {
  description = "Push mirror ids, for fetching each mirror's public key."
  value       = { for k, m in gitlab_project_push_mirror.github : k => m.mirror_id }
}
