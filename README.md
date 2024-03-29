# CentOS 7 Crond for Docker

This image is intended to have crontab configurations added by mounting files into it within `/etc/cron.d/`, `/etc/cron.hourly` or similar. Data the scripts need access to can also be mounted into the container. For example, to use this for running a nightly backup script via a systemd unit one could setup the following two files:

For short cron job configurations, the environment variable `CROND_JOB_CONFIG` may be set to base64 encoded contents for the file `/etc/cron.d/jobs` when the container is started.

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
        -e CROND_ENV_FILTER=^BACKUP_ \
        -e BACKUP_FILE_SOURCE=/data/${DIRECTORY_NAME} \
        -e BACKUP_FILE_TARGET=/backup/${DIRECTORY_NAME} \
        -e BACKUP_FILE_PREFIX=${DIRECTORY_NAME}-data \
        --name ${CONTAINER_NAME} ${CONTAINER_IMAGE}

    [Install]
    WantedBy=multi-user.target


`/var/lib/crond/backup-data`

    #!/bin/bash
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

    ## Wrap execution to redirect output to PID 1 procs so it will turn up in container logs
    {
        :: Starting backup for "${BACKUP_FILE_SOURCE}"
        # Tar returns non-zero exit code if (for example) a file is written to while it's reading it; this will happen
        # with Jira log files, so we must ignore the exit code to avoid halting the run and leaving a backup file able
        # to be ready by non-root users
        tar -czf "${BACKUP_FILE_OUTPUT}" -C "${BACKUP_FILE_SOURCE}" . || true
        chmod 600 "${BACKUP_FILE_OUTPUT}"

        :: Cleaning up files older than 30 days in "${BACKUP_FILE_TARGET}"
        find "${BACKUP_FILE_TARGET}" -type f -mtime +30 | sort | xargs -tI FILE rm -v FILE

        :: Completed backup for "${BACKUP_FILE_SOURCE}"
    } 1>/proc/1/fd/1 2>/proc/1/fd/2
