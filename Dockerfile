# syntax=docker/dockerfile:1.4

ARG BUILD_HASH=dev-build

# Override at your own risk - non-root configurations are untested
ARG UID=0
ARG GID=0

######## Backend ########
FROM python:3.12-slim-bookworm AS base

# Install deps and make paths
ARG UID
ARG GID

WORKDIR /app/

ENV HOME=/root

# Create user and group if not root
RUN if [ $UID -ne 0 ]; then \
    if [ $GID -ne 0 ]; then \
    addgroup --gid $GID app; \
    fi; \
    adduser --uid $UID --gid $GID --home $HOME --disabled-password --no-create-home app; \
    fi

# make dir
RUN mkdir -p /app/

# Make sure the user has access to the app and root directory
RUN chown -R $UID:$GID /app $HOME

# install curl + build-essential for rust
RUN apt-get update && apt-get -y install curl build-essential

# Install Rust to build tiktoken
RUN curl --proto '=https' --tlsv1.3 https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH=/root/.cargo/bin:$PATH

# install poetry
RUN --mount=type=cache,target=/root/.cache/pip curl -sSL https://install.python-poetry.org | python3 -
ENV PATH=/root/.local/bin/:$PATH

# poetry install
COPY --chown=$UID:$GID ./pyproject.toml ./pyproject.toml
COPY --chown=$UID:$GID ./poetry.lock ./poetry.lock
RUN --mount=type=cache,target=/root/.cache/pip poetry lock --no-update && poetry install 

# copy backend files
COPY --chown=$UID:$GID ./entropix ./entropix
COPY --chown=$UID:$GID ./README.md .
COPY --chown=$UID:$GID ./download_weights.py .

USER $UID:$GID

ARG BUILD_HASH
ENV ENTROPIX_BUILD_VERSION=${BUILD_HASH}
ENV DOCKER=true

ENV PYTHONPATH=.

CMD [ "poetry", "run", "python", "/app/entropix/main.py" ] 
