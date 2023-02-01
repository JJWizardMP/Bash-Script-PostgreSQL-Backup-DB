#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
#########################################################################################################
# name: Database Back Up
# version: 1.0.8
# description: This script allow create a backup for your database, also can restore the db
# keywords: bash, psql, pg_dump, pg_restore, crontab
# author: JJMPWizard
# lastupdate: 20/07/2022
#########################################################################################################
# @params
# task: "export" or "import" (required argument)
# method: may be "local" or "remote" on "export" and could be "1" on "import" (required argument)
# dbflag: pass "0" for create a database with the date of today and without create a role or 
#  pass "1" for create db and role when you use "import", pass any other number,
#  if it is not the case (required argument if you use "import" task)
# filename_backup: you must be specify the absolute path of the backup file 
#  you want to import(opcional argument)
#########################################################################################################
declare -A ERRORS_MSGS=( \
    [TWO_ARGS_REQUIRED]='Pass the two require arguments!\n' \
    [FIRST_ARG_REQUIRED]='The first argument is required!\n' \
    [FIRST_ARG_WRONG]='The first argument must be "import", "export" or "directory"!\n' \
    [SECOND_ARG_REQUIRED]='The second argument is required!\n' \
    [SECOND_ARG_WRONG]='Error, pass "local" or "remote" as second argument!\n' \
    [THIRD_ARG_REQUIRED]='Pass the third arguments if you use "import"!\n' \
    [THIRD_ARG_WRONG]='Error on import, pass "0" or "1" as third argument for (0) \
    for create a new db or (1) to create and assings a role in db!\n' \
    [FILE_DOES_NOT_EXIST]='The file that you want to import does not exist or not found!\n' \
)
# set env arguments
setEnvArguments(){
    export task=$1
    export method=$2
    export dbflag=$3
    export filename_backup=$4
}
# Extract database credentials from .env
setEnvVariables(){
    export projectdir=$( cat "/$( pwd | cut -d '/' -f2-3 )/scriptSshBdVcm/.env" | grep 'PROJECT_PATH' | cut -d '=' -f2 )
    export absolutepath=$( cat "${projectdir}/.env" | grep 'STORAGE_PATH' | cut -d '=' -f2 )
    export path=$( date +"%Y-%m-%d" )
    export host=$( cat "${projectdir}/.env" | grep 'DB_HOST' | cut -d '=' -f2 )
    export port=$( cat "${projectdir}/.env" | grep 'DB_PORT' | cut -d '=' -f2 )
    export database=$( cat "${projectdir}/.env" | grep 'DB_NAME' | cut -d '=' -f2 )
    export username=$( cat "${projectdir}/.env" | grep 'DB_USERNAME' | cut -d '=' -f2 )
    export PGPASSWORD=$( cat "${projectdir}/.env" | grep 'DB_PASSWORD' | cut -d '=' -f2 )
}
# Delete variables
unsetEnvVariables(){
    # Unset arguments
    unset task
    unset method
    unset dbflag
    unset filename_backup
    # Unset db variables
    unset host
    unset port
    unset database
    unset username
    unset PGPASSWORD
    # Unset utility variables
    unset absolutepath
    unset projectdir
    unset path
    unset dbname
}
# Reset bash
resetBash(){
    exec bash
    su - $(whoami)
}
#################################################################
# Handle Errors Control
verifyArguments(){
    throwError_firstArgRequired
    throwError_secondArgRequired
    #throwError_twoArgsRequired
    throwError_thirdArgRequired
}
throwError_firstArgRequired(){
    if [[ -z ${task} ]] 
    then
        echo -e ${ERRORS_MSGS[FIRST_ARG_REQUIRED]}
        exit 1
    fi
}
throwError_firstArgWrong(){
    echo -e ${ERRORS_MSGS[FIRST_ARG_WRONG]}
    exit 1
}
throwError_secondArgRequired(){
    if ( [[ "${task}" = 'export' ]] || [[ "${task}" = 'import' ]] ) && [[ -z ${method} ]] 
    then
        echo -e ${ERRORS_MSGS[SECOND_ARG_REQUIRED]}
        exit 1
    fi
}
throwError_secondArgWrong(){
    echo -e ${ERRORS_MSGS[SECOND_ARG_WRONG]}
    exit 1
}
throwError_twoArgsRequired(){
    if [[ -z ${task} ]] || [[ -z ${method} ]]
    then
        echo -e ${ERRORS_MSGS[TWO_ARGS_REQUIRED]}
        exit 1
    fi
}
throwError_thirdArgRequired(){
    if [[ "${task}" = 'import' ]] && [[ -z ${dbflag} ]]
    then
        echo -e ${ERRORS_MSGS[THIRD_ARG_REQUIRED]}
        exit 1
    fi
}
throwError_thirdArgWrong(){
    echo -e ${ERRORS_MSGS[THIRD_ARG_WRONG]}
    exit 1
}
throwError_fileDoesnotExist(){
    filename=$( echo $1 )
    if [[ ! -e "${filename}" ]]
    then
        echo -e ${ERRORS_MSGS[FILE_DOES_NOT_EXIST]}
        exit 1
    fi
}
# Daily directory for backups
directoryExists(){
    if [[ ! -d "${absolutepath}/${path}" ]]
    then
        mkdir -p "${absolutepath}/${path}"
    fi
}
cleanDirectory(){
    end=$( ls "${absolutepath}/" | wc -l | tr -d ' ' )
    start=$( echo "${end}-2" | bc -l )
    ls "${absolutepath}/" | sed "${start},${end} d" > /tmp/dirs.txt
    while read -r line;
    do
        rm -R "${absolutepath}/${line}"
    done < /tmp/dirs.txt
    rm -f /tmp/dirs.txt
}
# Run backup for db
exportDB(){
    case ${method} in
        local)
            # Run from local
            pg_dump -F t "${database}" > "${absolutepath}/${path}/backupdb-$(date +"%Y_%m_%d_%H_%M_%S").tar"
        ;;
        remote)
            # Run to remote host
            pg_dump -F t -U "${username}" -h "${host}" -p "${port}" "${database}" > "${absolutepath}/${path}/backupdb-$(date +"%Y_%m_%d_%H_%M_%S").tar"
        ;;
        *)
            throwError_secondArgWrong
        ;;
    esac
}
# Create a file to create db, user and assing roles and privileges
createQueryFile(){
    case ${dbflag} in
        0) # Create database with the date of today and without create a role
            export dbname=$( date +"%Y-%m-%d-%H-%M-%S" )
            {
                echo "CREATE DATABASE \"${dbname}\";"
                echo "GRANT ALL PRIVILEGES ON DATABASE \"${dbname}\" TO ${username};"
            } > /tmp/restoreDB.sql
        ;;
        1) # Create database with the same db name and a role
            {
                echo "CREATE DATABASE \"${database}\";"
                echo "CREATE USER ${username} WITH CREATEDB LOGIN PASSWORD '${PGPASSWORD}';"
                echo "ALTER ROLE ${username} SET client_encoding TO 'utf8';"
                echo "ALTER ROLE ${username} SET default_transaction_isolation TO 'read committed';"
                echo "ALTER ROLE ${username} SET timezone TO 'UTC';"
                echo "GRANT ALL PRIVILEGES ON DATABASE \"${database}\" TO ${username};"
            } > /tmp/restoreDB.sql
        ;;
        *)
            :
        ;;
    esac
}
# Load query file
loadQueryFile(){
    query_user=$( [[ "${dbflag}" == 1 ]] && echo "postgres" || echo "${username}" )
    # Pass a sql file to the db engine
    case ${method} in
        local)
            # Run from local
            psql -U "${query_user}" -f /tmp/restoreDB.sql
        ;;
        remote)
            # Run to remote host
            psql -h "${host}" -p "${port}" -U "${query_user}" -f /tmp/restoreDB.sql
        ;;
        *)
            throwError_secondArgWrong
        ;;
    esac
}
# Delete query file
removeQueryFile(){
    if [[ -e "/tmp/restoreDB.sql" ]]
    then
        rm -f /tmp/restoreDB.sql
    fi
}
# Compose function
runQueryFile(){
    if [[ ${dbflag} == 0 ]] || [[ ${dbflag} == 1 ]]
    then
        createQueryFile
        loadQueryFile
        removeQueryFile
    fi
}
# Import DB
importDB(){
    restore_user=$( [[ "${dbflag}" == 1 ]] && echo "postgres" || echo "${username}" )
    restore_db=$( [[ "${dbflag}" == [1-9]+ ]] && echo "${database}" || echo "${dbname}" )
    # Get name of the last backup if you do not especify the file name you want to import
    if [[ -n $filename_backup ]] 
    then
        filename=$( echo ${filename_backup} | tr '/' '\n' | tail -1 )
        throwError_fileDoesnotExist "${filename}"
    else
        filename=$( ls "${absolutepath}/${path}" | sort -r | head -1 )
    fi
    # import db into postgres
    case ${method} in
        local)
            # Run from local
            #psql -U "${restore_user}" -d "${restore_db}" < "${absolutepath}/${path}/${filename}"
            pg_restore -c -U "${restore_user}" -d "${restore_db}" -v "${absolutepath}/${path}/${filename}"
        ;;
        remote)
            # Run to remote host
            pg_restore -c -U "${restore_user}" -h "${host}" -p "${port}" -d "${restore_db}" -v "${absolutepath}/${path}/${filename}"
        ;;
        *)
            throwError_secondArgWrong
        ;;
    esac
}
# Main script
main(){
    setEnvArguments $1 $2 $3 $4
    setEnvVariables
    verifyArguments
    directoryExists
    case ${task} in
        export)
            # Run export backup
            exportDB
        ;;
        import)
            # Run import backup
            runQueryFile
            importDB
        ;;
        directory)
            cleanDirectory
        ;;
        *)
            throwError_firstArgWrong
    esac
    unsetEnvVariables
    resetBash
}

main $1 $2 $3 $4

exit 0