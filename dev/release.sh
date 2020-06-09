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

#
# ─── FUNCTIONS ──────────────────────────────────────────────────────────────────
#

log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}


#
# ─── EXECUTION ──────────────────────────────────────────────────────────────────
#
    
cd "$PW_PATH/webui/frontend"

log "Compiling frontend..."
if ! npm run build >/dev/null; then
    log "Error when trying to compile the frontend"
    exit 1
fi
log "Done!"

cd "../.."

log "Running pkger..."
if ! pkger; then
    log "Error when running pkger"
fi
log "Done!"

for os in "${OS[@]}"; do
    for arch in "${ARCH[@]}"; do
        output_path="$RELEASE_PATH/$VERSION/$os-$arch"

        mkdir -p "$output_path"

        log "[$os-$arch] Building"
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
                log "[$os-$arch] Compiled successfully"
            else
                log "[$os-$arch] Error when trying to compile"
                continue
            fi
        else
            if env \
                GOOS="$os" \
                GOARCH="$arch" \
                go build -o "$output_path"
            then
                log "[$os-$arch] Compiled successfully"
            else
                log "[$os-$arch] Error when trying to compile"
                continue
            fi
        fi

        exec_path="$output_path/piworker"

        if [[ ! -x "$exec_path" ]]; then
            log "[$os-$arch] Executable not found"
            continue
        fi

        log "[$os-$arch] Compressing the executable"

        filename="piworker-${os}_${arch}-${VERSION}.tar.gz"

        cd "$output_path"

        if ! tar -czf "$filename" "$exec_path"; then
            log "[$os-$arch] Error when trying to compress the executable"
            continue
        fi

        log "[$os-$arch] Removing the executable"
        rm "$exec_path"

        log "[$os-$arch] Doing checksum of $filename"
        if ! sha256sum "$filename" &>"$filename.sha256sum"; then
            log "[$os-$arch] Error when trying to make the sha256sum file"
            continue
        fi

        log "[$os-$arch] Process finished"

        cd "$PW_PATH"
    done
done