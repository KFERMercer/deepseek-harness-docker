# syntax=docker/dockerfile:1
#
# deepseek-harness (dsh) - DeepSeek agent harness, Web UI
#
# Build: `docker build -t dsh .`
# Run: `docker run -it --rm --network host -u $(id -u):$(id -g) -v ./:/work -v <dsh data>:/dsh -v <agents home>:/agents dsh web`

ARG DSH_VERSION=latest # or something like `0.1.0-rc.6`
ARG PNPM_VERSION=latest # or something like `12.5.1`

FROM node:slim AS base

ARG DEBIAN_FRONTEND=noninteractive

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources

RUN <<EOT
	apt-get update
	apt-get install -y --no-install-recommends \
		git \
		ca-certificates
EOT


FROM base AS builder

ARG DSH_VERSION

RUN <<EOT
	apt-get install -y --no-install-recommends \
		python3 \
		make \
		g++
EOT

RUN <<EOT
	npm install -g --prefix /opt/dsh "@deepseek-ai/dsh@${DSH_VERSION}"
EOT


FROM base AS final

ARG PNPM_VERSION

COPY --from=builder /opt/dsh /opt/dsh

RUN <<EOT
	npm install -g --cache /tmp/npm-cache "pnpm@${PNPM_VERSION}"
	rm -rf /tmp/npm-cache /tmp/* /var/tmp/* /var/log/* /run/shm/* /dev/shm/*
EOT

# # Add the official GitHub CLI Debian repo
# ADD --chmod=0644 https://cli.github.com/packages/githubcli-archive-keyring.gpg \
# 	/etc/apt/keyrings/githubcli-archive-keyring.gpg
# RUN <<EOT
# 	echo \
# 		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
# 		> /etc/apt/sources.list.d/github-cli.list
# 	apt-get update
# EOT

RUN <<EOT
	apt-get install -y --no-install-recommends \
		sudo \
		curl wget \
		file \
		bash-completion \
		gh
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/* /run/shm/* /dev/shm/*
EOT

RUN <<EOT
	echo 'ALL ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-all-users
	chmod 0440 /etc/sudoers.d/99-all-users
EOT

RUN <<EOT
	mkdir -p -m 1777 /work /agents /dsh
	ln -s /work /root/work
	ln -s /work /home/node/work
	ln -s /agents /root/.agents
	ln -s /agents /home/node/.agents
	ln -s /dsh /root/.dsh
	ln -s /dsh /home/node/.dsh
EOT

ENV PATH="/opt/dsh/bin:${PATH}"

ENV DSH_TELEMETRY_DISABLED=1
ENV DSH_HOME="/dsh"
ENV DSH_AGENTS_HOME="/agents"

WORKDIR /work

ENTRYPOINT ["node","--expose-internals","/opt/dsh/bin/dsh"]
