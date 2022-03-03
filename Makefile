.PHONY: help
.PHONY: clean clean-build clean-pyc clean-test
.PHONY: poetry-init poetry-requirements-txt poetry-requirements-dev-txt
.PHONY: version-bump-major version-bump-minor version-bump-patch
.PHONY: lint test test-all coverage
.PHONY: build publish install
.PHONY: docker-build docker-rm docker-run docker-publish
.PHONY: openfaas-deploy
.DEFAULT_GOAL := help

########
# help #
########
help: ## Prints all available targets w/ descriptions (Default Target)
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

#########
# clean #
#########
clean: clean-build clean-pyc clean-test ## remove all build, test, coverage and Python artifacts

clean-build: ## remove build artifacts
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

clean-pyc: ## remove Python file artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +

clean-test: ## remove test and coverage artifacts
	rm -fr .tox/
	rm -f .coverage
	rm -fr htmlcov/
	rm -fr .pytest_cache

##########
# poetry #
##########
poetry-install:
	rm -f poetry.lock
	poetry install

poetry-requirements-txt: ## export dependencies to requirements.txt
	poetry export --without-hashes -f requirements.txt > requirements.txt

###############
# lint & test #
###############
lint: ## check style with flake8
	poetry run flake8 cookiecutter_poetry_pyproject tests

test: ## run tests quickly with the default Python
	poetry run pytest

test-all: ## run tests on every Python version with tox
	poetry run tox

coverage: ## check code coverage quickly with the default Python
	poetry run coverage run --source cookiecutter_poetry_pyproject -m pytest
	poetry run coverage report -m

###################
# build & publish #
###################
POETRY_PYPI_REPO_URL ?= # Set environment variable to override
POETRY_PYPI_TOKEN_PYPI ?= # Set environment variable to use
POETRY_HTTP_BASIC_PYPI_USERNAME ?= # Set environment variable to use
POETRY_HTTP_BASIC_PYPI_PASSWORD ?= # Set environment variable to use

build: clean ## builds source and wheel package
	poetry build

publish: build ## package and upload a release
	poetry config repositories.publish $(POETRY_PRIVATE_REPO_URL) --local
	poetry publish

###########
# install #
###########
ENVIRONMENT ?= development

install:  clean ## install the package to the active Python's site-packages
ifeq ($(ENVIRONMENT), development)
	$(MAKE) poetry-install
else
	pip install .
endif

##########
# docker #
##########
PROJECT_NAME = $(shell poetry version | cut -d ' ' -f 1)
GIT_SHORT_HASH = $(shell git rev-parse --short HEAD)
DOCKER_RUN_CMD ?= help
VERSION = 0.0.0
ifndef LABEL
TAG = bot-anomaly-detector-fn:$(VERSION)
else
TAG = bot-anomaly-detector-fn:$(VERSION)_$(LABEL)
endif

docker-build:  ## build docker container
	docker build -t $(TAG) .

docker-rm: ## delete previously named docker container
	@echo 'Removing previous containers...'
	docker rm $(GIT_SHORT_HASH) &>/dev/null || echo 'No previous containers found.'

docker-run: docker-rm  ## runs named docker container
	docker run --name $(GIT_SHORT_HASH) \
		-e POETRY_PYPI_REPO_URL=$(POETRY_PYPI_REPO_URL) \
		-e POETRY_PYPI_TOKEN_PYPI=$(POETRY_PYPI_TOKEN_PYPI) \
		-e POETRY_HTTP_BASIC_PYPI_USERNAME=$(POETRY_HTTP_BASIC_PYPI_USERNAME) \
		-e POETRY_HTTP_BASIC_PYPI_PASSWORD=$(POETRY_HTTP_BASIC_PYPI_PASSWORD) \
		-i $(PROJECT_NAME) $(DOCKER_RUN_CMD)

docker-publish:
	$(MAKE) docker-build
	docker login proget.repo.symbotic.corp -u $(DOCKER_USER) -p $(DOCKER_PASS)
	docker tag $(TAG) proget.repo.symbotic.corp/dev_images/library/$(TAG)
	docker push proget.repo.symbotic.corp/dev_images/library/$(TAG)

#############
# openfaas  #
#############
openfaas-deploy:
	faas-cli login -g $(OPENFAAS_URL) --password $(OPENFAAS_PASS)
	faas-cli template pull
	faas-cli deploy -f bot-anomaly-detector.yml

#######
# git #
#######

git-prune-merged-branches:
	git checkout master
	git fetch --prune
	git branch --merged master | grep -v "^[ *]*master\$$" | xargs git branch -d

git-prune-deleted-branches:
	git checkout master
	git fetch --prune
	git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -D
