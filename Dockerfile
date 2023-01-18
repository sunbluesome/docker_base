FROM nvidia/cuda:11.4.0-devel-ubuntu20.04 as base
LABEL maintainer="haruki@hacarus.com"

SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    \
    # python
    PYTHONVERSION="3.8.6" \
    PYTHONUNBUFFERED=1 \
    # prevents python creating .pyc files
    PYTHONDONTWRITEBYTECODE=1 \
    \
    # pip
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    \
    # poetry
    # https://python-poetry.org/docs/configuration/#using-environment-variables
    POETRY_VERSION=1.2.0 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_CREATE=false \
    # do not ask any interactive question
    POETRY_NO_INTERACTION=1
# prepend poetry and venv to path
ENV PATH="$POETRY_HOME/bin:$PATH" \
    HOME="/home" \
    WORKDIR="/work"

FROM base as python-base
# for cuda
RUN apt-key adv --fetch-keys https://developer.download.nvidia.cn/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub
RUN apt-get update \
 && apt-get install --no-install-recommends -y \
    build-essential \
    fonts-ipaexfont \
    libglib2.0-0 \
    git \
    gcc \
    make \
    cmake \
    vim \
    pip \
    curl \
    wget \
    openssh-client \
    # to install python
    zlib1g-dev \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    llvm \
    libncurses5-dev \
    xz-utils \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    # to install opencv
    libgl1-mesa-dev
# for neovim plugins
RUN apt-get update \
 && curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
 && apt-get install --no-install-recommends -y \
    zip \
    unzip \
    gzip \
    nodejs


# install user local directory to avoid permission problems
# (Apply `chmod` for $HOME at the end of this Dockerfile)
RUN wget https://www.python.org/ftp/python/${PYTHONVERSION}/Python-${PYTHONVERSION}.tar.xz \
 && tar xJf Python-${PYTHONVERSION}.tar.xz \
 && cd Python-${PYTHONVERSION} \
 && ./configure \
 && make \
 && make install \
 && cd ../ \
 && rm -rf Python*
# register installed python as default
RUN update-alternatives --install /usr/bin/python python /usr/local/bin/python3 0


# For initializing project.
FROM python-base as initial
# install poetry for global.
# `poetry` commands are freely available as root.
RUN python3 -m pip install --upgrade pip \
 && curl -sSL https://install.python-poetry.org | python3 -
WORKDIR $WORKDIR


# For developmental use.
FROM initial as development
COPY pyproject.toml poetry.lock ./
COPY modules ./modules
RUN poetry install --no-root
# RUN poetry config repositories.hacaruspypi https://pypi.hacarus.com/simple/ \
#  && poetry config http-basic.hacaruspypi "$PYPI_USER" "$PYPI_PASSWORD" \
#  && poetry install

# `poetry` commands are freely available as a local user.
RUN poetry install \
 && find /usr/local -type d -print | xargs chmod 777 \
 && find $HOME -type d -print | xargs chmod 777 \
 && find $HOME/.cache/pypoetry -type f -print | xargs chmod 777

EXPOSE 8888

COPY entrypoint.sh ./entrypoint.sh
ENTRYPOINT /bin/bash entrypoint.sh

