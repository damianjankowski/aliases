#!/bin/bash

PRE_COMMIT_HOOKS_VERSION="v5.0.0"
RUFF_PRE_COMMIT_VERSION="v0.12.4"
MYPY_VERSION="v1.13.0"
BANDIT_VERSION="1.8.0"

_check_pyenv_setup() {
    if ! command -v pyenv >/dev/null 2>&1; then
        echo "Error: pyenv is not installed. Please install pyenv first." >&2
        echo "Installation guide: https://github.com/pyenv/pyenv#installation" >&2
        return 1
    fi
    if ! pyenv commands | grep -q "virtualenv"; then
        echo "Error: pyenv-virtualenv plugin not found." >&2
        echo "Install it: https://github.com/pyenv/pyenv-virtualenv#installation" >&2
        return 1
    fi
    return 0
}

get_unique_project_name() {
    local current_dir parent_dir project_name
    current_dir=$(basename "$PWD")
    parent_dir=$(basename "$(dirname "$PWD")")

    if [[ "$parent_dir" == "$HOME" || "$parent_dir" == "src" || "$parent_dir" == "dev" || "$parent_dir" == "projects" ]]; then
        project_name="$current_dir"
    else
        project_name="${parent_dir}-${current_dir}"
    fi

    project_name=$(echo "$project_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/^-*\|-*$//g')

    # Ensure name doesn't start with number
    if [[ "$project_name" =~ ^[0-9] ]]; then
        project_name="project-${project_name}"
    fi

    echo "$project_name"
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
        echo "Error: Python version ${version} is not installed" >&2
        return 1
    fi
    return 0
}

pyenv_versions() {
    _check_pyenv_setup || return 1
    echo "Running: pyenv install --list"
    echo "Installed Python versions:"
    pyenv versions
    echo -e "\nLatest available versions:"
    pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | tail -3
}

pyenv_install() {
    _check_pyenv_setup || return 1
    local python_version=${1:-$(pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | tail -1 | tr -d '[:space:]')}
    echo "Running: pyenv install -s "$python_version""

    if ! [[ "$python_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid Python version format. Use X.Y.Z format" >&2
        return 1
    fi

    echo "Installing Python $python_version..."
    pyenv install -s "$python_version"
}

create_venv() {
    _check_pyenv_setup || return 1
    
    local python_version=${1:-$(pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | tail -1 | tr -d '[:space:]')}
    local venv_name="${python_version}-$(get_unique_project_name)"

    if ! validate_python_version "$python_version"; then
        pyenv_install "$python_version" || return 1
    fi

    echo "Creating virtual environment: $venv_name"
    pyenv virtualenv -f "$python_version" "$venv_name" || return 1
    pyenv local "$venv_name"
    echo "Virtual environment '$venv_name' created and activated"
}


delete_venv() {
    _check_pyenv_setup || return 1

    local venv_name=$1

    if [ "$venv_name" = "--all" ]; then
        echo "Delete ALL pyenv virtual environments? (y/n)"
        read -r confirm
        if [ "$confirm" != "y" ]; then
            echo "Operation cancelled"
            return 0
        fi

        local venvs
        venvs=$(pyenv virtualenvs --bare)
        if [ -z "$venvs" ]; then
            echo "No virtual environments found"
            return 0
        fi

        echo "$venvs" | while read -r venv; do
            echo "Deleting virtual environment '$venv'..."
            pyenv uninstall -f "$venv"
        done

        if [ -f .python-version ]; then
            rm .python-version
            echo "Removed .python-version file"
        fi

        echo "All virtual environments deleted"
        return 0
    fi

    if [ -z "$venv_name" ]; then
        echo "Error: Please provide a virtual environment name or '--all'" >&2
        echo "Usage: pydel <venv-name> | --all" >&2
        return 1
    fi

    if ! pyenv virtualenvs --bare | grep -qx "$venv_name"; then
        echo "Error: Virtual environment '$venv_name' does not exist" >&2
        echo "Available environments:"
        pyenv virtualenvs
        return 1
    fi

    echo "Delete virtual environment '$venv_name'? (y/n)"
    read -r answer
    if [ "$answer" != "y" ]; then
        echo "Operation cancelled"
        return 0
    fi

    pyenv uninstall -f "$venv_name" || return 1

    if [ -f .python-version ] && [ "$(cat .python-version)" = "$venv_name" ]; then
        rm .python-version
        echo "Removed .python-version file"
    fi

    echo "Virtual environment '$venv_name' deleted"
}


list_venvs() {
    _check_pyenv_setup || return 1
    echo "Available virtual environments:"
    pyenv virtualenvs
}

clean_cache() {
    echo "Cleaning Python cache files..."
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
    find . -type f -name "*.pyc" -delete 2>/dev/null
    find . -type f -name "*.pyo" -delete 2>/dev/null
    find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null
    find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null
    find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null
    find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null
    echo "Cache cleaned"
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
        echo "Error: No virtual environment is active" >&2
        echo "Please activate a virtual environment first" >&2
        return 1
    fi

    if ! command -v pre-commit >/dev/null 2>&1; then
        echo "Installing pre-commit..."
        pip install pre-commit || return 1
    fi

    if [ ! -f ".pre-commit-config.yaml" ]; then
        echo "Creating pre-commit configuration..."
        _create_precommit_config
    fi

    echo "Installing pre-commit hooks..."
    pre-commit install || return 1
    echo "Pre-commit setup completed"
}

run_precommit() {
    _check_pyenv_setup || return 1
    
    if [ -z "$PYENV_VIRTUAL_ENV" ]; then
        echo "Error: No virtual environment is active" >&2
        return 1
    fi

    if ! command -v pre-commit >/dev/null 2>&1; then
        echo "Error: pre-commit not installed. Run 'setup_precommit' first" >&2
        return 1
    fi

    echo "Running pre-commit checks..."
    pre-commit run --all-files
}

# ---- Aliases ----
alias pyv="pyenv_versions"
alias pyi="pyenv_install"
alias pyvenv="create_venv"
alias pydel="delete_venv"
alias pylsvenv="list_venvs"
alias pyclean="clean_cache"
alias pyprecommit="setup_precommit"
alias pychecks="run_precommit"