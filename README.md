# container-docker

An Ubuntu container machine image for [Apple Container](https://github.com/apple/container) that runs Docker Engine as a systemd service. A lightweight Docker Desktop replacement for macOS development.

## Prerequisites

- macOS 26 on Apple silicon
- [Apple Container](https://github.com/apple/container/releases) installed and running:
  ```sh
  brew install container
  container system start
  ```
- Docker CLI on macOS: `brew install docker docker-compose`

## Quickstart

```sh
make setup            # Build image and create the container machine
source env.sh         # Set DOCKER_HOST for this shell
docker info           # Verify it works
```

Add `env.sh` to your shell profile so `DOCKER_HOST` is set in every new terminal:

```sh
echo 'source /path/to/container-docker/env.sh' >> ~/.zshrc
```

To run the full verification suite (prerequisites, connectivity, volume mounts):

```sh
make verify
```

## How It Works

```
macOS (docker CLI / docker compose)
  │
  │  DOCKER_HOST=tcp://docker-vm.test:2375
  │
  ▼
Apple Container Machine ("docker-vm")
  ├── systemd (PID 1)
  ├── Docker Engine (TCP :2375)
  ├── /Users/<you> (auto-mounted from macOS)
  └── App containers (managed by Docker Engine)
```

The container machine is a persistent Ubuntu VM running on Apple Container's lightweight virtualisation. Your macOS home directory is automatically mounted inside the VM at the same path, so docker-compose volume mounts like `-v /Users/you/Projects/app:/app` work without any extra configuration.

## Docker Compose

Once `DOCKER_HOST` is set in your shell, `docker compose` works as normal:

```sh
docker compose up -d
docker compose exec app bash
```

Volume mounts referencing macOS paths (e.g., `-v /Users/you/Projects/app:/app`) work transparently because the container machine auto-mounts your home directory.

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make setup` | Build image + create machine (full bootstrap) |
| `make build` | Build the container image |
| `make create` | Create the container machine |
| `make run` / `make shell` | Interactive shell in the machine |
| `make stop` | Stop the machine |
| `make destroy` | Remove machine and all Docker state |
| `make status` | Show machine details (JSON) |
| `make docker-status` | Check Docker daemon status |
| `make verify` | Check prerequisites, connectivity, and volume mounts |

Override defaults: `make create CPUS=8 MEMORY=16G`

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `IMAGE_NAME` | `local/docker-vm` | OCI image tag |
| `MACHINE_NAME` | `docker-vm` | Container machine name |
| `CPUS` | `4` | Virtual CPUs |
| `MEMORY` | `8G` | RAM allocation |
| `CONTAINER_DOCKER_MACHINE` | `docker-vm` | Machine name used by `env.sh` (set in shell profile before sourcing) |

## Troubleshooting

**Docker daemon not reachable**

Check the machine is running: `make docker-status`. If not, start it with `make run` (then type `exit` to return to macOS — the machine keeps running in the background).

**DNS not resolving (docker-vm.test)**

Ensure `container system start` has been run. If DNS still fails, `env.sh` falls back to the machine's IP address automatically. You can also get the IP manually:

```sh
container machine inspect docker-vm | grep address
export DOCKER_HOST=tcp://<ip>:2375
```

**Docker daemon not started inside the machine**

SSH into the machine and check systemd:

```sh
make shell
systemctl status docker
journalctl -u docker --no-pager -n 50
```

**Memory usage growing over time**

Apple Container VMs don't release freed memory back to macOS. Periodic restarts reclaim it:

```sh
make stop && make run
```
