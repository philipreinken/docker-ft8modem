# There's also the possibility of using a local directory for the source code.
# In that case, set the FT8MODEM_DISTRIBUTION argument to "local" and place the
# source code in a directory named "ft8modem" in the same directory as this Dockerfile.
ARG FT8MODEM_DISTRIBUTION="web"

FROM debian:bookworm-slim AS base

FROM base AS runtime_deps

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  <<EOF
  apt-get update && apt-get install -y --no-install-recommends \
    librtaudio6 \
    libsndfile1 \
    wsjtx \
    python3 \
    python3-pip
EOF

FROM runtime_deps AS build_deps

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  <<EOF
  apt-get update && apt-get install -y --no-install-recommends \
    librtaudio-dev \
    libsndfile1-dev \
    cmake \
    git \
    autoconf \
    libtool \
    automake \
    build-essential
EOF

FROM base AS ft8modem_source_web_prepare

ARG FT8MODEM_SOURCE_ARCHIVE_URL
ARG FT8MODEM_SOURCE_ARCHIVE_SHA256

ADD --link --checksum="sha256:${FT8MODEM_SOURCE_ARCHIVE_SHA256}" ${FT8MODEM_SOURCE_ARCHIVE_URL} /ft8modem.tar.gz

RUN <<EOF
  mkdir -p /ft8modem
  tar -xzf /ft8modem.tar.gz -C /ft8modem --strip-components=1
  rm /ft8modem.tar.gz
EOF

FROM scratch AS ft8modem_source_web

COPY --link --from=ft8modem_source_web_prepare /ft8modem /ft8modem

FROM scratch AS ft8modem_source_local

COPY --link ./ft8modem /ft8modem

FROM ft8modem_source_${FT8MODEM_DISTRIBUTION} AS ft8modem_source

FROM build_deps AS build_ft8modem

COPY --link ./ft8modem.cc.patch /ft8modem.cc.patch
COPY --link ./sc.h.patch /sc.h.patch
COPY --link ./ft8qso.patch /ft8qso.patch

COPY --link --from=ft8modem_source /ft8modem /ft8modem

WORKDIR /ft8modem

RUN <<EOF
  patch -p1 ft8modem.cc < /ft8modem.cc.patch
  patch -p1 sc.h < /sc.h.patch
  patch -p1 ft8qso < /ft8qso.patch

  make
  make install
EOF

FROM runtime_deps AS final

COPY --link --from=build_ft8modem  /usr/local/bin /usr/local/bin
COPY --link --from=build_ft8modem /usr/local/lib/ft8modem/* /usr/local/lib/ft8modem/

RUN useradd -ms /bin/bash ft8modem

USER ft8modem

VOLUME ["/home/ft8modem"]

ENTRYPOINT ["/usr/local/bin/ft8modem"]

FROM final