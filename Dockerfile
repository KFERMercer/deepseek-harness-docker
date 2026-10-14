# syntax=docker/dockerfile:1
#
# deepseek-harness (dsh) - DeepSeek agent harness, Web UI
#
# Build: `docker build -t dsh .`
# Run: `docker run -it --rm --network host -u $(id -u):$(id -g) -v ./:/work -v <dsh data>:/dsh -v <agents home>:/agents dsh web`

ARG DSH_VERSION=latest # or something like `0.1.0-rc.6`
ARG PNPM_VERSION=latest # or something like `12.5.1`

FROM node:slim AS base

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources

ARG DEBIAN_FRONTEND=noninteractive

RUN <<EOT
	apt-get update
	apt-get install -y --no-install-recommends ca-certificates git
EOT


FROM base AS builder

RUN apt-get install -y --no-install-recommends g++ make

ARG DSH_VERSION

RUN npm install -g --prefix /opt/dsh "@deepseek-ai/dsh@${DSH_VERSION}"


FROM base AS final

# Add the official GitHub CLI Debian repo
ADD --chmod=0644 https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	/etc/apt/keyrings/githubcli-archive-keyring.gpg
RUN <<EOT
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
		| install -m 0644 /dev/stdin /etc/apt/sources.list.d/github-cli.list
	apt-get update
EOT

RUN apt-get install -y --no-install-recommends bash-completion bubblewrap curl file gh sudo tzdata wget

RUN echo 'ALL ALL=(ALL:ALL) NOPASSWD: ALL' | install -m 0440 /dev/stdin /etc/sudoers.d/99-all-users

RUN <<EOT
	install -d -m 1777 /agents /dsh /work
	ln -s /agents /home/node/.agents
	ln -s /dsh /home/node/.dsh
	ln -s /work /home/node/work
	install -d -o node -g node /home/node/.config
	install -d -o node -g node /home/node/.local/bin
	install -d -o node -g node /home/node/.local/lib
	install -d -o node -g node /home/node/.local/share
	install -d -o node -g node /home/node/.local/state
EOT

ARG PNPM_VERSION

RUN npm install -g --cache /tmp/npm-cache "pnpm@${PNPM_VERSION}"

RUN <<EOT
	shopt -s dotglob nullglob
	rm -rf /tmp/* /dev/shm/* /run/shm/* /var/log/* /var/tmp/* /var/lib/apt/lists/*
EOT

COPY --from=builder /opt/dsh /opt/dsh

ENV PATH="/opt/dsh/bin:${PATH}"

ENV DSH_TELEMETRY_DISABLED=1
ENV DSH_HOME="/dsh"
ENV DSH_AGENTS_HOME="/agents"

ENTRYPOINT ["dsh"]
