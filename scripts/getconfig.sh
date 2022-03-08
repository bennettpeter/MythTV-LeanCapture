#!/usr/bin/echo This file is not executable
# This must be sourced into bash scripts instead of /etc/mythtv/mysql.txt
# It sets up environment variables for the fields from config.xml

if [[ "$MYTHCONFDIR" == "" ]] ; then
    MYTHCONFDIR="$HOME/.mythtv"
fi

paramfile=$MYTHCONFDIR/config.xml

function parsexml {
    context=$1
    keyword=$2
    value=`xmllint $paramfile --xpath $context/$keyword` || true
    if [[ "$value" != "" ]] ; then
        value=`echo $value | sed -e "s~ *<$keyword>~~;s~</$keyword> *~~"`
    fi
}
if [[ -f $paramfile ]] ; then
    parsexml //Configuration/Database Host         ; DBHostName=$value
    parsexml //Configuration/Database UserName     ; DBUserName=$value
    parsexml //Configuration/Database Password     ; DBPassword=$value
    parsexml //Configuration/Database DatabaseName ; DBName=$value
    parsexml //Configuration/Database Port         ; DBPort=$value
    parsexml //Configuration LocalHostName         ; LocalHostName=$value
fi
if [[ "$LocalHostName" == "" || "$LocalHostName" == "my-unique-identifier-goes-here" ]]; then
    LocalHostName=`cat /etc/hostname`
fi
if [[ "$DBHostName" == "" ]] ; then
    echo "ERROR parsing config.xml"
fi

mysqlcmd="mysql -N --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"
