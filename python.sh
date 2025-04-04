#!/bin/bash
# Python aliases

# ---- Helper functions ----

get_current_dir_name() {
    basename "$PWD"
}

get_venv_name() {
    local current_dir
    current_dir=$(get_current_dir_name)
    echo "${current_dir}-venv"
}

check_python_version() {
    local python_version
    python_version=$(pyenv version-name)

    if [ -z "$python_version" ]; then
        echo "Error: No Python version is set for pyenv. Use 'pyenv local <version>' to set one."
        return 1
    fi

    echo "$python_version"
}

# ---- Python version management ----

# Display available Python versions
pyenv_versions() {
    echo "Installed Python versions:"
    pyenv versions
    echo -e "\nLatest available Python versions:"
    pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | tail -5
}

# Install Python version (latest by default)
pyenv_install() {
    local python_version

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

    echo "Installing Python $python_version..."
    pyenv install -s "$python_version"  # -s flag skips if already installed
    echo "Python $python_version installed successfully"
    
    echo "$python_version"  # Return the Python version
}

# ---- Virtual environment management ----

# Create a new virtual environment
create_venv() {
    local venv_name=${1:-$(get_venv_name)}
    local python_version
    
    if [ -z "$2" ]; then
        # Ask for Python version directly in this function
        echo "Which Python version do you want to use? (Leave blank for latest)"
        read -r user_input
        
        if [ -z "$user_input" ]; then
            python_version=$(pyenv install --list | grep -E "^\s*[0-9]+\.[0-9]+\.[0-9]+$" | tail -1 | tr -d '[:space:]')
            echo "Using latest Python version: $python_version"
        else
            python_version=$user_input
        fi
        
        # Ensure the Python version is installed
        echo "Installing Python $python_version if not already installed..."
        pyenv install -s "$python_version"
    else
        python_version=$2
        # Ensure the Python version is installed
        echo "Installing Python $python_version if not already installed..."
        pyenv install -s "$python_version"
    fi
    
    echo "Creating virtualenv: $venv_name (Python $python_version)"
    pyenv virtualenv -f "$python_version" "$venv_name" || return 1  # -f flag forces creation

    # Automatically set local version for the project
    pyenv local "$venv_name"
    echo "Virtualenv '$venv_name' created and set as local version."
    echo "Created .python-version file."
}


# Activate an existing virtual environment
activate_venv() {
    local venv_name=${1:-$(get_venv_name)}
    
    if pyenv virtualenvs --bare | grep -q "^${venv_name}$"; then
        echo "Activating virtualenv: $venv_name"
        pyenv activate "$venv_name"
    else
        echo "Error: Virtualenv '$venv_name' does not exist."
        echo "Available virtualenvs:"
        pyenv virtualenvs
        return 1
    fi
}

# Deactivate the active virtual environment
deactivate_venv() {
    pyenv deactivate
}

# Delete a virtual environment
delete_venv() {
    local venv_name=${1:-$(get_venv_name)}
    
    if pyenv virtualenvs --bare | grep -q "^${venv_name}$"; then
        echo "This will delete virtualenv '$venv_name'. Are you sure? (y/n)"
        read -r answer
        if [[ "$answer" == "y" ]]; then
            pyenv uninstall -f "$venv_name"
            echo "Virtualenv '$venv_name' deleted."
        else
            echo "Operation cancelled."
        fi
    else
        echo "Error: Virtualenv '$venv_name' does not exist."
        return 1
    fi
}

# List all virtual environments
list_venvs() {
    echo "Available virtualenvs:"
    pyenv virtualenvs
}

# ---- Dependency management ----

# Update all packages
update_packages() {
    echo "Updating all packages..."
    pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip install -U
    echo "All packages updated."
}

# Safely remove all packages
clean_packages() {
    echo "This will uninstall all packages. Continue? (y/n)"
    read -r answer
    if [[ "$answer" == "y" ]]; then
        pip freeze | grep -v '^-e' | xargs pip uninstall -y
        echo "All packages uninstalled."
    else
        echo "Operation cancelled."
    fi
}

# ---- Development tools ----

# Install pre-commit with basic configuration
setup_precommit() {
    if ! command -v pre-commit >/dev/null 2>&1; then
        echo "Install pre-commit..."
    fi
    
    if [ ! -f ".pre-commit-config.yaml" ]; then
        echo "Creating basic pre-commit configuration..."
        cat > .pre-commit-config.yaml << EOF
repos:
-   repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
    -   id: trailing-whitespace
    -   id: end-of-file-fixer
    -   id: check-yaml
    -   id: check-added-large-files

-   repo: https://github.com/pycqa/isort
    rev: 5.12.0
    hooks:
    -   id: isort

-   repo: https://github.com/psf/black
    rev: 23.3.0
    hooks:
    -   id: black
        language_version: python3

-   repo: https://github.com/charliermarsh/ruff-pre-commit
    rev: v0.0.262
    hooks:
    -   id: ruff
        args: [--fix, --exit-non-zero-on-fix]
EOF
        echo "Pre-commit configuration created."
    else
        echo ".pre-commit-config.yaml already exists."
    fi
    
    echo "Installing pre-commit hooks..."
    pre-commit install
    echo "Pre-commit hooks installed."
}

# Run pre-commit on all files
run_precommit() {
    if command -v pre-commit >/dev/null 2>&1; then
        echo "Running pre-commit on all files..."
        pre-commit run --all-files
    else
        echo "Error: pre-commit not installed. Run 'setup_precommit' first."
        return 1
    fi
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
alias pynew="create_venv && setup_precommit"
