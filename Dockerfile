# syntax=docker/dockerfile:1.4

#######################################################################################
# base stage, with the non-python runtime dependencies
#

FROM ghcr.io/acsone/odoo-bedrock:16.0-py311-latest as base

# Install apt runtime dependencies.
# - postgresql-client for comfort in the shell container and for db dump to work
# - expect to have unbuffer in CI
# - gettext for click-odoo-makepot in CI
RUN set -e \
  && apt update \
  && apt -y install --no-install-recommends \
       postgresql-client \
       expect \
       gettext \
       libxmlsec1-openssl \
  && apt -y clean \
  && rm -rf /var/lib/apt/lists/*

#######################################################################################
# builds-deps stage, where we download requirements-build.txt,
# and install tools necessary to build source distributions.
#

FROM base as build-deps

# Install git.
RUN set -e \
  && apt update \
  && apt -y install --no-install-recommends \
       git \
       openssh-client \
       python3.11-dev \
       build-essential \
       libpq-dev \
       pkg-config libxml2-dev libxmlsec1-dev \
  && apt -y clean \
  && rm -rf /var/lib/apt/lists/*

# Configure ssh.
RUN mkdir $HOME/.ssh \
  && echo "Host github.com\n  StrictHostKeyChecking no" >> $HOME/.ssh/config \
  && echo "PubkeyAcceptedKeyTypes=+ssh-rsa" >> $HOME/.ssh/config

# Configure pip:
# - use pep517 builds always (no setup.py bdist_wheel)
# - constraint build depdendencies for better reproducibility
ENV PIP_USE_PEP517=1 PIP_CONSTRAINTS=/build-deps/requirements-build.txt

# Download build dependencies to /build-deps.
# --only-binary=:all: is to avoid trying building build dependencies from source
# --no-deps is to make sure we have pinned them all
COPY requirements-build.txt /build-deps/
RUN pip wheel --only-binary=:all: --no-deps --wheel-dir=/build-deps -r /build-deps/requirements-build.txt

#######################################################################################
# devcontainer stage, install development tools.

FROM build-deps as devcontainer

# Add some dev tools.
RUN apt update \
 && apt -y install pipx sudo
ENV PIPX_BIN_DIR=/usr/local/bin \
    PIPX_HOME=/usr/local/pipx
RUN pipx install pip-deepfreeze

# Add dev user with sudo rights.
# We name it odoo so the bedrock image entrypoint does not attempt to create it.
ARG USERNAME=odoo
ARG USER_UID=1000
ARG USER_GID=$USER_UID
# LOCAL_USER_ID is used in the bedrock image entrypoint
ENV LOCAL_USER_ID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

#######################################################################################
# build stage
# --no-deps is to make sure we have pinned all dependencies
#

FROM build-deps as build
COPY requirements.txt /tmp/requirements.txt
RUN --mount=type=ssh \
    --mount=type=cache,target=/root/.cache/pip \
    pip wheel --no-deps --wheel-dir=/build -r /tmp/requirements.txt

#######################################################################################
# dependencies stage, installs wheels from build stages on top of other runtime deps.
# This stage basically installs everything we need at runtime, except the app itself.
# It is separated from the build stage to avoid having build tools in the runtime image.
#

FROM base as dependencies

# Install python dependencies we built in the build stage.
# Use --no-deps and --no-index to be sure to not download anything else.

RUN --mount=type=bind,target=/build,source=/build,from=build \
  pip install --no-deps --no-index /build/*.whl

#######################################################################################
# runtime stage, installs the app in editable mode, on top of dependencies.
#

FROM dependencies as runtime

# Install the app in editable mode.
# Here we don't use --no-deps but we do use --no-index to be sure that all dependencies
# have been installed before (i.e. they have been pinned in requirements.txt).
COPY . /app
RUN --mount=type=bind,target=/build-deps,source=/build-deps,from=build-deps \
  --mount=type=cache,target=/root/.cache/pip \
  pip install --no-index --find-links /build-deps --editable /app
