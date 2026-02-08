FROM ubuntu:latest

ARG DEBIAN_FRONTEND=noninteractive

# Create a non-root user (Homebrew refuses to run as root)
RUN apt-get update && apt-get install -y sudo \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER testuser
WORKDIR /home/testuser

CMD ["bash"]
