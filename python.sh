#!/bin/bash
# Python aliases

# ---- Configuration ----
PRE_COMMIT_HOOKS_VERSION="v5.0.0"
ISORT_VERSION="5.12.0"
BLACK_VERSION="24.1.1"
RUFF_PRE_COMMIT_VERSION="v0.2.1"

# ---- Helper functions ----

_check_pyenv_setup() {
    if ! command -v pyenv >/dev/null 2>&1; then
        echo "Error: pyenv is not installed. Please install pyenv to use this script." >&2
        echo "For installation instructions, see: https://github.com/pyenv/pyenv#installation" >&2
        return 1
    fi
    if ! pyenv commands | grep -q "virtualenv"; then
        echo "Error: pyenv-virtualenv plugin not found." >&2
        echo "Please install it: https://github.com/pyenv/pyenv-virtualenv#installation" >&2
        return 1
    fi
    return 0
}

get_unique_project_name() {
    local project_name

    # Use a parent-directory-project-directory naming scheme
    local current_dir
    local parent_dir
    current_dir=$(basename "$PWD")
    parent_dir=$(basename "$(dirname "$PWD")")

    # Avoid using home directory or generic names as a prefix
    if [[ "$parent_dir" == "$HOME" || "$parent_dir" == "src" || "$parent_dir" == "dev" || "$parent_dir" == "projects" || "$parent_dir" == "." || "$parent_dir" == "$current_dir" ]]; then
         project_name="$current_dir"
    else
         project_name="${parent_dir}-${current_dir}"
    fi

    # Sanitize the name to be compliant with pyenv virtualenv naming
    # - Replace invalid characters with a hyphen
    # - Remove leading/trailing hyphens
    # - Ensure it doesn't start with a number (pyenv constraint)
    local sanitized_name
    sanitized_name=$(echo "$project_name" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-zA-Z0-9]/-/g' -e 's/^-*//' -e 's/-*$//')
    
    if [[ "$sanitized_name" =~ ^[0-9] ]]; then
        sanitized_name="project-${sanitized_name}"
    fi

    echo "$sanitized_name"
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
        echo "Error: Python version ${version} is not installed"
        return 1
    fi
    return 0
}

# ---- Python version management ----

pyenv_versions() {
    _check_pyenv_setup || return 1
    echo "Installed Python versions:"
    pyenv versions
    echo -e "\nLatest available patch for the 3 most recent minor versions:"
    pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | sed 's/^[ \t]*//' | sort -rV | awk -F. '!seen[$1"."$2]++' | head -n 3 | sed 's/^/  /' >&2
}

