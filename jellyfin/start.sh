#!/usr/bin/env bash

# [SERVICE]: PARAMETERS
function SERVER_CONFIG {
    #set -o pipefail # Exit code from last command
    set -o errexit   # Exit on non-zero status
    set -o nounset   # Error on unset variables
    set -o xtrace    # Print executed commands

    declare CFG_SERVICE_NAME=${CFG_SERVICE_NAME:='jellyfin-archlinux'}
    declare CFG_SERVICE_REPO=${CFG_SERVICE_REPO:="localhost/${CFG_SERVICE_NAME}"}

    declare CFG_FRONTEND_IMAGE=${CFG_FRONTEND_IMG:='frontend:latest'}
    declare CFG_FRONTEND_DIR=${CFG_FRONTEND_DIR:='/var/home/monorepo/server/jellyfin/web'} # Todo: remove hardcoding

    declare CFG_BACKEND_IMG=${CFG_BACKEND_IMG:='backend:latest'}
    declare CFG_BACKEND_DIR=${CFG_BACKEND_DIR:='/var/home/jellyfin'}
}

# [SERVICE]: INIT
function SERVER_CREATE {
    local BUILD_CACHE=(
        --volume='/var/cache/pacman/pkg:/var/cache/pacman/pkg:rslave'
        #--no-cache='true'
    )

    # WEB [/dist]
    local BUILD_FRONTEND=(
        --file='Containerfile.frontend'
        --tag="${CFG_SERVICE_REPO}/${CFG_FRONTEND_IMG}"
        --ulimit='nofile=65535:65535' # cat /proc/sys/fs/file-nr
        --volume="${CFG_FRONTEND_DIR}:/src"
    )
    podman build ${BUILD_CACHE[@]} ${BUILD_FRONTEND[@]}

    # API [runtime]
    local BUILD_BACKEND=(
        --file='Containerfile.backend'
        --tag="${CFG_SERVICE_REPO}/${CFG_BACKEND_IMG}"
    )
    podman build ${BUILD_CACHE[@]} ${BUILD_BACKEND[@]}
    mkdir --parents ${CFG_BACKEND_DIR}/{dist,cache,config,media}
}

# [SERVICE]: RUNTIME
function SERVER_DEPLOY {
    # Todo: max pids limit needed?
    local RUNTIME_BACKEND=(
        --name="${CFG_SERVICE_NAME}"
        --replace='true'
        --rm='true'
        --label='io.containers.autoupdate=registry'

        --network='host'
        #--publish='8096:8096/tcp'

        #--userns='keep-id'
        --volume="${CFG_FRONTEND_DIR}/dist:/dist"
        --volume="${CFG_BACKEND_DIR}/cache:/cache:Z" # Todo: tmpfs?
        --volume="${CFG_BACKEND_DIR}/config:/config:Z"
        --mount="type=bind,source=${CFG_BACKEND_DIR}/media,destination=/media,ro=true,relabel=private"

        #--device='/dev/dri/renderD128'
        --device='/dev/dri'

        --pull='newer'
        --detach='false'
        #--restart='unless-stopped'
        #--interactive='true'
        #--tty='true'
    )
    podman run ${RUNTIME_BACKEND[@]} ${CFG_SERVICE_REPO}/${CFG_BACKEND_IMG}
}

# [SERVICE]: KILL
function SERVER_UNPLUG {
    podman stop --ignore ${CFG_SERVICE_NAME}
}

# [CLI]: TASKS FINECONTROL
function CLI {
    CLI_ARGS=(${@:2})
    CLI_ARG=${1:-}
    #CLI_DIR=${0%/*}

    # Tasks
    case "${CLI_ARG}" in
        'build')
            clear
            SERVER_CONFIG
            SERVER_CREATE
        ;;

        'start')
            clear
            SERVER_CONFIG
            SERVER_UNPLUG
            SERVER_DEPLOY "${CLI_ARGS[@]}"
        ;;

        'stop')
            SERVER_CONFIG
            SERVER_UNPLUG
        ;;

        'help' | *)
            printf '%s\n' 'Usage: start.sh {start|stop}'
        ;;
    esac
}

CLI "${@}"
