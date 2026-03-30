# syntax=docker/dockerfile:1

# Build stage: accept the pre-built STM32 toolchain from the build context.
# The caller must run build-toolchain.sh first so that install-native/ is present.
FROM ubuntu:24.04 AS builder

COPY install-native/ /opt/stm32-toolchain/

# Final stage: minimal runtime image containing only the toolchain and its
# required shared libraries.
FROM ubuntu:24.04

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libncurses6 \
       libexpat1 \
       zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/stm32-toolchain/ /opt/stm32-toolchain/
COPY LICENSE.md /licenses/LICENSE.md

ENV PATH="/opt/stm32-toolchain/bin:${PATH}"

LABEL org.opencontainers.image.source="https://github.com/grahame-org/gnu-tools-for-stm32" \
      org.opencontainers.image.description="GNU Tools for STM32 – arm-none-eabi cross-compilation toolchain" \
      org.opencontainers.image.licenses="SEE_LICENSE"