pycleanversions() {
    _check_pyenv_setup || return 1

    echo "Analyzing installed Python versions to find old and unused patches..." >&2

    local all_installed
    all_installed=$(pyenv versions --bare | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -u)
    if [ -z "$all_installed" ]; then
        echo "No installed Python versions found." >&2
        return 0
    fi

    local latest_installed
    latest_installed=$(echo "$all_installed" | sort -V | awk -F. '{key=$1"."$2; versions[key]=$0} END {for (k in versions) print versions[k]}')

    local old_versions
    old_versions=$(echo "$all_installed" | grep -vFf <(echo "$latest_installed"))

    if [ -z "$old_versions" ]; then
        echo "No old Python patch versions to clean up." >&2
        return 0
    fi

    local versions_to_delete_safely=""
    local versions_to_delete_with_deps=""
    local venvs_to_delete=""
    local current_global_version
    current_global_version=$(pyenv global)
    
    local current_local_version=""
    if [ -f .python-version ]; then
        current_local_version=$(cat .python-version)
    fi

    echo "Checking for active virtual environments (this may take a moment)..." >&2
    local venv_info
    venv_info=$(pyenv virtualenvs)

    for v in $old_versions; do
        if [[ "$current_global_version" == "$v" || "$current_local_version" == "$v" ]]; then
            continue # Skip protected versions
        fi

        local dependent_venvs
        dependent_venvs=$(echo "$venv_info" | grep "(created from .*versions/${v})" | awk '{print $1}')

        if [ -z "$dependent_venvs" ]; then
            versions_to_delete_safely+="$v"$'\n'
        else
            echo "" >&2
            echo "Old version '$v' is used by the following virtual environment(s):" >&2
            echo "$dependent_venvs" | sed 's/^/  - /' >&2
            echo -n "Delete this Python version AND its dependent venv(s)? (y/n) " >&2
            read -r answer
            if [[ "$answer" == "y" ]]; then
                versions_to_delete_with_deps+="$v"$'\n'
                venvs_to_delete+="$dependent_venvs"$'\n'
            fi
        fi
    done
    
    versions_to_delete_safely=$(echo "$versions_to_delete_safely" | sed '/^$/d')
    versions_to_delete_with_deps=$(echo "$versions_to_delete_with_deps" | sed '/^$/d')
    venvs_to_delete=$(echo "$venvs_to_delete" | sed '/^$/d')

    if [ -z "$versions_to_delete_safely" ] && [ -z "$versions_to_delete_with_deps" ]; then
        echo "No old or unused Python versions found to clean up. Your installation is tidy!"
        return 0
    fi

    echo "" >&2
    echo "--- Cleanup Plan ---" >&2

    if [ -n "$venvs_to_delete" ]; then
        echo "The following virtual environments will be DELETED:" >&2
        echo "$venvs_to_delete" | sed 's/^/  - /' >&2
    fi
    
    local all_versions_to_delete
    all_versions_to_delete=$(echo -e "${versions_to_delete_safely}\n${versions_to_delete_with_deps}" | sed '/^$/d' | sort -u)

    if [ -n "$all_versions_to_delete" ]; then
        echo "The following Python versions will be DELETED:" >&2
        echo "$all_versions_to_delete" | sed 's/^/  - /' >&2
    fi
    
    echo "This action cannot be undone." >&2
    echo -n "Proceed with the cleanup plan? (y/n) " >&2
    read -r answer

    if [[ "$answer" != "y" ]]; then
        echo "Cleanup cancelled."
        return 0
    fi

    echo "Starting cleanup..."
    if [ -n "$venvs_to_delete" ]; then
        echo "$venvs_to_delete" | while read -r venv; do
            echo "Deleting virtualenv $venv..."
            pyenv virtualenv-delete -f "$venv"
        done
    fi

    if [ -n "$all_versions_to_delete" ]; then
        echo "$all_versions_to_delete" | while read -r version; do
            echo "Uninstalling Python version $version..."
            pyenv uninstall -f "$version"
        done
    fi

    echo "Cleanup complete."
    return 0
}

pyenv_install() {
    _check_pyenv_setup || return 1
    local python_version
    local user_input

    if [ -z "$1" ]; then
        echo "Which Python version do you want to install? (Leave blank for latest)"
        read -r user_input
        if [ -z "$user_input" ]; then
            python_version=$(pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | tail -1 | tr -d '[:space:]')
            echo "Installing latest Python version: $python_version"
        else
            python_version=$user_input
        fi
    else
        python_version=$1
    fi

    if ! [[ "$python_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid Python version format. Use format X.Y.Z"
        return 1
    fi

    echo "Installing Python $python_version..."
    if ! pyenv install -s "$python_version"; then
        echo "Error: Failed to install Python $python_version"
        return 1
    fi
    
    echo "Python $python_version installed successfully"
    return 0
}

# ---- Virtual environment management ----

_create_py_venv() {
    _check_pyenv_setup || return 1
    local python_version=$1
    local venv_name=$2

    if ! validate_python_version "$python_version"; then
        if ! pyenv_install "$python_version"; then
            return 1
        fi
    fi
    
    echo "Creating virtualenv: $venv_name"
    if ! pyenv virtualenv -f "$python_version" "$venv_name"; then
        echo "Error: Failed to create virtual environment"
        return 1
    fi

    pyenv local "$venv_name"
    echo "Virtualenv '$venv_name' created and set as local version"
}

_get_python_version() {
    local user_input
    local python_version
    if [ -z "$1" ]; then
        echo "Which Python version do you want to use? (Leave blank for the latest available)" >&2
        echo "" >&2
        echo "Latest available patch for the 3 most recent minor versions:" >&2
        pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | sed 's/^[ \t]*//' | sort -rV | awk -F. '!seen[$1"."$2]++' | head -n 3 | sed 's/^/  /' >&2
        echo "Provide a version number (e.g. 3.12.0):" >&2
        read -r user_input
        
        if [ -z "$user_input" ]; then
            python_version=$(pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | tail -1 | tr -d '[:space:]')
            echo "Using latest Python version: $python_version" >&2
        else
            python_version=$user_input
        fi
    else
        python_version=$1
    fi
    echo "$python_version"
}

_create_precommit_config_file() {
    if [ -f ".pre-commit-config.yaml" ]; then
        echo ".pre-commit-config.yaml already exists"
        return 0
    fi
    echo "Creating basic pre-commit configuration..."
    cat > .pre-commit-config.yaml << EOF
repos:
-   repo: https://github.com/pre-commit/pre-commit-hooks
    rev: ${PRE_COMMIT_HOOKS_VERSION}
    hooks:
    -   id: trailing-whitespace
        stages: [pre-commit]
    -   id: end-of-file-fixer
        stages: [pre-commit]
    -   id: check-yaml
        stages: [pre-commit]
    -   id: check-added-large-files
        stages: [pre-commit]

-   repo: https://github.com/pycqa/isort
    rev: ${ISORT_VERSION}
    hooks:
    -   id: isort
        stages: [pre-commit]

-   repo: https://github.com/psf/black
    rev: ${BLACK_VERSION}
    hooks:
    -   id: black
        language_version: python3
        stages: [pre-commit]

-   repo: https://github.com/astral-sh/ruff-pre-commit
    rev: ${RUFF_PRE_COMMIT_VERSION}
    hooks:
    -   id: ruff
        args: [--fix, --exit-non-zero-on-fix]
        stages: [pre-commit]
EOF
}

_create_makefile_common() {
    cat << EOF
# Environment
# -----------------------------------------------------------------------------
ENV_FILE := .env

ifneq (,\$(wildcard \$(ENV_FILE)))
    include \$(ENV_FILE)
    export
endif

# Default Goal
# -----------------------------------------------------------------------------
.DEFAULT_GOAL := help

# Help
# -----------------------------------------------------------------------------
.PHONY: help
help:  ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_-]+:.*?##/ { \
			printf "  \033[36m%-30s\033[0m %s\n", \$\$1, \$\$2 \
		} \
		/^##@/ { \
			printf "\n%s\n", substr(\$\$0, 5) \
		} ' \$(MAKEFILE_LIST)
