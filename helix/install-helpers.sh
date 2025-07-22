#!/usr/bin/env bash

# Helix Development Tools Installation Script
# Run this to install language servers, formatters, and debug adapters for your Helix config
# Supports macOS (Homebrew) and Linux (apt/dnf/pacman)

set -e

echo "🚀 Installing Language Servers, Formatters, and Debug Adapters for Helix..."
echo

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ -f "/etc/os-release" ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian) OS="debian" ;;
            fedora|centos|rhel) OS="fedora" ;;
            arch|manjaro|cachyos|endeavouros|artix) OS="arch" ;;
            *) OS="linux" ;;
        esac
    else
        OS="unknown"
    fi
}

detect_os

# Check for required tools
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 is not installed. Please install it first."
        return 1
    fi
}

# Function to install with error handling
install_safe() {
    echo "📦 Installing $1..."
    if eval "$2"; then
        echo "✅ $1 installed successfully"
    else
        echo "❌ Failed to install $1"
    fi
    echo
}

# System packages
echo "📦 Installing system packages..."
case "$OS" in
    "macos")
        if ! check_command "brew"; then
            echo "❌ Homebrew not found. Please install it first: https://brew.sh"
            exit 1
        fi
        brew_packages=(
            "llvm"  # includes clangd
            "gopls" 
            "rust-analyzer"
            "taplo"
            "marksman"
            "shfmt"
            "node"  # needed for npm packages
            "black"
            "libxml2"  # includes xmllint
            # Formatters
            "prettier"
            "stylua"
            "jq"
            "isort"
            "autopep8"
            "clang-format"
        )
        for package in "${brew_packages[@]}"; do
            if brew list "$package" &>/dev/null; then
                echo "✅ $package already installed"
            else
                install_safe "$package" "brew install $package"
            fi
        done
        # Ensure node is linked properly
        if brew list node &>/dev/null && ! command -v node &>/dev/null; then
            echo "🔧 Linking node..."
            brew link --overwrite node
        fi
        ;;
    "debian")
        echo "Installing packages via apt..."
        sudo apt-get update
        apt_packages=(
            "clang" "clangd"  # C/C++ LSP
            "nodejs" "npm"    # Node.js and npm
            "python3-pip" "pipx"
            "golang-go"       # Go
            "rustc" "rust-src" "rust-analyzer"
            "libxml2-utils"   # xmllint
            # Formatters
            "jq"
            "clang-format"
            "python3-autopep8"
            "python3-isort"
        )
        for package in "${apt_packages[@]}"; do
            install_safe "$package" "sudo apt-get install -y $package"
        done
        ;;
    "fedora")
        echo "Installing packages via dnf..."
        dnf_packages=(
            "clang" "clang-tools-extra"  # clangd
            "nodejs" "npm"
            "python3-pip" "pipx"
            "golang"
            "rust" "rust-analyzer"
            "libxml2"
            # Formatters
            "jq"
            "python3-autopep8"
            "python3-isort"
        )
        for package in "${dnf_packages[@]}"; do
            install_safe "$package" "sudo dnf install -y $package"
        done
        ;;
    "arch")
        echo "Installing packages via pacman..."
        pacman_packages=(
            "clang" "clang-tools-extra"  # clangd
            "nodejs" "npm"
            "python-pip" "python-pipx"
            "go"
            "rust" "rust-analyzer"
            "libxml2"
            # Formatters
            "jq"
            "python-autopep8"
            "python-isort"
            "shfmt"  # shell formatter
        )
        for package in "${pacman_packages[@]}"; do
            install_safe "$package" "sudo pacman -S --noconfirm --needed $package"
        done
        ;;
    *)
        echo "⚠️ Unknown OS: $OS. Skipping system package installation."
        echo "Please manually install: clangd, nodejs, npm, python3, go, rust, rust-analyzer"
        ;;
esac

# Configure npm for user installs (fix permission issues)
if check_command "npm" && [[ ! -f "$HOME/.npmrc" || ! $(grep -q "prefix=" "$HOME/.npmrc" 2>/dev/null) ]]; then
    echo "🔧 Configuring npm for user installs..."
    mkdir -p "$HOME/.local/lib"
    npm config set prefix "$HOME/.local"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.zshrc
    export PATH="$HOME/.local/bin:$PATH"
    echo "✅ npm configured for user installs"
    echo
fi

# Node.js packages
if check_command "npm"; then
    echo "📦 Installing npm packages..."
    npm_packages=(
        # Language Servers
        "bash-language-server"
        "dockerfile-language-server-nodejs"
        "vscode-langservers-extracted"
        "typescript-language-server"
        "yaml-language-server"
        "@ansible/ansible-language-server"
        "graphql-language-service-cli"
        "@tailwindcss/language-server"
        # Formatters
        "prettier"
        "@fsouza/prettierd"  # faster prettier daemon
        "eslint"
        "@typescript-eslint/eslint-plugin"
        # Debug Adapters
        # Note: vscode-js-debug is not available on npm, use VS Code extension instead
        "node-debug2"
    )
    
    for package in "${npm_packages[@]}"; do
        install_safe "$package" "npm install -g $package"
    done
