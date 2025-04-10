# Ansible Role: debian-install-docker

This Ansible role installs Docker on Debian and Ubuntu systems. It follows the official Docker installation guide and includes best practices for Docker daemon configuration.

## Requirements

- Debian or Ubuntu system
- Ansible 2.9 or higher
- Root privileges (become: true)

## Role Variables

Available variables are listed below, along with default values:

```yaml
# User to add to the docker group
docker_user: "{{ ansible_user }}"

# Docker daemon configuration
docker_daemon_config:
  log-driver: "json-file"
  log-opts:
    max-size: "100m"
    max-file: "3"
  default-ulimits:
    nofile:
      name: "nofile"
      hard: 64000
      soft: 64000
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: servers
  become: true
  roles:
    - role: debian-install-docker
      vars:
        docker_user: "myuser"
        docker_daemon_config:
          log-driver: "json-file"
          log-opts:
            max-size: "50m"
            max-file: "2"
```

## Role Testing

To test the role:

1. Clone this repository
2. Navigate to the role directory
3. Run the test playbook:

```bash
ansible-playbook tests/test.yml
```

## License

MIT

## Author Information

This role was created by Abhishek Ranjan.

## Role Tasks

The role performs the following tasks:

1. Installs required system packages
2. Adds Docker's official GPG key
3. Sets up Docker repository
4. Installs Docker packages (docker-ce, docker-ce-cli, containerd.io)
5. Configures Docker daemon
6. Ensures Docker service is running and enabled
7. Adds specified user to docker group

## Security Notes

- The role adds the specified user to the docker group, which effectively gives root access
- Docker daemon configuration is secured with proper file permissions
- GPG key verification is implemented for package authenticity