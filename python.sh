#!/bin/bash

PRE_COMMIT_HOOKS_VERSION="v5.0.0"
RUFF_PRE_COMMIT_VERSION="v0.12.4"
MYPY_VERSION="v1.13.0"
BANDIT_VERSION="1.8.0"

_check_pyenv_setup() {
  if ! command -v pyenv >/dev/null 2>&1; then
    printf "Error: pyenv is not installed. Please install pyenv first.\n" >&2
    printf "Installation guide: https://github.com/pyenv/pyenv#installation\n" >&2
    return 1
  fi
  if ! pyenv commands | grep -q "virtualenv"; then
    printf "Error: pyenv-virtualenv plugin not found.\n" >&2
    printf "Install it: https://github.com/pyenv/pyenv-virtualenv#installation\n" >&2
    return 1
  fi
  return 0
}

get_unique_project_name() {
  local current_dir parent_dir project_name
  current_dir="$(basename "$PWD")"
  parent_dir="$(basename "$(dirname "$PWD")")"
  if [[ "$parent_dir" == "$HOME" || "$parent_dir" == "src" || "$parent_dir" == "dev" || "$parent_dir" == "projects" ]]; then
    project_name="$current_dir"
  else
    project_name="${parent_dir}-${current_dir}"
  fi
  project_name="$(printf "%s" "$project_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/^-*\\|-*$//g')"
  if [[ "$project_name" =~ ^[0-9] ]]; then
    project_name="project-${project_name}"
  fi
  printf "%s\n" "$project_name"
}

get_venv_name() {
  if [ -f ".python-version" ]; then
    head -n 1 .python-version | tr -d '[:space:]'
    return 0
  fi
  return 1
}

validate_python_version() {
  local version=$1
  if ! pyenv versions --bare | grep -q "^${version}$"; then
    printf "Error: Python version %s is not installed\n" "$version" >&2
    return 1
  fi
  return 0
}

_latest_patch_version() {
  pyenv install --list | grep -E "^[[:space:]]*[0-9]+\\.[0-9]+\\.[0-9]+$" | tail -1 | tr -d '[:space:]'
}

pyenv_versions() {
  _check_pyenv_setup || return 1
  printf "Running: pyenv install --list\n"
  printf "Installed Python versions:\n"
  pyenv versions
  printf "\nLatest available versions:\n"
  pyenv install --list | grep -E "^[[:space:]]*[0-9]+\\.[0-9]+\\.[0-9]+$" | tail -3
}

pyenv_install() {
  _check_pyenv_setup || return 1
  local python_version=${1:-$(_latest_patch_version)}
  printf "Running: pyenv install -s %s\n" "$python_version"
  if ! [[ "$python_version" =~ ^[0-9]+\\.[0-9]+\\.[0-9]+$ ]]; then
    printf "Error: Invalid Python version format. Use X.Y.Z format\n" >&2
    return 1
  fi
  printf "Installing Python %s...\n" "$python_version"
  pyenv install -s "$python_version"
}

create_venv() {
  _check_pyenv_setup || return 1
  local python_version=${1:-$(_latest_patch_version)}
  local venv_name="${python_version}-$(get_unique_project_name)"
  if ! validate_python_version "$python_version"; then
    pyenv_install "$python_version" || return 1
  fi
  printf "Creating virtual environment: %s\n" "$venv_name"
  pyenv virtualenv -f "$python_version" "$venv_name" || return 1
  pyenv local "$venv_name"
  printf "Virtual environment '%s' created and activated\n" "$venv_name"
}

