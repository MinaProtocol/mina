#!/usr/bin/env bash
source "$HOME/.nvm/nvm.sh"
nvm use 20
claude --allowedTools "Read" "Edit" "Write" "Glob" "Grep" "Bash(git:*)" "Bash(gh:*)" "Bash(ls:*)" "Bash(cat:*)" "Bash(find:*)" "Bash(head:*)" "Bash(tail:*)" "Bash(wc:*)" "Bash(dune:*)" "Bash(make:*)" -- "Read AGENT.md to understand the task, then run /port-old-pr. Your branch (ai/port-17466/builder) is the PR branch."
