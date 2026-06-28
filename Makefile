IMAGE_NAME  ?= local/docker-vm
MACHINE_NAME ?= docker-vm
CPUS        ?= 4
MEMORY      ?= 8G

.PHONY: help build create setup run shell stop destroy status docker-status

help:
	@echo "Usage:"
	@echo "  make setup          Build image and create machine (full bootstrap)"
	@echo "  make build          Build the container image"
	@echo "  make create         Create the container machine from the image"
	@echo "  make run            Start an interactive shell in the machine"
	@echo "  make shell          Alias for run"
	@echo "  make stop           Stop the machine"
	@echo "  make destroy        Remove the machine and its storage"
	@echo "  make status         Show machine details (JSON)"
	@echo "  make docker-status  Check Docker daemon status inside the machine"
	@echo ""
	@echo "Variables (override with make VAR=value):"
	@echo "  IMAGE_NAME   $(IMAGE_NAME)"
	@echo "  MACHINE_NAME $(MACHINE_NAME)"
	@echo "  CPUS         $(CPUS)"
	@echo "  MEMORY       $(MEMORY)"

build:
	container build -t $(IMAGE_NAME) -f Dockerfile .

create:
	container machine create $(IMAGE_NAME) --name $(MACHINE_NAME) --set-default --cpus $(CPUS) --memory $(MEMORY)

setup: build create

run:
	container machine run -n $(MACHINE_NAME)

shell: run

stop:
	container machine stop $(MACHINE_NAME)

destroy:
	container machine rm $(MACHINE_NAME)

status:
	container machine inspect $(MACHINE_NAME)

docker-status:
	container machine run -n $(MACHINE_NAME) -- systemctl status docker
