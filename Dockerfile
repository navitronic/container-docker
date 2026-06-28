FROM ubuntu:26.04

ENV container=container
ENV DEBIAN_FRONTEND=noninteractive

# Install systemd, dbus, and essential tools
RUN apt-get update && \
    apt-get install -y \
      dbus systemd \
      openssh-server \
      net-tools iproute2 iputils-ping \
      curl wget ca-certificates \
      gnupg lsb-release \
      sudo vim-tiny man && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    (yes | unminimize 2>/dev/null || true)

# Reset machine-id so each machine instance gets a unique one
RUN >/etc/machine-id
RUN >/var/lib/dbus/machine-id

# Mask systemd units that don't apply inside a container machine VM
RUN systemctl set-default multi-user.target && \
    systemctl mask \
      dev-hugepages.mount \
      sys-fs-fuse-connections.mount \
      systemd-update-utmp.service \
      systemd-tmpfiles-setup.service \
      console-getty.service && \
    systemctl disable networkd-dispatcher.service 2>/dev/null || true

# Install Docker CE via official repository
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources-docker.list && \
    cp /etc/apt/sources-docker.list /etc/apt/sources.list.d/docker.list && \
    rm /etc/apt/sources-docker.list && \
    apt-get update && \
    apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure Docker daemon for TCP access on the vmnet interface
COPY daemon.json /etc/docker/daemon.json

# Override Docker systemd unit to remove the -H fd:// flag
# (conflicts with hosts in daemon.json)
RUN mkdir -p /etc/systemd/system/docker.service.d && \
    printf '[Service]\nExecStart=\nExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock\n' \
      > /etc/systemd/system/docker.service.d/override.conf

# Enable Docker to start on boot
RUN systemctl enable docker

# Install QEMU user-static for amd64 emulation (runs x86_64 container images on arm64)
RUN apt-get update && \
    apt-get install -y qemu-user-static binfmt-support && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Fix SSH config for container machine use
RUN sed -i -e 's/^AcceptEnv LANG LC_\*$/#AcceptEnv LANG LC_*/' /etc/ssh/sshd_config

VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]