# Development
# -----------------------------------------------------------------------------
.PHONY: clean
##@ Cleaning
clean:  ## Clean up Python cache files
	find . -type d -name "__pycache__" -exec rm -r {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name "*.pyd" -delete
	find . -type d -name "*.egg-info" -exec rm -r {} +
	find . -type d -name "*.egg" -exec rm -r {} +
	find . -type d -name ".pytest_cache" -exec rm -r {} +
	find . -type d -name ".ruff_cache" -exec rm -r {} +
	find . -type d -name ".mypy_cache" -exec rm -r {} +
EOF
}

create_venv() {
    _check_pyenv_setup || return 1
    local python_version
    python_version=$(_get_python_version "$1")
    if [ -z "$python_version" ]; then return 1; fi
    local venv_name="${python_version}-$(get_unique_project_name)"
    _create_py_venv "$python_version" "$venv_name" || return 1
    echo "Note: Environment will be automatically activated when entering this directory"
}

activate_venv() {
    _check_pyenv_setup || return 1
    local venv_name
    if [ -n "$1" ]; then
        venv_name=$1
    else
        venv_name=$(get_venv_name)
        if [ $? -ne 0 ]; then
            echo "Error: No virtual environment specified and no .python-version file found." >&2
            echo "Usage: pyact [venv-name]" >&2
            return 1
        fi
    fi

    if [ -z "$venv_name" ]; then
        echo "Error: Virtual environment name cannot be empty." >&2
        return 1
    fi
    
    if ! pyenv virtualenvs --bare | grep -q "^${venv_name}$"; then
        echo "Error: Virtualenv '$venv_name' does not exist"
        echo "Available virtualenvs:"
        pyenv virtualenvs
        return 1
    fi

    echo "Activating virtualenv: $venv_name"
    pyenv activate "$venv_name"
    return 0
}

deactivate_venv() {
    _check_pyenv_setup || return 1
    if [ -z "$PYENV_VIRTUAL_ENV" ]; then
        echo "No virtual environment is currently active"
        return 1
    fi
    
    pyenv deactivate
    echo "Virtual environment deactivated"
    return 0
}

