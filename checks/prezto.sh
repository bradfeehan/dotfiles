#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

check_git_remote "${HOME}/.zprezto" origin "git@github.com:bradfeehan/prezto.git"
