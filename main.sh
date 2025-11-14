#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2025, Jagermister
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 3. Neither the name of COPYRIGHT HOLDER nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# Main script to setup a Plasma desktop environment on Alpine Linux

set -e

# Trap errors and exit cleanly
trap 'log_error "Script failed at line $LINENO"; exit 1' ERR

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

source /etc/os-release
if [[ "$ID" != "alpine" ]]; then
    log_error "This script is intended to run on Alpine Linux only."
    exit 1
fi

# Update system packages
log_info "Updating system packages..."
if ! doas apk upgrade; then
    log_error "Failed to upgrade system packages"
    exit 1
fi

# Enable Alpine Edge Repositories
read -p "Enable Alpine Edge repositories? (y/n): " edge_choice
if [[ "$edge_choice" == "y" || "$edge_choice" == "Y" ]]; then
    log_info "Enabling Alpine Edge repositories..."
    EDGE_REPO=("http://dl-cdn.alpinelinux.org/alpine/edge/main" "http://dl-cdn.alpinelinux.org/alpine/edge/community")
    for repo in "${EDGE_REPO[@]}"; do
        if ! doas grep -q "^$repo" /etc/apk/repositories; then
            doas tee -a /etc/apk/repositories <<< "$repo" > /dev/null
        fi
    done
    if ! doas apk upgrade; then
        log_error "Failed to upgrade packages after enabling Edge repositories"
        exit 1
    fi
fi


# Install Plasma desktop environment
log_info "Installing Plasma desktop environment..."
if ! doas setup-desktop plasma; then
    log_error "Failed to install Plasma desktop environment"
    exit 1
fi

# Download Some Wallpapers
read -p "Download additional wallpapers? (y/n): " wallpaper_choice
if [[ "$wallpaper_choice" == "y" || "$wallpaper_choice" == "Y" ]]; then
    log_info "Downloading additional wallpapers..."
    mkdir -p ~/.local/share/wallpapers/Plasma || { log_error "Failed to create wallpapers directory"; exit 1; }
    if ! git clone https://github.com/Jagermist/wallpapers.git ~/.local/share/wallpapers/Plasma --depth=1; then
        log_error "Failed to clone wallpapers repository"
        exit 1
    fi
    log_info "Wallpapers downloaded to ~/.local/share/wallpapers/Plasma, you can set them via wallpaper settings in Plasma."
fi

# Install additional useful packages
read -p "Install additional packages? (y/n): " install_choice
if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
    log_info "Installing additional packages..."
    if ! doas apk add \
        alacritty \
        fish \
        flatpak \
        neovim \
        curl \
        wget \
        gh-cli; then
        log_error "Failed to install additional packages"
        exit 1
    fi
        
    log_info "Configuring Flathub repository for Flatpak..."
    if ! flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        log_warning "Failed to add Flathub repository (may already exist)"
    fi
    if ! flatpak install flathub app.zen_browser.zen --noninteractive -u; then
        log_warning "Failed to install Zen browser via Flatpak"
    fi
fi

# Remove Bloat
read -p "Remove bloat packages? (y/n): " remove_choice
if [[ "$remove_choice" == "y" || "$remove_choice" == "Y" ]]; then
    log_info "Removing bloat packages..."
    if ! doas apk del firefox; then
        log_warning "Failed to remove Firefox (may not be installed)"
    fi
fi

# Add Plasma Development Packages
read -p "Install Plasma development packages? (y/n): " dev_choice
if [[ "$dev_choice" == "y" || "$dev_choice" == "Y" ]]; then
    log_info "Installing Plasma development packages..."
    if ! doas apk add \
        build-base \
        cmake \
        extra-cmake-modules \
        libplasma-dev \
        python3 \
        py3-dbus \
        py3-gobject3 \
        kwin-dev \
        kconfigwidgets-dev \
        libepoxy-dev \
        wayland-dev \
        libdrm-dev; then
        log_error "Failed to install Plasma development packages"
        exit 1
    fi
fi

