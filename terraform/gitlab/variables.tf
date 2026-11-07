variable "gitlab_namespace" {
  description = "Your GitLab username: the namespace the repos were imported into."
  type        = string
}

variable "github_owner" {
  description = "GitHub account the repos are mirrored back to."
  type        = string
  default     = "abhishekr700"
}

variable "repos" {
  # Not `ansible`: it configures every host, so it stays out of the dev agent's reach (see TODO.md, homelab agent).
  description = "Repos the agent may push branches to. Same name on GitLab and GitHub."
  type        = set(string)
  default = [
    "email-filter-script",
    "expense-splitwise-bridge",
    "expenseTracker",
    "foodies-app",
  ]
}

variable "mirror_repos" {
  description = "Repos whose main is push-mirrored to GitHub. Start with one, test, then add the rest."
  type        = set(string)
  default     = []

  validation {
    condition     = length(setsubtract(var.mirror_repos, var.repos)) == 0
    error_message = "mirror_repos must be a subset of repos."
  }
}

variable "agent_deploy_key_path" {
  description = "Public half of the agent's deploy key, fetched by agent-devbox/setup-agent-devbox-git.yaml."
  type        = string
  default     = "agent-deploy-key.pub"
}
