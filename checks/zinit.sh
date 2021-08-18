#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

check_git_remote "${HOME}/.zinit/bin" origin "git@github.com:zdharma/zinit.git"