# Add KDE Rounded Corners Extension if KDE Development Packages Installed
if [[ "$dev_choice" == "y" || "$dev_choice" == "Y" ]]; then
read -p "Install KDE Rounded Corners extension? (y/n): " kd_choice
if [[ "$kd_choice" == "y" || "$kd_choice" == "Y" ]]; then
    log_info "Installing KDE Rounded Corners extension at ${HOME}/Extensions/Plasma/"
    mkdir -p "${HOME}/Extensions/Plasma/" || { log_error "Failed to create Extensions directory"; exit 1; }
    if ! git clone https://github.com/matinlotfali/KDE-Rounded-Corners.git "${HOME}/Extensions/Plasma/KDE-Rounded-Corners" --depth=1; then
        log_error "Failed to clone KDE Rounded Corners repository"
        exit 1
    fi
    pushd "${HOME}/Extensions/Plasma/KDE-Rounded-Corners" || { log_error "Failed to change to KDE Rounded Corners directory"; exit 1; }
    mkdir -p build || { log_error "Failed to create build directory"; exit 1; }
    cd build || { log_error "Failed to change to build directory"; exit 1; }
    if ! cmake ..; then
        log_error "CMake configuration failed"
        exit 1
    fi
    if ! cmake --build . -j; then
        log_error "CMake build failed"
        exit 1
    fi
    if ! doas make install; then
        log_error "Make install failed"
        exit 1
    fi
    if ! sh ../tools/install-autorun-test.sh; then
        log_warning "Failed to run install-autorun-test.sh"
    fi
    popd || exit 1
fi
fi

# Setup AppArmour
read -p "Setup AppArmour for Plasma? (y/n): " aa_choice
if [[ "$aa_choice" == "y" || "$aa_choice" == "Y" ]]; then
    log_info "Setting up AppArmour..."
    if ! doas apk add apparmor apparmor-utils apparmor-profiles; then
        log_error "Failed to install AppArmour packages"
        exit 1
    fi
    log_info "Configuring Grub to enable AppArmour..."
    GRUB_FILE=/etc/default/grub
    if doas grep -q '^GRUB_CMDLINE_LINUX' "$GRUB_FILE"; then
        current=$(doas sed -n 's/^GRUB_CMDLINE_LINUX="\?\(.*\)"\?/\1/p' "$GRUB_FILE" || true)
        new="$current"
        for param in apparmor=1 security=apparmor; do
            if ! echo " $new " | grep -q " $param "; then
                new="$new $param"
            fi
        done
        new=$(echo "$new" | xargs)
        if ! doas sed -i "s#^GRUB_CMDLINE_LINUX=.*#GRUB_CMDLINE_LINUX=\"$new\"#" "$GRUB_FILE"; then
            log_error "Failed to modify GRUB configuration"
            exit 1
        fi
    else
        if ! echo 'GRUB_CMDLINE_LINUX="apparmor=1 security=apparmor"' | doas tee -a "$GRUB_FILE" > /dev/null; then
            log_error "Failed to add GRUB configuration"
            exit 1
        fi
    fi
    doas grub2-mkconfig -o /boot/grub/grub.cfg
    log_info "Enabling AppArmour service..."
    if ! doas rc-update add apparmor boot; then
        log_error "Failed to add AppArmour to boot runlevel"
        exit 1
    fi
fi

# Disable Grub timeout
read -p "Disable GRUB timeout? (y/n): " grub_timeout_choice
if [[ "$grub_timeout_choice" == "y" || "$grub_timeout_choice" == "Y" ]]; then
    log_info "Disabling GRUB timeout..."
    GRUB_FILE=/etc/default/grub
    if doas grep -q '^GRUB_TIMEOUT=' "$GRUB_FILE"; then
        if ! doas sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' "$GRUB_FILE"; then
            log_error "Failed to modify GRUB timeout"
            exit 1
        fi
    else
        if ! echo 'GRUB_TIMEOUT=0' | doas tee -a "$GRUB_FILE" > /dev/null; then
            log_error "Failed to add GRUB timeout configuration"
            exit 1
        fi
    fi
    if ! doas grub2-mkconfig -o /boot/grub/grub.cfg; then
        log_error "Failed to update GRUB configuration"
        exit 1
    fi
fi

log_success "Plasma desktop environment setup completed!"