fi

# Python packages - use pipx for isolated installs
if check_command "pipx" || { [[ "$OS" == "macos" ]] && { brew list pipx &>/dev/null || install_safe "pipx" "brew install pipx"; }; }; then
    echo "🐍 Installing Python packages..."
    if check_command "pipx"; then
        # Language Servers
        install_safe "Python LSP Server" "pipx install 'python-lsp-server[all]'"
        install_safe "Ruff LSP" "pipx install ruff-lsp"
        # Formatters
        install_safe "Black formatter" "pipx install black"
        install_safe "Isort" "pipx install isort"
        install_safe "Autopep8" "pipx install autopep8"
        install_safe "YAPF" "pipx install yapf"
        # Debug Adapters
        install_safe "debugpy" "pipx install debugpy"
    fi
else
    echo "❌ pipx is not installed. Please install it first."
fi

# Go packages
if check_command "go"; then
    echo "🐹 Installing Go packages..."
    # Language Servers
    install_safe "gopls" "go install golang.org/x/tools/gopls@latest"
    # Formatters
    install_safe "goimports" "go install golang.org/x/tools/cmd/goimports@latest"
    install_safe "gci" "go install github.com/daixiang0/gci@latest"
    # Debug Adapters
    install_safe "delve (dlv)" "go install github.com/go-delve/delve/cmd/dlv@latest"
else
    echo "❌ go is not installed. Please install it first."
fi

# Rust packages
if check_command "cargo"; then
    echo "🦀 Installing Rust packages..."
    # Language Servers
    install_safe "asm-lsp" "cargo install asm-lsp"
    # nil LSP server for Nix - only install if nix is available
    if check_command "nix"; then
        install_safe "nil (Nix LSP)" "cargo install --git https://github.com/oxalica/nil nil"
    else
        echo "❌ nix is not installed. Please install it first."
        echo "🦀 Skipping nil (Nix LSP) - requires nix to build"
    fi
    # Formatters
    if ! command -v rustfmt &>/dev/null; then
        install_safe "rustfmt" "rustup component add rustfmt"
    fi
    install_safe "stylua (Lua formatter)" "cargo install stylua"
    install_safe "taplo (TOML formatter)" "cargo install taplo-cli --locked"
    # Debug Adapters
    install_safe "codelldb" "cargo install --git https://github.com/vadimcn/codelldb.git codelldb"
fi

# Ruby packages (skip - system Ruby 2.6 too old for modern gems)
if check_command "gem"; then
    RUBY_VERSION=$(ruby -v | grep -o '[0-9]\+\.[0-9]\+')
    if [[ "$RUBY_VERSION" > "2.7" || "$RUBY_VERSION" == "2.7" ]]; then
        echo "💎 Installing Ruby packages..."
        # Language Servers
        install_safe "Ruby LSP" "gem install --user-install ruby-lsp"
        install_safe "Solargraph" "gem install --user-install solargraph"
        # Formatters
        install_safe "Rubocop" "gem install --user-install rubocop"
        # Debug Adapters
        install_safe "ruby-debug-ide" "gem install --user-install ruby-debug-ide"
        install_safe "debase" "gem install --user-install debase"
    else
        echo "💎 Skipping Ruby packages (Ruby $RUBY_VERSION too old, need 2.7+)"
    fi
fi

# Additional formatters and tools (cross-platform via other package managers)
echo "🎨 Installing additional formatters..."

# Install additional Rust formatters if cargo is available
if check_command "cargo"; then
    install_safe "dprint" "cargo install dprint"
    install_safe "leptosfmt" "cargo install leptosfmt"
fi

# Install Java formatters if they're available
if check_command "npm"; then
    install_safe "google-java-format" "npm install -g google-java-format"
fi

# Fix prettier conflict if it exists (macOS specific)
if [[ "$OS" == "macos" ]] && brew list prettier &>/dev/null && [[ -L "/opt/homebrew/bin/prettier" ]]; then
    echo "🔧 Fixing prettier symlink conflict..."
    brew unlink prettier && brew link --overwrite prettier
fi

# Add clangd to PATH if installed via llvm (macOS specific)
if [[ "$OS" == "macos" ]] && brew list llvm &>/dev/null && ! command -v clangd &>/dev/null; then
    echo "🔧 Adding clangd to PATH..."
    echo 'export PATH="$(brew --prefix llvm)/bin:$PATH"' >> ~/.zshrc
    echo "Run: source ~/.zshrc or restart terminal to use clangd"
fi

echo "🎉 Language servers, formatters, and debug adapters installation complete!"
echo
echo "💡 Run 'hx --health' to check which language servers are working"
echo "🔗 Link configs: ln -sf ~/dotfiles/helix/* ~/.config/helix/"
echo
echo "Note: You may need to restart your terminal or run 'source ~/.zshrc' to update your PATH."
