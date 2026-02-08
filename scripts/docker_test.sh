#!/bin/bash

docker build -t dotfiles-test -f test/Dockerfile .
docker run -it --rm -v ~/dotfiles:/home/testuser/dotfiles dotfiles-test
