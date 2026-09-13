#!/bin/bash

set -e

echo "Setting up environment for GSI Tool..."

if [[ "$OSTYPE" == "linux-gnu" ]]; then
    distro=$(awk -F= '$1 == "ID" {print $2}' /etc/os-release | tr -d '"')
    id_like=$(awk -F= '$1 == "ID_LIKE" {print $2}' /etc/os-release | tr -d '"')

    if [[ "$distro" == "arch" || "$id_like" == *"arch"* ]]; then
        echo "Arch Linux detected"
        sudo pacman -Sy --needed --noconfirm \
            unace unrar zip unzip p7zip sharutils uudeview arj cabextract \
            file-roller dtc xz python python-pip brotli lz4 gawk aria2 \
            erofs-utils e2fsprogs android-tools
    else
        echo "Debian/Ubuntu detected"
        sudo apt-get update -y
        sudo apt-get install -y \
            unace unrar zip unzip p7zip-full sharutils uudeview arj cabextract \
            file-roller device-tree-compiler liblzma-dev brotli liblz4-tool \
            gawk aria2 xz-utils e2fsprogs simg2img libfuse-dev erofs-utils \
            python3 python3-pip python3-setuptools python3-wheel python-is-python3
    fi

    # Ensure pip maps to python3
    if ! command -v pip &> /dev/null; then
        sudo ln -sf "$(which pip3)" /usr/local/bin/pip || true
    fi

    # Determine if pip requires --break-system-packages (PEP 668 on Debian/Ubuntu 23+)
    PIP_ARGS=""
    if python3 -m pip install --help | grep -q -- '--break-system-packages'; then
        PIP_ARGS="--break-system-packages"
    fi

    # Upgrade pip and install modern Python packages
    python3 -m pip install $PIP_ARGS --upgrade pip
    # Pin protobuf to 3.20.x to prevent descriptor crashes in payload_dumper
    # Use pycryptodome instead of dead pycrypto
    python3 -m pip install $PIP_ARGS "protobuf>=3.19.0,<3.21.0" pycryptodome setuptools wheel

elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS detected"
    brew install protobuf xz brotli lz4 aria2 python3 erofs-utils || true
    python3 -m pip install --upgrade pip
    python3 -m pip install "protobuf>=3.19.0,<3.21.0" pycryptodome
fi

echo "Setup completed successfully."