delete_venv() {
    _check_pyenv_setup || return 1
    local venv_name=$1
    
    if [ -z "$venv_name" ]; then
        echo "Error: Please provide a virtual environment name"
        echo "Usage: pydel <venv-name>"
        return 1
    fi

    # Check if the virtualenv exists
    if ! pyenv virtualenvs --bare | grep -q "^${venv_name}$"; then
        echo "Error: Virtualenv '$venv_name' does not exist"
        echo "Available virtualenvs:"
        pyenv virtualenvs
        return 1
    fi

    echo "This will delete virtualenv '$venv_name'. Are you sure? (y/n)"
    read -r answer
    if [ "$answer" != "y" ]; then
        echo "Operation cancelled"
        return 0
    fi

    if ! pyenv uninstall -f "$venv_name"; then
        echo "Error: Failed to delete virtualenv '$venv_name'"
        return 1
    fi

    # Remove .python-version file if it exists and points to this venv
    if [ -f .python-version ] && [ "$(cat .python-version)" = "$venv_name" ]; then
        rm .python-version
        echo "Removed .python-version file"
    fi

    echo "Virtualenv '$venv_name' deleted"
    return 0
}

list_venvs() {
    _check_pyenv_setup || return 1
    echo "Available virtualenvs:"
    pyenv virtualenvs
    return 0
}

# ---- Dependency management ----

update_packages() {
    _check_pyenv_setup || return 1
    if [ -z "$PYENV_VIRTUAL_ENV" ]; then
        echo "Error: No virtual environment is active" >&2
        return 1
    fi

    if [ -f "pyproject.toml" ] && grep -q '\[tool\.poetry\]' "pyproject.toml"; then
        echo "Poetry project detected. Updating dependencies with poetry..."
        if ! poetry update; then
            echo "Error: Failed to update packages with poetry" >&2
            return 1
        fi
    else
        echo "Updating all packages with pip..."
        if ! pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip install -U; then
            echo "Error: Failed to update packages with pip" >&2
            return 1
        fi
    fi
    
    echo "All packages updated successfully"
    return 0
}

clean_packages() {
    _check_pyenv_setup || return 1
    if [ -z "$PYENV_VIRTUAL_ENV" ]; then
        echo "Error: No virtual environment is active"
        return 1
    fi

    echo "This will uninstall all packages. Continue? (y/n)"
    read -r answer
    if [[ "$answer" != "y" ]]; then
        echo "Operation cancelled"
        return 0
    fi

    if ! pip freeze | grep -v '^-e' | xargs pip uninstall -y; then
        echo "Error: Failed to uninstall packages"
        return 1
    fi

    echo "All packages uninstalled successfully"
    return 0
}

# ---- Development tools ----

setup_precommit() {
    _check_pyenv_setup || return 1
    if [ -z "$PYENV_VIRTUAL_ENV" ]; then
        echo "Error: No virtual environment is active"
        return 1
    fi

    if ! command -v pre-commit >/dev/null 2>&1; then
        echo "Error: pre-commit is not installed. Please install it using: pip install pre-commit"
        return 1
    fi
    
    if [ ! -f ".pre-commit-config.yaml" ]; then
        echo "Creating basic pre-commit configuration..."
        _create_precommit_config_file
    fi
    
    echo "Installing pre-commit hooks..."
    if ! pre-commit install; then
        echo "Error: Failed to install pre-commit hooks"
        return 1
    fi

    echo "Pre-commit setup completed successfully"
    return 0
}

create_makefile() {
    if [ -f "Makefile" ]; then
        echo "Makefile already exists"
        return 0
    fi

    echo "Creating Makefile..."
    {
        _create_makefile_common
        cat << EOF

.PHONY: install-dev install check

##@ Installation
install-dev:  ## Install development dependencies
	pip install -e ".[dev]"

install:  ## Install all dependencies
	pip install -e .

##@ Checks
check: ## Run all checks
    poetry run pre-commit run --all-files
EOF
    } > Makefile

    echo "Makefile created successfully"
    return 0
}

run_precommit() {
    _check_pyenv_setup || return 1
    if [ -z "$PYENV_VIRTUAL_ENV" ]; then
        echo "Error: No virtual environment is active"
        return 1
    fi

    if ! command -v pre-commit >/dev/null 2>&1; then
        echo "Error: pre-commit not installed. Run 'setup_precommit' first"
        return 1
    fi

    echo "Running pre-commit on all files..."
    if ! pre-commit run --all-files; then
        echo "Error: Pre-commit checks failed"
        return 1
    fi

    echo "Pre-commit checks passed successfully"
    return 0
}

# ---- Poetry project management ----

