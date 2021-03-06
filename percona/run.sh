#!/bin/bash

SCRIPT_PATH=$(readlink -f "$0")
DIRECTORY_PATH=$(dirname "${SCRIPT_PATH}")

function init_configuration()
{
    CONFIG_FILE="${DIRECTORY_PATH}/extra/my.cnf"
    if [[ -e "${CONFIG_FILE}" ]]; then
        cp -f "${CONFIG_FILE}" /etc/mysql/conf.d/custom.cnf
        echo "File \"${CONFIG_FILE}\" successfully imported."
    fi
}

function start_mysql()
{
    mysqld &
    PROCESS_ID=$!

    echo "Waiting MySQL..."

    until mysqladmin ping &> /dev/null; do
        sleep 1
    done

    echo "MySQL is alive."
}

function uncompress_files()
{
    workingDir=$1
    if [[ -d ${workingDir} ]]; then
        curDir=$(pwd)
        cd ${workingDir}
        for zipFile in $(ls *.zip 2>>/dev/null)
        do
            echo "Decompress $zipFile"
            unzip ${zipFile}
        done
        for tgzFile in $(ls *.tgz *.tar.gz 2>>/dev/null)
        do
            echo "Extract ${tgzFile}"
            tar -xvf ${tgzFile}
        done
        for gzFile in $(ls *.gz 2>>/dev/null)
        do
            echo "Extract ${gzFile}"
            gunzip ${gzFile}
        done
        cd ${curDir}
    else
        echo "Wrong parameter $*"
    fi
}

function init_databases()
{
    EXTRA_PATH="${DIRECTORY_PATH}/extra"
    if [[ -d "${EXTRA_PATH}" ]]; then
        uncompress_files ${EXTRA_PATH}
        DATABASES_FILES="$(find "${EXTRA_PATH}" -maxdepth 1 -type f -name *.sql | sort)"
        if [[ ! -z "${DATABASES_FILES}" ]]; then
            for FILE in ${DATABASES_FILES}; do
                FILENAME="$(basename "${FILE}")"

                echo "Importing sql file $FILE"
                IMPORT_OUTPUT="$(mysql -u root < "${FILE}" 2>&1)"
                if [[ ! -z "${IMPORT_OUTPUT}" ]]; then
                    echo "An error occured during the \"${FILENAME}\" import. ${IMPORT_OUTPUT}."
                else
                    echo "File \"${FILENAME}\" successfully imported."
                fi

                rm "${FILE}"
            done
        fi
    fi
}

LOCK_FILE="/var/docker.lock"
if [[ ! -e "${LOCK_FILE}" ]]; then
    cp /docker-entrypoint.sh /docker-entrypoint-custom.sh
    sed -i -e "s|exec \"\$@\"|#exec \"\$@\"|g" /docker-entrypoint-custom.sh
    /bin/bash /docker-entrypoint-custom.sh mysqld

    init_configuration
    start_mysql
    init_databases

    touch "${LOCK_FILE}"
    wait "${PROCESS_ID}"
else
    /bin/bash /docker-entrypoint.sh mysqld
fi
