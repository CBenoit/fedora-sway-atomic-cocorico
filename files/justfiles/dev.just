# Run `ujust` to list available commands.
default:
    @just --list

# Create a Fedora Toolbox that matches the host release.
# (idempotent: safe to re-run)
toolbox-create:
    toolbox create --container dev \
      --image registry.fedoraproject.org/fedora-toolbox:$(rpm -E %fedora) 2>/dev/null || true

# Enter the dev toolbox.
dev:
    toolbox enter dev

# Provision the dev toolbox with compilers, SDKs, and headers.
dev-setup: toolbox-create
    toolbox run --container dev -- sh -lc '
      set -euxo pipefail

      sudo dnf -y upgrade

      # Core build tools.
      sudo dnf -y groupinstall "Development Tools"

      # Compilers & build systems.
      sudo dnf -y install \
        gcc gcc-c++ clang clang-tools-extra cmake ninja-build gdb pkgconfig \
        protobuf-compiler openssl-devel zlib-devel bzip2-devel xz-devel \
        jq yq git ripgrep fd-find

      # Wayland/GTK bits used by Avalonia GTK hosting and common native deps.
      sudo dnf -y install \
        gtk3 gtk3-devel glib2-devel wayland-devel libxkbcommon-devel \
        libX11-devel libXi-devel libXrandr-devel libxcb-devel xcb-util-devel \
        xcb-util-wm-devel xcb-util-keysyms-devel dbus-devel

      # Rust (use rustup for project-pinned toolchains).
      sudo dnf -y install rustup
      rustup default stable
      rustup component add rust-analyzer

      # .NET SDK (Fedora packages track current LTS/current; adjust as needed).
      sudo dnf -y install dotnet-sdk-9.0

      # Node + package managers (adjust if you prefer fnm/volta).
      sudo dnf -y install nodejs npm
      npm -g install pnpm yarn || true

      # Quick smoke.
      cargo --version
      dotnet --info
      node --version
    '

# Make Nushell your login shell (host). Adds /usr/bin/nu to /etc/shells if needed.
nu-default:
    if ! grep -qx "/usr/bin/nu" /etc/shells; then \
      echo "/usr/bin/nu" | sudo tee -a /etc/shells >/dev/null; \
    fi
    sudo chsh -s /usr/bin/nu "${USER}"
    @echo "Switched ${USER} to Nushell. Log out/in to take effect."

# Bootstrap Nushell config: Starship prompt + Zoxide integration.
nu-bootstrap:
    mkdir -p ~/.config/nushell ~/.cache/starship
    # Generate init scripts (plain shell redirection; no Nu required here)
    starship init nu > ~/.cache/starship/init.nu
    zoxide init nushell > ~/.config/nushell/zoxide.nu

    # Ensure env.nu and config.nu exist and source the init scripts
    touch ~/.config/nushell/env.nu ~/.config/nushell/config.nu

    if ! grep -q "STARSHIP_SHELL" ~/.config/nushell/env.nu; then \
      printf '\n$env.STARSHIP_SHELL = "nu"\n' >> ~/.config/nushell/env.nu; \
    fi

    if ! grep -q "starship/init.nu" ~/.config/nushell/config.nu; then \
      printf '\nsource ~/.cache/starship/init.nu\n' >> ~/.config/nushell/config.nu; \
    fi

    if ! grep -q "zoxide.nu" ~/.config/nushell/config.nu; then \
      printf 'source ~/.config/nushell/zoxide.nu\n' >> ~/.config/nushell/config.nu; \
    fi

    @echo "Nu + Starship + Zoxide configured. Open a new terminal to see it."

# Optional: allow non-root packet capture on host (re-login for group to apply).
wireshark-perms:
    sudo usermod -aG wireshark ${USER} || true
    @echo "Re-login or run: newgrp wireshark"
