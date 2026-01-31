# Hermes Ansible Setup

Device: `Raspberry Pi 4 - Bangalore Home`

> Naming ideology: God of communication and travel
> apt for device whose primary purpose is network filtering device (adguard home)

## Playbooks Overview

- **setup-hermes.yaml**: Main playbook for setting up Hermes (network, docker, home assistant, etc.).
- **setup-expense-tracker-hermes.yaml**: Playbook for setting up the expense tracker project only.
- **setup-hermes-all.yaml**: Master playbook that runs both setup-hermes.yaml and setup-expense-tracker-hermes.yaml in sequence.

### Usage

- To run the full Hermes setup (including the expense tracker), use:

  ```sh
  ansible-playbook hermes/setup-hermes-all.yaml
  ```

- To run only the main Hermes setup (without expense tracker):

  ```sh
  ansible-playbook hermes/setup-hermes.yaml
  ```

- To run only the expense tracker setup:

  ```sh
  ansible-playbook hermes/setup-expense-tracker-hermes.yaml
  ```

> **Note:** The master playbook (setup-hermes-all.yaml) ensures all components are set up in the correct order.
