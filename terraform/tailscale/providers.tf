# Credentials come from the environment only:
#   TAILSCALE_OAUTH_CLIENT_ID, TAILSCALE_OAUTH_CLIENT_SECRET
# "-" means "the tailnet the OAuth client belongs to".
provider "tailscale" {
  tailnet = "-"
}
