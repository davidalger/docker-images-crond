# CentOS 7 Crond for Docker

This image is intended to have crontab configurations added by mounting files into it within `/etc/cron.d/`, `/etc/cron.hourly` or similar. Data the scripts need access to can also be mounted into the container. For example, to use this for running a nightly backup script via a systemd unit one could setup the following two files:

`/etc/systemd/system/backup-jira.service`

    [Unit]
    Description=Nightly backup for Jira data

    After=data.mount
    Requires=data.mount

    After=backup.mount
    Requires=backup.mount

    [Service]
    TimeoutStartSec=0
    Environment=DIRECTORY_NAME=jira
    Environment=CONTAINER_NAME=backup-jira
    Environment=CONTAINER_IMAGE=davidalger/crond
    ExecStartPre=-/usr/bin/docker kill ${CONTAINER_NAME}
    ExecStartPre=-/usr/bin/docker rm ${CONTAINER_NAME}
    ExecStartPre=/usr/bin/docker pull ${CONTAINER_IMAGE}
    ExecStart=/usr/bin/docker run \
        -v /var/lib/crond/backup-data:/etc/cron.daily/backup-data \
        -v /data/${DIRECTORY_NAME}:/data/${DIRECTORY_NAME} \
        -v /backup/${DIRECTORY_NAME}:/backup/${DIRECTORY_NAME} \
        -e BACKUP_FILE_SOURCE=/data/${DIRECTORY_NAME} \
        -e BACKUP_FILE_TARGET=/backup/${DIRECTORY_NAME} \
        -e BACKUP_FILE_PREFIX=${DIRECTORY_NAME}-data \
        --name ${CONTAINER_NAME} ${CONTAINER_IMAGE}

    [Install]
    WantedBy=multi-user.target


`/var/lib/crond/backup-data.sh`

    #!/usr/bin/env bash
    set -eu

    function :: {
        echo
        echo "==> [$(date +%H:%M:%S)] $@"
    }

    ## Configure backup parameters allowing override for most of these via environment variables in the container
    BACKUP_FILE_SOURCE="${BACKUP_FILE_SOURCE:-"/data"}"
    BACKUP_FILE_TARGET="${BACKUP_FILE_TARGET:-"/backup"}"
    BACKUP_FILE_PREFIX="${BACKUP_FILE_PREFIX:-"data-archive"}"
    BACKUP_FILE_OUTPUT="${BACKUP_FILE_TARGET}/${BACKUP_FILE_PREFIX}-$(date +%F).tgz"

    :: Starting backup for "${BACKUP_FILE_SOURCE}"
    tar -czf "${BACKUP_FILE_OUTPUT}" -C "${BACKUP_FILE_SOURCE}" .
    chmod 600 "${BACKUP_FILE_OUTPUT}"

    :: Cleaning up files older than 30 days in "${BACKUP_FILE_TARGET}"
    find "${BACKUP_FILE_TARGET}" -type f -mtime +30 | sort | xargs -tI FILE rm -v FILE

    :: Completed backup for "${BACKUP_FILE_SOURCE}"