delete_venv() {
  _check_pyenv_setup || return 1
  local venv_name=$1
  if [ "$venv_name" = "--all" ]; then
    printf "Delete ALL pyenv virtual environments? (y/n)\n"
    read -r confirm
    if [ "$confirm" != "y" ]; then
      printf "Operation cancelled\n"
      return 0
    fi
    local venvs
    venvs="$(pyenv virtualenvs --bare)"
    if [ -z "$venvs" ]; then
      printf "No virtual environments found\n"
      return 0
    fi
    printf "%s\n" "$venvs" | while read -r venv; do
      printf "Deleting virtual environment '%s'...\n" "$venv"
      pyenv uninstall -f "$venv"
    done
    if [ -f .python-version ]; then
      rm .python-version
      printf "Removed .python-version file\n"
    fi
    printf "All virtual environments deleted\n"
    return 0
  fi

  if [ -z "$venv_name" ]; then
    printf "Error: Please provide a virtual environment name or '--all'\n" >&2
    printf "Usage: pydel <venv-name> | --all\n" >&2
    return 1
  fi

  if ! pyenv virtualenvs --bare | grep -qx "$venv_name"; then
    printf "Error: Virtual environment '%s' does not exist\n" "$venv_name" >&2
    printf "Available environments:\n"
    pyenv virtualenvs
    return 1
  fi

  printf "Delete virtual environment '%s'? (y/n)\n" "$venv_name"
  read -r answer
  if [ "$answer" != "y" ]; then
    printf "Operation cancelled\n"
    return 0
  fi

  pyenv uninstall -f "$venv_name" || return 1

  if [ -f .python-version ] && [ "$(cat .python-version)" = "$venv_name" ]; then
    rm .python-version
    printf "Removed .python-version file\n"
  fi

  printf "Virtual environment '%s' deleted\n" "$venv_name"
}

list_venvs() {
  _check_pyenv_setup || return 1
  printf "Available virtual environments:\n"
  pyenv virtualenvs
}

clean_cache() {
  printf "Cleaning Python cache files...\n"
  find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
  find . -type f -name "*.pyc" -delete 2>/dev/null
  find . -type f -name "*.pyo" -delete 2>/dev/null
  find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null
  find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null
  find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null
  find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null
  printf "Cache cleaned\n"
}

_create_precommit_config() {
  cat > .pre-commit-config.yaml << EOF
repos:
-   repo: https://github.com/pre-commit/pre-commit-hooks
    rev: ${PRE_COMMIT_HOOKS_VERSION}
    hooks:
    -   id: trailing-whitespace
    -   id: end-of-file-fixer
    -   id: check-yaml
    -   id: check-toml
    -   id: check-json
    -   id: check-added-large-files
    -   id: check-merge-conflict
    -   id: debug-statements

-   repo: https://github.com/astral-sh/ruff-pre-commit
    rev: ${RUFF_PRE_COMMIT_VERSION}
    hooks:
    -   id: ruff
        args: [--fix, --exit-non-zero-on-fix]
    -   id: ruff-format

-   repo: https://github.com/pre-commit/mirrors-mypy
    rev: ${MYPY_VERSION}
    hooks:
    -   id: mypy
        additional_dependencies: [types-requests, types-PyYAML]
        args: [--ignore-missing-imports]

-   repo: https://github.com/PyCQA/bandit
    rev: ${BANDIT_VERSION}
    hooks:
    -   id: bandit
        args: [-r, ., --skip, B101]
        exclude: ^tests/
EOF
}

setup_precommit() {
  _check_pyenv_setup || return 1
  if [ -z "$PYENV_VIRTUAL_ENV" ]; then
    printf "Error: No virtual environment is active\n" >&2
    printf "Please activate a virtual environment first\n" >&2
    return 1
  fi
  if ! command -v pre-commit >/dev/null 2>&1; then
    printf "Installing pre-commit...\n"
    pip install pre-commit || return 1
  fi
  if [ ! -f ".pre-commit-config.yaml" ]; then
    printf "Creating pre-commit configuration...\n"
    _create_precommit_config
  fi
  printf "Installing pre-commit hooks...\n"
  pre-commit install || return 1
  printf "Pre-commit setup completed\n"
}

run_precommit() {
  _check_pyenv_setup || return 1
  if [ -z "$PYENV_VIRTUAL_ENV" ]; then
    printf "Error: No virtual environment is active\n" >&2
    return 1
  fi
  if ! command -v pre-commit >/dev/null 2>&1; then
    printf "Error: pre-commit not installed. Run 'setup_precommit' first\n" >&2
    return 1
  fi
  printf "Running pre-commit checks...\n"
  pre-commit run --all-files
}

alias pyv="pyenv_versions"
alias pyi="pyenv_install"
alias pyvenv="create_venv"
alias pydel="delete_venv"
alias pylsvenv="list_venvs"
alias pycleancache="clean_cache"
alias pyprecommit="setup_precommit"
alias pychecks="run_precommit"
alias pyclean="pip uninstall -y -r <(pip freeze | grep -viE '^(pip|setuptools)==')"
alias pyupdate="pip list --outdated --format=columns | awk '{print $1}' | xargs -I {} pip install -U {}"