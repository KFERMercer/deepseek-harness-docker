# syntax=docker/dockerfile:1
#
# deepseek-harness (dsh) - DeepSeek agent harness, Web UI
# Official image-less deployment: installs the published @deepseek-ai/dsh npm package.
# Requires: Linux kernel with Landlock >= 5.13 (optional; falls back when unavailable)
#
# Build: `docker build -t dsh .`
# Run: `docker run -it --rm --network host -u $(id -u):$(id -g) -v ./:/work -v <dsh data>:/dsh -v <agents home>:/agents dsh web`
# Web UI: http://127.0.0.1:3080

ARG DSH_VERSION=latest # or something like `0.1.0-rc.6`

FROM node:slim AS base

ARG DEBIAN_FRONTEND noninteractive

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

RUN npm install -g --prefix /opt/dsh "@deepseek-ai/dsh@${DSH_VERSION}"


FROM base AS final

COPY --from=builder /opt/dsh /opt/dsh

RUN <<EOT
	apt-get install -y --no-install-recommends \
		sudo
EOT

RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/* /run/shm/* /dev/shm/*

RUN <<EOT
	echo 'ALL ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-all-users
	chmod 0440 /etc/sudoers.d/99-all-users
EOT

ENV PATH="/opt/dsh/bin:${PATH}"

ENV DSH_TELEMETRY_DISABLED=1
ENV DSH_HOME="/dsh"
ENV DSH_AGENTS_HOME="/agents"

RUN mkdir -p -m 1777 /work /dsh /agents

WORKDIR /work

# USER 1000

# EXPOSE 3080

# HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
# 	CMD node -e "fetch('http://127.0.0.1:3080').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["dsh"]
