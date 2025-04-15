#!/bin/bash
# Python aliases

# ---- Helper functions ----

get_current_dir_name() {
    basename "$PWD"
}

get_venv_name() {
    local current_dir
    local python_version
    current_dir=$(get_current_dir_name)
    python_version=$(pyenv version-name | cut -d'-' -f1)
    echo "${python_version}-${current_dir}"
}

validate_python_version() {
    local version=$1
    if ! pyenv versions --bare | grep -q "^${version}$"; then
        echo "Error: Python version ${version} is not installed"
        return 1
    fi
    return 0
}

validate_venv_name() {
    local venv_name=$1
    # Allow both formats: X.Y.Z-name and name
    if [[ ! "$venv_name" =~ ^([0-9]+\.[0-9]+\.[0-9]+-[a-zA-Z0-9_-]+|[a-zA-Z0-9_-]+)$ ]]; then
        echo "Error: Invalid virtual environment name. Use format: X.Y.Z-project-name or project-name"
        return 1
    fi
    return 0
}

# ---- Python version management ----

pyenv_versions() {
    echo "Installed Python versions:"
    pyenv versions
    echo -e "\nLatest available Python versions:"
    pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | tail -5
}

pyenv_install() {
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

create_venv() {
    local venv_name
    local python_version
    local user_input

    if [ -z "$1" ]; then
        echo "Which Python version do you want to use? (Leave blank for latest)"
        read -r user_input
        
        if [ -z "$user_input" ]; then
            python_version=$(pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | tail -1 | tr -d '[:space:]')
            echo "Using latest Python version: $python_version"
        else
            python_version=$user_input
        fi
    else
        python_version=$1
    fi

    if ! validate_python_version "$python_version"; then
        if ! pyenv_install "$python_version"; then
            return 1
        fi
    fi

    venv_name="${python_version}-$(get_current_dir_name)"
    
    if ! validate_venv_name "$venv_name"; then
        return 1
    fi
    
    echo "Creating virtualenv: $venv_name"
    if ! pyenv virtualenv -f "$python_version" "$venv_name"; then
        echo "Error: Failed to create virtual environment"
        return 1
    fi

    # Set local version for automatic activation
    pyenv local "$venv_name"
    echo "Virtualenv '$venv_name' created and set as local version"
    echo "Note: Environment will be automatically activated when entering this directory"
    return 0
}

activate_venv() {
    local venv_name=${1:-$(get_venv_name)}
    
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
    if [ -z "$PYENV_VIRTUAL_ENV" ]; then
        echo "No virtual environment is currently active"
        return 1
    fi
    
    pyenv deactivate
    echo "Virtual environment deactivated"
    return 0
}

delete_venv() {
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
    echo "Available virtualenvs:"
    pyenv virtualenvs
    return 0
}

# ---- Dependency management ----

update_packages() {
    if [ -z "$PYENV_VIRTUAL_ENV" ]; then
        echo "Error: No virtual environment is active"
        return 1
    fi

    echo "Updating all packages..."
    if ! pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip install -U; then
        echo "Error: Failed to update packages"
        return 1
    fi
    
    echo "All packages updated successfully"
    return 0
}

clean_packages() {
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
    if [ -z "$PYENV_VIRTUAL_ENV" ]; then
        echo "Error: No virtual environment is active"
        return 1
    fi

    if ! command -v pre-commit >/dev/null 2>&1; then
        echo "Installing pre-commit..."
        if ! pip install pre-commit; then
            echo "Error: Failed to install pre-commit"
            return 1
        fi
    fi
    
    if [ ! -f ".pre-commit-config.yaml" ]; then
        echo "Creating basic pre-commit configuration..."
        cat > .pre-commit-config.yaml << EOF
repos:
-   repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
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
    rev: 5.12.0
    hooks:
    -   id: isort
        stages: [pre-commit]

-   repo: https://github.com/psf/black
    rev: 24.1.1
    hooks:
    -   id: black
        language_version: python3
        stages: [pre-commit]

-   repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.2.1
    hooks:
    -   id: ruff
        args: [--fix, --exit-non-zero-on-fix]
        stages: [pre-commit]
EOF
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
    cat > Makefile << EOF
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
.PHONY: clean install-dev install check

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

##@ Installation
install-dev:  ## Install development dependencies
	pip install -e ".[dev]"

install:  ## Install all dependencies
	pip install -e .

##@ Checks
check: ## Run all checks
    poetry run pre-commit run --all-files
EOF

    echo "Makefile created successfully"
    return 0
}

run_precommit() {
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
    cat > Makefile << EOF
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
.PHONY: clean test install-dev install check

##@ Testing
test:  ## Run tests
	poetry run pytest

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

    echo "Makefile created successfully"
    return 0
}

create_poetry_project() {
    local project_name
    local python_version
    local user_input
    local venv_name

    # Initialize git repository if not already initialized
    if [ ! -d ".git" ]; then
        echo "Initializing git repository..."
        git init
        git add .
        git commit -m "Initial commit"
    fi

    # Get project name from current directory
    project_name=$(get_current_dir_name)

    # Ask for Python version
    if [ -z "$1" ]; then
        echo "Which Python version do you want to use? (Leave blank for latest)"
        read -r user_input
        
        if [ -z "$user_input" ]; then
            python_version=$(pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | tail -1 | tr -d '[:space:]')
            echo "Using latest Python version: $python_version"
        else
            python_version=$user_input
        fi
    else
        python_version=$1
    fi

    # Ensure Python version is installed
    if ! validate_python_version "$python_version"; then
        if ! pyenv_install "$python_version"; then
            return 1
        fi
    fi

    # Create virtual environment with pyenv
    venv_name="${python_version}-${project_name}"
    echo "Creating virtual environment: $venv_name"
    if ! pyenv virtualenv -f "$python_version" "$venv_name"; then
        echo "Error: Failed to create virtual environment"
        return 1
    fi

    # Set local version for the project
    pyenv local "$venv_name"
    echo "Virtual environment '$venv_name' created and set as local version"

    # Check if pipx is installed
    if ! command -v pipx >/dev/null 2>&1; then
        echo "Installing pipx..."
        if ! brew install pipx; then
            echo "Error: Failed to install pipx"
            return 1
        fi
        pipx ensurepath
        source ~/.zshrc
        pipx ensurepath
    fi

    # Check if poetry is installed via pipx
    if ! command -v poetry >/dev/null 2>&1; then
        echo "Installing poetry via pipx..."
        if ! pipx install poetry; then
            echo "Error: Failed to install poetry"
            return 1
        fi
    fi

    # Configure poetry to use the pyenv virtual environment
    poetry config virtualenvs.create false
    poetry config virtualenvs.in-project false

    # Initialize poetry project
    echo "Initializing poetry project: $project_name"
    if ! poetry init --name "$project_name" --description "A Python project" --author "$(git config user.name) <$(git config user.email)>" --python "^$python_version" --dependency "black" --dependency "isort" --dependency "ruff" --dependency "pytest" --dev-dependency "pre-commit" --no-interaction; then
        echo "Error: Failed to initialize poetry project"
        return 1
    fi

    # Create basic project structure
    mkdir -p "$project_name" tests
    touch "$project_name/__init__.py" tests/__init__.py

    # Create README.md
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

    # Create pre-commit configuration
    cat > .pre-commit-config.yaml << EOF
repos:
-   repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
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
    rev: 5.12.0
    hooks:
    -   id: isort
        stages: [pre-commit]

-   repo: https://github.com/psf/black
    rev: 24.1.1
    hooks:
    -   id: black
        language_version: python3
        stages: [pre-commit]

-   repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.2.1
    hooks:
    -   id: ruff
        args: [--fix, --exit-non-zero-on-fix]
        stages: [pre-commit]
EOF

    # Create Makefile
    create_poetry_makefile

    # Install dependencies
    echo "Installing dependencies..."
    if ! poetry install; then
        echo "Error: Failed to install dependencies"
        return 1
    fi

    # Setup pre-commit
    echo "Installing pre-commit hooks..."
    if ! poetry run pre-commit install; then
        echo "Error: Failed to install pre-commit hooks"
        return 1
    fi

    echo "Poetry project '$project_name' created successfully"
    return 0
}

# ---- Aliases ----

# Python version management
alias pyv="pyenv_versions"
alias pyi="pyenv_install"

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
