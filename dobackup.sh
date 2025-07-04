#!/usr/bin/env sh

set -e

source /home/backup/.env

# if dry run is mode is enabled, no upload to AWS will be performed
DRY_RUN=${DRY_RUN:-false}
# does everything dry run and in addition no creation of archive
DRY_RUN_WITHOUT_ARCHIVE=${DRY_RUN_WITHOUT_ARCHIVE:-false}

if [ "$DRY_RUN_WITHOUT_ARCHIVE" = true ] || [ "$DRY_RUN" = true ]; then
    echo "Dry run mode is enabled. No backup will be performed."
fi

# default storage class to standard if not provided
S3_STORAGE_CLASS=${S3_STORAGE_CLASS:-STANDARD}

# generate file name for tar
FILE_NAME=/tmp/${BACKUP_NAME}-$(date "+%Y-%m-%d_%H-%M-%S").tar.gz

# Check if TARGET variable is set
if [ -z "${TARGET}" ]; then
    echo "TARGET env var is not set so we use the default value (/data)"
    TARGET=/data
else
    echo "TARGET env var is set"
fi

if [ -z "${S3_ENDPOINT}" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

echo "creating archive"

if [ "$DRY_RUN_WITHOUT_ARCHIVE" = true ]; then
    echo "Dry run without archive mode is enabled. No archive will be created."
    # Creates an empty file to simulate the archive creation and later deletion
    touch "$FILE_NAME"
else
    tar -zcvf "${FILE_NAME}" "${TARGET}"
fi

echo "uploading archive to S3 [${FILE_NAME}, storage class - ${S3_STORAGE_CLASS}]"

if [ "$DRY_RUN_WITHOUT_ARCHIVE" = true ] || [ "$DRY_RUN" = true ]; then
    echo "Dry run mode is enabled. No upload to AWS will be performed."
else
    aws s3 ${AWS_ARGS} cp --storage-class "${S3_STORAGE_CLASS}" "${FILE_NAME}" "${S3_BUCKET_URL}"
fi

echo "removing local archive"
rm "${FILE_NAME}"
echo "done"

if [ -n "${WEBHOOK_URL}" ]; then
    echo "notifying webhook"
    curl -m 10 --retry 5 "${WEBHOOK_URL}"
fi