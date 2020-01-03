#!/bin/bash


# MariaDB Backup Script
# Developed by DESENBAHIA-GTI Team
# This shell script implelements multi-database backup operation for MariaDB. It provides 
# It dumps all databases (compressed using gzip) into an specifc directory labeled by "date-hour".
# Its log feature sends messages to the stdout and to a file as well.
# Dump files overwriten at the same hour.
# It was built with modularity, extensibility and simplicity in mind.
#
# Tested in MariaDB 10.3.16 version
#
# Try...catch approach
# { commandA && commandB } || { block C }
# If commandA succeeds, runs commandB (and so on); if it fails, runs block C
# Optional:
# Use trap to capture unexpected/signal errors
# The adoption of "||" as error handler doesn't ensure the other part gets executed even under
# exceptional conditions (signals), which is pretty much what one expects from finally. That's the reason 
# of the function signal_error().
#
# Strongly recomended: create ~/.my.cnf file with credentials
# [mysql]
# user=myuser
# password=secret
#
# [mysqldump]
# user=myuser
# password=secret
#
# $ chmod 660 ~/.my.cnf



# DEBUG ON/OFF
# set -x


# Variables
DATE_INVERTED=$(date +%Y-%m-%d)
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
HOUR=$(date +%H)
#NOW=$(date +%d-%m-%Y_%Hh%Mm%Ss)
BACKUP_DIR="/var/opt/mariadb/backup"
BACKUP_DIR_CURRENT="${BACKUP_DIR}/${DATE_INVERTED}_${HOUR}h"
ECHO_TYPE=("[MSG]" "[WAR]" "[ERR]")
RETENTION="+2" # deletes from the day before yesterday on
LOG_DIR="/var/opt/mariadb/log"
LOG_FILE="backup_log.txt"
LOG_FILE_CURRENT="${YEAR}_${MONTH}_${LOG_FILE}"


# # Optional
# # Called for error
# signal_err()
# {
#     create_log_header
#     register_log "${ECHO_TYPE[2]} An unexpected error occurred."
#     create_log_footer
#     exit 1
# }
# # Call function signal_err() for any failures
# trap signal_err ERR


# Register in the console and file
# TO DO: Analytics tool
register_log(){
    echo $1
    { # try
        echo $1 >> $LOG_DIR/$LOG_FILE_CURRENT
    } || { # catch
        ERR_CODE=$?
        echo "${ECHO_TYPE[2]} Failed to log in file. ERR_CODE: ${ERR_CODE}."
        return $ERR_CODE
    }
    return $? # exit value of the last run command
}


# Creates backup and log directories
setup(){
    { # try
        if [ ! -d ${LOG_DIR} ]
        then
            mkdir -p ${LOG_DIR}
        fi
        
        if [ ! -d ${BACKUP_DIR} ]
        then
            mkdir -p ${BACKUP_DIR}
        fi
    } || { # catch
        ERR_CODE=$?
        register_log "${ECHO_TYPE[2]} Failed to configure runtime environment (backup/log directories not created). ERR_CODE: ${ERR_CODE}."
        return $ERR_CODE
    }
}


# Creates directory using current date as its name
create_dir(){
    { # try
        mkdir -p $BACKUP_DIR_CURRENT &&
        register_log "${ECHO_TYPE[0]} Directory $BACKUP_DIR_CURRENT created."
    } || { # catch
        ERR_CODE=$?
        register_log "${ECHO_TYPE[2]} Directory $BACKUP_DIR_CURRENT can not be created. ERR_CODE: ${ERR_CODE}."
        return $ERR_CODE
    }
}


create_log_header(){
    register_log ""
    register_log "- Started backup: $(date +%d-%m-%Y_%Hh%Mm%Ss)"
}


create_log_footer(){
    register_log "- Finished backup: $(date +%d-%m-%Y_%Hh%Mm%Ss)"
    register_log ""
}


init(){
    setup
    create_log_header
    create_dir
}


terminate(){
    # Only root can access
    chown 0.0 -R $BACKUP_DIR_CURRENT
    chmod 0660 $BACKUP_DIR_CURRENT

    create_log_footer
}


dump_db(){

    # Get a list of databases
    { # try
        SELECTED_DATABASES="$(mysql -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema)")" &&
        register_log "${ECHO_TYPE[0]} Selected databases: $SELECTED_DATABASES"
    } || { # catch
        ERR_CODE=$?
        register_log  "${ECHO_TYPE[2]} Failed to select databases. ERR_CODE: ${ERR_CODE}."
        return $ERR_CODE
    }

    # Dump each selected database in a separate file
    { # try
        for db in $SELECTED_DATABASES; do
            # TO DO: Include duration of dump into log file
            # time -f "\t%U user" mysqldump ...
            { # try
                # TO DO: goes throught log even if dump fails ('cos of pipe)
                mysqldump --force --skip-lock-tables --databases $db | gzip > "$BACKUP_DIR_CURRENT/$DATE_INVERTED-$db.sql.gz" &&
                register_log "${ECHO_TYPE[0]} Database $db dumped and compressed."
            } || { # catch
                    ERR_CODE=$?
                    register_log  "${ECHO_TYPE[2]} Failed to dump database. ERR_CODE: ${ERR_CODE}."
                    return $ERR_CODE   
            }
        done
    } || { # catch
        ERR_CODE=$?
        register_log  "${ECHO_TYPE[2]} Failed to dump database (loop). ERR_CODE: ${ERR_CODE}."
        return $ERR_CODE
    }
}


clean_old_bkp(){
    # Delete the directories older than $RETENTION days
    { #try
        DELETED_BACKUPS="$(find $BACKUP_DIR -mtime $RETENTION -exec rm -rf {} +;)"
        # TO DO: msg migth consider if none is deleted
        # TO DO: show the $DELETED_BACKUPS as below
        # register_log "${ECHO_TYPE[0]} Old backups deleted: (${DELETED_BACKUPS})."
    } || { # catch
        ERR_CODE=$?
        register_log "${ECHO_TYPE[2]} Failed to delete old backups files. ERR_CODE: ${ERR_CODE}."
        return $ERR_CODE
    }
}



## Main script starts here
{
    init &&
    dump_db &&
    clean_old_bkp &&
    terminate
} || {
    ERR_CODE=$?
    register_log "${ECHO_TYPE[2]} Execution fail. ERR_CODE: ${ERR_CODE}."
}