create_poetry_makefile() {
    if [ -f "Makefile" ]; then
        echo "Makefile already exists"
        return 0
    fi

    echo "Creating Makefile for Poetry project..."
    {
        _create_makefile_common
        cat << EOF

.PHONY: test install-dev install check

##@ Testing
test:  ## Run tests
	poetry run pytest

##@ Installation
install-dev:  ## Install development dependencies
	poetry install --only dev

install:  ## Install all dependencies
	poetry install

##@ Checks
check:  ## Run all checks
	poetry run pre-commit run --all-files

##@ All
all: check  ## Run all checks (default target)
EOF
    } > Makefile

    echo "Makefile created successfully"
    return 0
}

_initialize_git() {
    if [ ! -d ".git" ]; then
        echo "Initializing git repository..."
        git init
        git add .
        git commit -m "Initial commit"
    fi
}

_ensure_pipx_installed() {
    if command -v pipx >/dev/null 2>&1; then
        return 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        echo "Error: Homebrew is required to install pipx automatically. Please install Homebrew or pipx manually." >&2
        return 1
    fi

    echo "Installing pipx..."
    if ! brew install pipx; then
        echo "Error: Failed to install pipx" >&2
        return 1
    fi
    
    pipx ensurepath
    # The following export is to make pipx available in the current shell session.
    export PATH="$PATH:$HOME/.local/bin"
    echo "pipx is now available in this session. For permanent changes, please open a new terminal."
}

_ensure_poetry_installed() {
    if command -v poetry >/dev/null 2>&1; then
        return 0
    fi

    echo "Installing poetry via pipx..."
    if ! pipx install poetry; then
        echo "Error: Failed to install poetry" >&2
        return 1
    fi
}

_initialize_poetry_project() {
    local project_name=$1
    local python_version=$2
    
    echo "Configuring poetry..."
    poetry config virtualenvs.create false
    poetry config virtualenvs.in-project false

    echo "Initializing poetry project: $project_name"
    if ! poetry init --name "$project_name" --description "A Python project" --author "$(git config user.name) <$(git config user.email)>" --python "^$python_version" --dependency "black" --dependency "isort" --dependency "ruff" --dependency "pytest" --dev-dependency "pre-commit" --no-interaction; then
        echo "Error: Failed to initialize poetry project" >&2
        return 1
    fi
    return 0
}

_scaffold_poetry_project_structure() {
    local project_name=$1
    echo "Creating project structure..."
    mkdir -p "$project_name" tests
    touch "$project_name/__init__.py" tests/__init__.py

    cat > README.md << EOF
# $project_name

## Development

### Setup

1. Install dependencies:
\`\`\`bash
poetry install
\`\`\`

2. Install pre-commit hooks:
\`\`\`bash
poetry run pre-commit install
\`\`\`

### Usage

- Run tests: \`make test\`
- Format code: \`make format\`
- Run linting: \`make lint\`
- Run all checks: \`make check\`
EOF
}

_install_poetry_dependencies_and_hooks() {
    echo "Installing dependencies..."
    if ! poetry install; then
        echo "Error: Failed to install dependencies" >&2
        return 1
    fi

    echo "Installing pre-commit hooks..."
    if ! poetry run pre-commit install; then
        echo "Error: Failed to install pre-commit hooks" >&2
        return 1
    fi
    return 0
}

create_poetry_project() {
    _check_pyenv_setup || return 1
    
    _initialize_git

    local project_name
    project_name=$(get_unique_project_name)

    local python_version
    python_version=$(_get_python_version "$1")
    if [ -z "$python_version" ]; then return 1; fi
    
    local venv_name="${python_version}-${project_name}"
    _create_py_venv "$python_version" "$venv_name" || return 1

    _ensure_pipx_installed || return 1
    _ensure_poetry_installed || return 1

    _initialize_poetry_project "$project_name" "$python_version" || return 1

    _scaffold_poetry_project_structure "$project_name"

    _create_precommit_config_file
    create_poetry_makefile

    _install_poetry_dependencies_and_hooks || return 1

    echo "Poetry project '$project_name' created successfully"
    return 0
}

# ---- Aliases ----

# Python version management
alias pyv="pyenv_versions"
alias pyi="pyenv_install"
alias pycleanv="pycleanversions"

# Virtual environment management
alias pycreate="create_venv"
alias pyact="activate_venv"
alias pydeact="deactivate_venv"
alias pydel="delete_venv"
alias pylsvenv="list_venvs"

# Dependency management
alias pyupdate="update_packages"
alias pyclean="clean_packages"

# Development tools
alias pyprecommit="setup_precommit"
alias pycheck="run_precommit"

# Quick project setup
alias pynew="create_venv && pyact && setup_precommit && create_makefile"
alias pypoetry="create_poetry_project"
