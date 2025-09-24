# Base bootable container OS (Fedora)
FROM quay.io/fedora/fedora-bootc:latest

# --- Core desktop stack ---
# Niri compositor, seatd for input, audio/portal plumbing, XWayland for X apps
RUN microdnf -y install \
      seatd greetd \
      pipewire pipewire-alsa pipewire-pulse wireplumber cava \
      xorg-x11-server-Xwayland \
      xdg-desktop-portal xdg-desktop-portal-wlr \
      polkit-mate \
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

# --- Quickshell from COPR (Fedora docs and upstream point here) ---
# Adds a .repo that keeps $releasever/$basearch dynamic on the target system
RUN bash -lc 'cat > /etc/yum.repos.d/errornointernet-quickshell.repo << "EOF"\n\
[copr:copr.fedorainfracloud.org:errornointernet:quickshell]\n\
name=COPR repo for quickshell owned by errornointernet\n\
baseurl=https://download.copr.fedorainfracloud.org/results/errornointernet/quickshell/fedora-$releasever-$basearch/\n\
type=rpm-md\n\
gpgcheck=1\n\
gpgkey=https://download.copr.fedorainfracloud.org/results/errornointernet/quickshell/pubkey.gpg\n\
repo_gpgcheck=0\n\
enabled=1\n\
EOF'
RUN microdnf -y install quickshell && microdnf clean all

# --- Extra deps DMS recommends (clipboard history + theming) ---
# cliphist & matugen (both via COPR)
RUN bash -lc 'cat > /etc/yum.repos.d/wef-cliphist.repo << "EOF"\n\
[copr:copr.fedorainfracloud.org:wef:cliphist]\n\
name=Copr cliphist\n\
baseurl=https://download.copr.fedorainfracloud.org/results/wef/cliphist/fedora-$releasever-$basearch/\n\
type=rpm-md\n\
gpgcheck=1\n\
gpgkey=https://download.copr.fedorainfracloud.org/results/wef/cliphist/pubkey.gpg\n\
repo_gpgcheck=0\n\
enabled=1\n\
EOF'
RUN bash -lc 'cat > /etc/yum.repos.d/heus-sueh-packages.repo << "EOF"\n\
[copr:copr.fedorainfracloud.org:heus-sueh:packages]\n\
name=COPR heus-sueh packages\n\
baseurl=https://download.copr.fedorainfracloud.org/results/heus-sueh/packages/fedora-$releasever-$basearch/\n\
type=rpm-md\n\
gpgcheck=1\n\
gpgkey=https://download.copr.fedorainfracloud.org/results/heus-sueh/packages/pubkey.gpg\n\
repo_gpgcheck=0\n\
enabled=1\n\
EOF'
RUN microdnf -y install cliphist matugen && microdnf clean all

# --- Material Symbols (variable fonts): install from Google repo ---
RUN install -d /usr/local/share/fonts/material-symbols && \
    curl -fsSL -o /usr/local/share/fonts/material-symbols/MaterialSymbolsOutlined.ttf \
      "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" && \
    curl -fsSL -o /usr/local/share/fonts/material-symbols/MaterialSymbolsRounded.ttf \
      "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" && \
    curl -fsSL -o /usr/local/share/fonts/material-symbols/MaterialSymbolsSharp.ttf \
      "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsSharp%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" && \
    fc-cache -f

# --- Install DMS (DankMaterialShell) ---
# 1) place config under /etc/skel so every new user gets it
RUN mkdir -p /etc/skel/.config/quickshell && \
    git clone --depth=1 https://github.com/AvengeMedia/DankMaterialShell.git /etc/skel/.config/quickshell/dms

# 2) install the dms CLI from release (binary helper the project provides)
RUN bash -lc 'arch=$(uname -m); \
  [ "$arch" = "x86_64" ] && arch=amd64 || [ "$arch" = "aarch64" ] && arch=arm64 || true; \
  curl -fsSL "https://github.com/AvengeMedia/danklinux/releases/latest/download/dms-${arch}.gz" \
  | gunzip | install -m 0755 /dev/stdin /usr/local/bin/dms'

# --- Make a user and greetd config ---
RUN useradd -m -U live && mkdir -p /etc/greetd
# Tuigreet is a nice TUI greeter (optional). You can also autologin directly.
# Note: Replacing command = "/usr/bin/tuigreet --remember --cmd \\'dbus-run-session -- niri\\'"\n\
RUN microdnf -y install tuigreet && microdnf clean all
RUN bash -lc 'cat > /etc/greetd/config.toml << "EOF"\n\
[terminal]\n\
vt = 1\n\
[default_session]\n\
command = "/usr/bin/tuigreet --remember --cmd '\''env LIBVA_DRIVER_NAME=iHD dbus-run-session -- niri'\''"\n\
user = "live"\n\
EOF'

# --- Systemwide Niri config that autostarts dms + helpers ---
RUN mkdir -p /etc/xdg/niri
RUN bash -lc 'cat > /etc/xdg/niri/config.kdl << "EOF"\n\
// Minimal Niri config: spawn dms and a few helpers DMS recommends\n\
environment {\n\
  XDG_CURRENT_DESKTOP \"niri\"\n\
}\n\
spawn-at-startup \"bash\" \"-c\" \"wl-paste --watch cliphist store &\"\n\
spawn-at-startup \"/usr/libexec/polkit-mate-authentication-agent-1\"\n\
spawn-at-startup \"dms\" \"run\"\n\
EOF'

# --- Enable services + boot target ---
RUN systemctl set-default graphical.target && \
    systemctl enable greetd.service && \
    systemctl enable NetworkManager.service && \
    systemctl enable seatd.service

# Labels help bootc-aware tools
LABEL bootc=1

