# AGENTS.md

## Project

Ubuntu container machine image for Apple Container that runs Docker Engine, replacing Docker Desktop as the Docker host for local development.

## Stack

- Apple Container v1.0.0 (macOS 26, Apple silicon)
- Ubuntu 26.04 LTS (codename "resolute")
- Docker CE 29.x with docker-compose-plugin
- systemd as PID 1 inside the container machine VM
- QEMU user-static for amd64 emulation on arm64

## Architecture

macOS runs the Docker CLI. It connects to Docker Engine inside an Apple Container machine VM over TCP on the private vmnet network (192.168.64.0/24). The VM's home directory is auto-mounted from macOS, so docker-compose volume mounts referencing macOS paths work transparently.

```
macOS (DOCKER_HOST=tcp://<machine-ip>:2375)
  → Docker Engine inside Apple Container machine VM
    → App containers (managed by Docker Engine)
```

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Ubuntu 26.04 image with systemd, Docker CE, QEMU amd64 emulation |
| `daemon.json` | Docker daemon config — TCP listener on :2375, host-gateway-ip for host.docker.internal |
| `Makefile` | Build/lifecycle targets: setup, build, create, run, stop, destroy |
| `setup-host.sh` | Configures macOS DOCKER_HOST, verifies connectivity and volume mounts |
| `README.md` | Quickstart, troubleshooting |

## Build and Run

```sh
make setup        # Build image + create machine
./setup-host.sh   # Configure DOCKER_HOST, verify connectivity
make stop         # Stop the machine (Docker state persists)
make destroy      # Remove machine and all Docker state
```

## Conventions

- Makefile is the entry point for all lifecycle operations
- Variables (`IMAGE_NAME`, `MACHINE_NAME`, `CPUS`, `MEMORY`) are overridable via `make VAR=value`
- Default machine name is `docker-vm`
- Docker daemon listens on TCP 2375 (no TLS — private vmnet only)
- setup-host.sh auto-detects the machine IP; falls back from DNS (.test) to IP address

## Known Constraints

- `.test` DNS domains may not resolve from macOS without `sudo container system dns create test`. The setup script handles this by falling back to the machine's IP address.
- Docker daemon is exposed without TLS. This is acceptable because the vmnet network (192.168.64.0/24) is private to the Mac host.
- Apple Container VMs don't release freed memory back to macOS. Periodic `make stop && make run` reclaims memory.
- The `host-gateway-ip` in daemon.json is hardcoded to `192.168.64.1` (the default vmnet gateway). If a user has a custom network subnet in `~/.config/container/config.toml`, this value needs to match their gateway.
- amd64 container images run via QEMU emulation — slower than native arm64 images.
- Volume mounts only work for paths under the macOS home directory (auto-mounted by the container machine). Paths outside `$HOME` are not accessible to Docker.

## Rebuilding

After changing the Dockerfile or daemon.json:

```sh
make stop && make destroy && make setup
```

The machine must be destroyed and recreated — `make build` alone only rebuilds the image.
