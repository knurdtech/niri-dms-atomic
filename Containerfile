# --- Final bootc image ---
FROM quay.io/fedora/fedora-bootc:latest

# --- Core desktop stack ---
# Niri compositor, seatd for input, audio/portal plumbing, XWayland for X apps
RUN microdnf -y install \
      seatd greetd \
      pipewire pipewire-alsa pipewire-pulse wireplumber cava \
      xorg-x11-server-Xwayland \
      xdg-desktop-portal xdg-desktop-portal-wlr \
      mate-polkit \
      wl-clipboard brightnessctl \
      NetworkManager \
      libva-intel-media-driver libva-utils mesa-dri-drivers mesa-vulkan-drivers \
      rsms-inter-vf-fonts fira-code-fonts google-noto-emoji-fonts jetbrains-mono-fonts \
      curl git fontconfig \
    && microdnf clean all

# (Optional) If you want the very latest Niri, enable COPR instead of the stable Fedora pkg:
 RUN curl -fsSL -o /etc/yum.repos.d/yalter-niri.repo \
   https://copr.fedorainfracloud.org/coprs/yalter/niri/repo/fedora-$releasever/yalter-niri-fedora-$releasever.repo \
   && microdnf -y install niri && microdnf clean all

# Quickshell COPR (no bash; pure sh heredoc)
RUN cat >/etc/yum.repos.d/errornointernet-quickshell.repo <<'EOF'
[copr:copr.fedorainfracloud.org:errornointernet:quickshell]
name=COPR repo for quickshell owned by errornointernet
baseurl=https://download.copr.fedorainfracloud.org/results/errornointernet/quickshell/fedora-$releasever-$basearch/
type=rpm-md
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/errornointernet/quickshell/pubkey.gpg
repo_gpgcheck=0
enabled=1
EOF
RUN microdnf -y install quickshell && microdnf clean all

# Optional: matugen COPR
RUN cat >/etc/yum.repos.d/heus-sueh-packages.repo <<'EOF'
[copr:copr.fedorainfracloud.org:heus-sueh:packages]
name=COPR heus-sueh packages
baseurl=https://download.copr.fedorainfracloud.org/results/heus-sueh/packages/fedora-$releasever-$basearch/
type=rpm-md
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/heus-sueh/packages/pubkey.gpg
repo_gpgcheck=0
enabled=1
EOF
RUN microdnf -y install matugen || true && microdnf clean all

# --- Material Symbols (variable fonts): install from Google repo ---
RUN install -d /usr/local/share/fonts/material-symbols && \
    curl -fsSL -o /usr/local/share/fonts/material-symbols/MaterialSymbolsOutlined.ttf \
      "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" && \
    curl -fsSL -o /usr/local/share/fonts/material-symbols/MaterialSymbolsRounded.ttf \
      "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" && \
    curl -fsSL -o /usr/local/share/fonts/material-symbols/MaterialSymbolsSharp.ttf \
      "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsSharp%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" && \
    fc-cache -f

# DankMaterialShell (config + helper)
RUN mkdir -p /etc/skel/.config/quickshell && \
    git clone --depth=1 https://github.com/AvengeMedia/DankMaterialShell.git /etc/skel/.config/quickshell/dms

# Install the dms helper (POSIX sh, no bash)
RUN set -e; arch="$(uname -m)"; \
    case "$arch" in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; esac; \
    curl -fsSL "https://github.com/AvengeMedia/danklinux/releases/latest/download/dms-${arch}.gz" \
    | gunzip | install -m0755 /dev/stdin /usr/local/bin/dms

# --- Make a user and greetd config ---
RUN useradd -m -U live && mkdir -p /etc/greetd
# Tuigreet is a nice TUI greeter (optional). You can also autologin directly.
# Note: Replacing command = "/usr/bin/tuigreet --remember --cmd \\'dbus-run-session -- niri\\'"\n\
RUN microdnf -y install tuigreet && microdnf clean all
RUN cat >/etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1
[default_session]
command = "/usr/bin/tuigreet --remember --cmd 'env LIBVA_DRIVER_NAME=iHD dbus-run-session -- niri'"
user = "live"
EOF

# Niri: autostart DMS + helpers
RUN install -d /etc/xdg/niri
RUN cat >/etc/xdg/niri/config.kdl <<'EOF'
environment { XDG_CURRENT_DESKTOP "niri" }
spawn-at-startup "wl-paste" "--watch" "cliphist" "store"
spawn-at-startup "/usr/libexec/polkit-mate-authentication-agent-1"
spawn-at-startup "dms" "run"
EOF

# --- Enable services + boot target ---
RUN systemctl set-default graphical.target && \
    systemctl enable greetd.service && \
    systemctl enable NetworkManager.service && \
    systemctl enable seatd.service

# Labels help bootc-aware tools
LABEL bootc=1

