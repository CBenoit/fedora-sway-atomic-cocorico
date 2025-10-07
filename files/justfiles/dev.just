# Enter the dev toolbox.
dev:
    toolbox enter dev

# Provision the dev toolbox with compilers, SDKs, and headers.
dev-setup: toolbox-create
    #!/usr/bin/env bash
    set -euo pipefail

    toolbox run --container dev -- bash -lc '
        set -euxo pipefail

        sudo dnf -y upgrade

        # Core build tools.
        sudo dnf -y groupinstall development-tools
        sudo dnf -y groupinstall c-development

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
        # 1) Make container-local dirs and give ownership to current user.
        sudo mkdir -p /var/opt/{cargo,rustup}
        sudo chown -R "$USER":"$USER" /var/opt/{cargo,rustup}
        # 2) Define env vars (and PATH) for all future shells in this container.
        printf "%s\n" "export RUSTUP_HOME=/var/opt/rustup" "export CARGO_HOME=/var/opt/cargo" "export PATH=\"\$CARGO_HOME/bin:$PATH\"" | sudo tee /etc/profile.d/rustup.sh >/dev/null
        # 3) Re-load.
        source /etc/profile.d/rustup.sh
        # 4) Install rustup and initialize toolchain into /var/opt/*
        sudo dnf -y install rustup
        rustup-init -y --default-toolchain stable --component rust-analyzer --no-modify-path
        # 5) Quick sanity check.
        echo "$RUSTUP_HOME"   # /var/opt/rustup
        echo "$CARGO_HOME"    # /var/opt/cargo
        which cargo           # /var/opt/cargo/bin/cargo
        cargo --version

        # .NET SDK (prefer 9; fall back to 8 if not available).
        sudo dnf -y install dotnet-sdk-9.0 || sudo dnf -y install dotnet-sdk-8.0
        dotnet --info

        # Node + package managers.
        # 1) Install Node and npm via dnf.
        sudo dnf -y install nodejs npm
        # 2) Make container-local dirs and own them.
        sudo mkdir -p /var/opt/npm/{prefix,cache}
        sudo chown -R "$USER":"$USER" /var/opt/npm
        # 3) Set npm to use those dirs *and* expose their bin on PATH for every shell.
        printf "%s\n" "export npm_config_prefix=/var/opt/npm/prefix" "export npm_config_cache=/var/opt/npm/cache" "export PATH=\"/var/opt/npm/prefix/bin:\$PATH\"" | sudo tee /etc/profile.d/npm.sh >/dev/null
        # 4) Reload the profile.
        source /etc/profile.d/npm.sh
        # 5) Sanity checks.
        echo "$npm_config_prefix"    # /var/opt/npm/prefix
        echo "$npm_config_cache"     # /var/opt/npm/cache
        npm config get prefix        # /var/opt/npm/prefix
        which npm                    # /usr/bin/npm
        node --version
        # 6) Install alternate package managers.
        npm -g install pnpm yarn || true

        # TODO: add nushell and set as default shell.
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
