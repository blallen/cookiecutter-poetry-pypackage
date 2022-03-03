# using https://github.com/michaeloliverx/python-poetry-docker-example as a template

###############################################
# Base Image
###############################################
# `python-base` sets up all our shared environment variables
# not alpine because https://pythonspeed.com/articles/alpine-docker-python/
FROM python:3.8.12-slim as python-base

    # python
ENV PYTHONUNBUFFERED=1 \
    # prevents python creating .pyc files
    PYTHONDONTWRITEBYTECODE=1 \
    # pip
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    # make poetry install to this location
    POETRY_HOME="/opt/poetry" \
    # make poetry create the virtual environment in the project's root
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    # do not ask any interactive question
    POETRY_NO_INTERACTION=1 \
    # this is where our requirements + virtual environment will live
    PYSETUP_PATH="/opt/pysetup" \
    VENV_PATH="/opt/pysetup/.venv"

# prepend poetry and venv to path
ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$PATH"


###############################################
# Builder Image
###############################################
# `builder-base` stage is used to build deps + create our virtual environment
FROM python-base as builder-base
# hadolint ignore=DL3008
RUN apt-get update && apt-get install --no-install-recommends -y curl build-essential

# install poetry - respects $POETRY_VERSION & $POETRY_HOME
ENV POETRY_VERSION=1.1.7
# hadolint ignore=DL4006
RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py | python -

# copy project requirement files here to ensure they will be cached.
WORKDIR $PYSETUP_PATH
COPY poetry.lock pyproject.toml ./

# install runtime deps - uses $POETRY_VIRTUALENVS_IN_PROJECT internally
RUN poetry install --no-dev

# export requirements.txt for inference stage
RUN poetry export -f requirements.txt --output requirements.txt --without-hashes


###############################################
# Development Image
###############################################
# `development` image is used during development / testing
FROM python-base as development

# copy in our built poetry + venv
WORKDIR $PYSETUP_PATH
COPY --from=builder-base $POETRY_HOME $POETRY_HOME
COPY --from=builder-base $PYSETUP_PATH $PYSETUP_PATH

# Copying in our entrypoint
COPY ./docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# quicker install as runtime deps are already installed
RUN poetry install

# copy source code
COPY . .

# set up poetry shell
# hadolint ignore=DL3025
ENTRYPOINT /docker-entrypoint.sh $0 $@
CMD ["pytest"]


###############################################
# Production Image
###############################################
# 'production' stage uses the clean 'python-base' stage and copyies
# in only our runtime deps that were installed in the 'builder-base'
FROM python-base as production

# copy virtual env
COPY --from=builder-base $VENV_PATH $VENV_PATH

# Copying in our entrypoint
COPY ./docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# copy source code
COPY {{ cookiecutter.project_slug }} {{ cookiecutter.project_slug }}

# set up poetry shell
# hadolint ignore=DL3025
ENTRYPOINT /docker-entrypoint.sh $0 $@
CMD ["pytest"]
