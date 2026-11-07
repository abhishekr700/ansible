terraform {
  required_version = ">= 1.7" # for_each in import blocks

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "19.5.0"
    }
  }
}
