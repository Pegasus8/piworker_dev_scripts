#!/usr/bin/bash
#
# Script to release a new version of PiWorker.

set -e

VERSION="v0.1.0-alpha.1"
PW_PATH="$HOME/go/src/github.com/Pegasus8/piworker"
RELEASE_PATH="$HOME/PW/bin/release"
OS=("linux")
ARCH=("arm" "amd64")
ARM=7


cd "$PW_PATH/webui/frontend"

echo "Compiling frontend..."
if ! npm run build >/dev/null; then
    echo "Error when trying to compile the frontend"
    exit 1
fi
echo "Done!"

cd "../.."

echo "Running pkger..."
if ! pkger; then
    echo "Error when running pkger"
fi
echo "Done!"

for os in "${OS[@]}"; do
    for arch in "${ARCH[@]}"; do
        output_path="$RELEASE_PATH/$VERSION/$os-$arch"

        mkdir -p "$output_path"

        echo "[$os-$arch] Building"
        if [[ "$os" == "linux" && "$arch" == "arm" ]]; then
            if env \
                CC=arm-linux-gnueabihf-gcc \
                CXX=arm-linux-gnueabihf-g++ \
                CGO_ENABLED=1 \
                GOOS="$os" \
                GOARCH="$arch" \
                GOARM="$ARM" \
                go build -o "$output_path"
            then
                echo "[$os-$arch] Compiled successfully"
            else
                echo "[$os-$arch] Error when trying to compile"
                continue
            fi
        else
            if env \
                GOOS="$os" \
                GOARCH="$arch" \
                go build -o "$output_path"
            then
                echo "[$os-$arch] Compiled successfully"
            else
                echo "[$os-$arch] Error when trying to compile"
                continue
            fi
        fi

        exec_path="$output_path/piworker"

        if [[ ! -x "$exec_path" ]]; then
            echo "[$os-$arch] Can't found the executable"
            continue
        fi

        echo "[$os-$arch] Compressing the executable"

        filename="piworker-${os}_${arch}-${VERSION}.tar.gz"

        cd "$output_path"

        if ! tar -czf "$filename" "$exec_path"; then
            echo "[$os-$arch] Error when trying to compress the executable"
            continue
        fi

        echo "[$os-$arch] Removing the executable"
        rm "$exec_path"

        echo "[$os-$arch] Making checksum of $filename"
        if ! sha256sum "$filename" &>"$filename.sha256sum"; then
            echo "[$os-$arch] Error when trying to make the sha256sum file"
            continue
        fi

        echo "[$os-$arch] Process finished"

        cd "$PW_PATH"
    done
done