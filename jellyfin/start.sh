#!/usr/bin/env bash
#set -o pipefail # Exit code from last command
set -o errexit   # Exit on non-zero status
set -o nounset   # Error on unset variables
set -o xtrace    # Print executed commands

function MAIN {
    # CONFIG
    declare CFG_STORAGE_DIR='/var/home/jellyfin'
    declare CFG_BACKEND_DIR='/var/home/monorepo/server/jellyfin'
    declare CFG_BACKEND_NAME='jellyfin-archlinux'
    declare CFG_BACKEND_TAG="localhost/${CFG_BACKEND_NAME}"


    # WEB [builds /dist]
    local BUILD_FRONTEND=(
        --file='Containerfile.frontend'
        --tag="${CFG_BACKEND_TAG}/frontend:latest"
        --ulimit='nofile=65535:65535'
        --volume="${CFG_BACKEND_DIR}/web:/src"
        #--volume='/var/cache/apk:/var/cache/apk:rslave'
        --volume='/var/cache/pacman/pkg:/var/cache/pacman/pkg:rslave'

        #--no-cache='true'
    )
    mkdir -p /var/cache/apk
    podman build ${BUILD_FRONTEND[@]}


    # API [builds runtime]
    local BUILD_BACKEND=(
        --file='Containerfile.backend'
        --tag="${CFG_BACKEND_TAG}/backend:latest"
        --volume='/var/cache/pacman/pkg:/var/cache/pacman/pkg:rslave'

        #--no-cache='true'
    )
    podman build ${BUILD_BACKEND[@]}

    # SERVER [runtime]
    local RUNTIME_BACKEND=(
        --name="${CFG_BACKEND_NAME}"
        --replace='true'
        --rm='true'
        --label='io.containers.autoupdate=registry'

        --network='host'
        #--publish='8096:8096/tcp'
        #--userns='keep-id'

        --volume="${CFG_BACKEND_DIR}/web/dist:/dist"
        --volume="${CFG_STORAGE_DIR}/cache:/cache:Z"
        --volume="${CFG_STORAGE_DIR}/config:/config:Z"
        --mount="type=bind,source=${CFG_STORAGE_DIR}/media,destination=/media,ro=true,relabel=private"
        --device='/dev/dri/renderD128'

        --pull='newer'
        --detach='false'
        #--restart='unless-stopped'
        #--interactive='true'
        #--tty='true'
    )
    mkdir -p ${CFG_STORAGE_DIR}/{dist,cache,config,media}
    podman stop --ignore ${CFG_BACKEND_NAME}
    podman run ${RUNTIME_BACKEND[@]} ${CFG_BACKEND_TAG}/backend:latest
}

clear; MAIN
