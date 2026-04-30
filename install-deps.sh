#!/usr/bin/env bash
# install-deps.sh — instala dependências de sistema do Big Screen Monitor Display
# em Debian / Ubuntu / Linux Mint (e qualquer derivado com apt).
#
# É chamado pelo `make install`. Em distros não-apt apenas imprime a dica
# correspondente e sai sem erro, pra não quebrar o fluxo.

set -euo pipefail

PACKAGES=(
    # Daemon (main.py)
    librsvg2-bin            # rsvg-convert — renderiza ícones SVG e logo da distro
    lm-sensors              # leitura de temperaturas via psutil.sensors_temperatures
    # GUI de configuração (config_gui.py)
    libgtk-4-1              # GTK 4 runtime
    libgtk-4-dev
    libadwaita-1-0          # libadwaita 1 runtime
    gir1.2-gtk-4.0          # typelib do GTK 4 — necessário p/ gi.require_version('Gtk','4.0')
    gir1.2-adw-1            # typelib da libadwaita 1
    python3-gi              # bindings PyGObject do sistema
    python3-gi-cairo        # backend cairo (config_gui.py força GSK_RENDERER=cairo)
    policykit-1             # pkexec — usado para systemctl como root
    # Toolchain do Makefile
    virtualenv              # criação do .venv com --system-site-packages
)

color() { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }
info()  { color "1;34" "ℹ $1"; }
ok()    { color "1;32" "✔ $1"; }
warn()  { color "1;33" "⚠ $1"; }
err()   { color "1;31" "✖ $1"; }

if ! command -v apt-get >/dev/null 2>&1; then
    warn "apt-get não encontrado — pulando instalação automática de deps de sistema."
    cat <<EOF
   Equivalentes por distro:

   Arch / BigLinux / Manjaro:
     sudo pacman -S gtk4 libadwaita python-gobject python-cairo \\
                    librsvg lm_sensors polkit python-virtualenv

   Fedora:
     sudo dnf install gtk4 libadwaita python3-gobject python3-cairo \\
                      librsvg2-tools lm_sensors polkit python3-virtualenv
EOF
    exit 0
fi

# Idempotência: instala só o que falta
MISSING=()
for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING+=("$pkg")
    fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
    ok "Todas as dependências de sistema já estão instaladas."
    exit 0
fi

info "Pacotes faltando: ${MISSING[*]}"

# Decide privilege escalation
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    err "Não estou rodando como root e não há 'sudo' disponível."
    err "Rode novamente como root, ou instale manualmente: ${MISSING[*]}"
    exit 1
fi

info "Atualizando índice do apt..."
$SUDO apt-get update -qq

info "Instalando pacotes..."
$SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${MISSING[@]}"

ok "Dependências de sistema instaladas."
