#!/bin/bash

cd "$(git rev-parse --show-toplevel)"

git config core.hooksPath .githooks/
helmfile repos

