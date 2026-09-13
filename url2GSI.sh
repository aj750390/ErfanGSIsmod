#!/bin/bash

# Project OEM-GSI Porter by Erfan Abdi <erfangplus@gmail.com>

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
TOOLS_DIR="$PROJECT_DIR/tools"
PARTITIONS="system vendor cust odm oem factory product xrom systemex system_ext reserve india system_dlkm vendor_dlkm"

AB=false
AONLY=false
MOUNTED=false
CLEAN=false

usage()
{
    echo "Usage: [--help|-h|-?] [--ab|-b] [--aonly|-a] [--mounted|-m] [--cleanup|-c] $0 <Firmware link> <Firmware type> [Target type: AB/Aonly]"
    echo -e "\tFirmware link: Firmware download link or local path"
    echo -e "\tFirmware type: Firmware mode"
    echo -e "\t--ab: Build only AB"
    echo -e "\t--aonly: Build only A-Only"
    echo -e "\t--cleanup: Cleanup downloaded firmware"
    echo -e "\t--help: To show this info"
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --ab|-b)
    AONLY=false
    AB=true
    shift
    ;;
    --aonly|-a)
    AONLY=true
    AB=false
    shift
    ;;
    --cleanup|-c)
    CLEAN=true
    shift
    ;;
    --help|-h|-?)
    usage
    exit 0
    ;;
    *)
    POSITIONAL+=("$1")
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}"

if [[ ! -n $2 ]]; then
    echo "ERROR: Enter all needed parameters"
    usage
    exit 1
fi

URL=$1
shift
SRCTYPE=$1
shift
TARGET_INPUT=$1

# Handle target type passed as 3rd argument (e.g., ":AB", "AB", ":Aonly")
if [[ "$TARGET_INPUT" == *"Aonly"* ]]; then
    AONLY=true
    AB=false
elif [[ "$TARGET_INPUT" == *"AB"* ]]; then
    AB=true
    AONLY=false
elif [ $AB == false ] && [ $AONLY == false ]; then
    # Default to AB for modern Android
    AB=true
fi

ORIGINAL_URL=$URL

if [[ $SRCTYPE == *":"* ]]; then
    SRCTYPENAME=$(echo "$SRCTYPE" | cut -d ":" -f 2)
else
    SRCTYPENAME=$SRCTYPE
fi

DOWNLOAD()
{
    URL="$1"
    ZIP_NAME="$2"
    echo "Downloading firmware to: $ZIP_NAME"
    aria2c -x16 -s16 -j$(nproc) -U "Mozilla/5.0" -d "$PROJECT_DIR/input" -o "$ACTUAL_ZIP_NAME" "${URL}" || wget -U "Mozilla/5.0" "${URL}" -O "$ZIP_NAME"
}

MOUNT()
{
    for p in $PARTITIONS; do
        if [[ -e "$1/$p.img" ]]; then
            # Convert sparse images to raw before mounting
            if file "$1/$p.img" | grep -q "Android sparse image"; then
                echo "Unsparsing $p.img..."
                simg2img "$1/$p.img" "$1/$p.raw.img" && mv "$1/$p.raw.img" "$1/$p.img"
            fi
            mkdir -p "$1/$p"
            printf "$p " >> "$1/mounted.txt"
            if [ $(uname) == Linux ]; then
                sudo mount -o loop,ro "$1/$p.img" "$1/$p"
            elif [ $(uname) == Darwin ]; then
                fuse-ext2 "$1/$p.img" "$1/$p"
            fi
        fi
    done
}

UMOUNT()
{
    for p in $PARTITIONS; do
        if [[ -d "$1/$p" ]]; then
            sudo umount "$1/$p" 2>/dev/null || true
        fi
    done
}

CLEANUP()
{
    UMOUNT "$PROJECT_DIR/working"
    rm -rf "$PROJECT_DIR/working"
}

ERROR_EXIT()
{
    echo "Build failed. Cleaning up..."
    CLEANUP
    exit 1
}

echo "Updating tools..."
"$PROJECT_DIR"/update.sh

mkdir -p "$PROJECT_DIR/input" "$PROJECT_DIR/working" "$PROJECT_DIR/output"

if [[ -d "$URL" ]]; then
    MOUNTED=true
fi

ZIP_NAME="$PROJECT_DIR/input/dummy"
if [ $MOUNTED == false ]; then
    if [[ "$URL" == "http"* ]]; then
        RANDOMM=$(echo $RANDOM)
        ACTUAL_ZIP_NAME="${RANDOMM}_FIRMWARE.tgz"
        ZIP_NAME="$PROJECT_DIR/input/${RANDOMM}_FIRMWARE.tgz"
        DOWNLOAD "$URL" "$ZIP_NAME"
        URL="$ZIP_NAME"
    fi
    $TOOLS_DIR/Firmware_extractor/extractor.sh "$URL" "$PROJECT_DIR/working" || ERROR_EXIT
    if [ $CLEAN == true ]; then
        rm -rf "$ZIP_NAME"
    fi
    MOUNT "$PROJECT_DIR/working"
    URL="$PROJECT_DIR/working"
fi

if [ $AB == true ]; then
   echo "Starting AB partition build..."
   "$PROJECT_DIR"/make.sh "${URL}" "${SRCTYPE}" AB "$PROJECT_DIR/output" || ERROR_EXIT
fi

if [ $AONLY == true ]; then
   echo "Starting Aonly partition build..."
   "$PROJECT_DIR"/make.sh "${URL}" "${SRCTYPE}" Aonly "$PROJECT_DIR/output" || ERROR_EXIT
fi

echo "Porting ${SRCTYPENAME} GSI done on: $PROJECT_DIR/output"

if [[ -f "$PROJECT_DIR/private_utils.sh" ]]; then
    . "$PROJECT_DIR/private_utils.sh"
    UPLOAD "$PROJECT_DIR/output" ${SRCTYPENAME} ${AB} ${AONLY} "${ORIGINAL_URL}"
fi

# Clean up temporary mounted images and exit successfully
CLEANUP
echo "Process completed successfully."
exit 0
