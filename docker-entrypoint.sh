#!/bin/sh

set -e

# activate our virtual environment here
. /home/app/cookiecutter-poetry-pypackage/.venv/bin/activate

# You can put other setup logic here

# Evaluating passed command:
exec "$@"
