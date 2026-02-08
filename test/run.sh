#!/bin/bash
set -e

cd "$(dirname "$0")/.."

docker build -t dotfiles-test -f test/Dockerfile .
docker run -it --rm -v "$PWD":/home/testuser/dotfiles dotfiles-test
