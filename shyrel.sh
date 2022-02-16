#!/bin/bash

##################################################
#
# Initialization
#
##################################################

DIR=$(dirname $0)
APPNAME="shyrel"

# load config files and utils
source $DIR/checkConfig.sh
source ~/.bashrc


##################################################
#
# parse command line arguments
#
##################################################

# invoke getopt on the list of arguments $@
PARSED_OPTIONS=$(getopt -n "$0" -o h --long "help,day:,conf:" -- "$@")

# check if getopt went fine
if [ $? -ne 0 ];
then
    echo "[$APPNAME][ERROR] -- Wrong arguments!"
    exit 1
fi

# now let's process getopt output
eval set -- "$PARSED_OPTIONS"
while true;
do
    case "$1" in
	-h|--help)	    
	    echo "[$APPNAME] -- Mandatory parameters:"
	    echo "[$APPNAME] -- * --conf=<CONFIGFILE>"
	    echo "[$APPNAME] -- Optional parameters:"
	    echo "[$APPNAME] -- * --day=<YYYYMMDD>"
	    shift;;
	--conf)
	    echo "[$APPNAME] -- Config file set to $2"
	    CONFIGFILE=$2
	    shift 2;;
	--day)
	    echo "[$APPNAME] -- Date set to $2"
	    DATE=$2
	    shift 2;;		
	--)
	    shift
	    break;;
    esac
done


##################################################
#
# Check/load the config file provided as input
#
##################################################

if [[ -z $CONFIGFILE ]]; then
    echo "[$APPNAME][ERROR] -- Configuration file not provided!"
    exit
else
    echo "[$APPNAME] -- Loading config file $CONFIGFILE"
    source $CONFIGFILE
fi



##################################################
#
# Check the config file
#
##################################################

checkConfig $CONFIGFILE
configStatus=$?
if [[ $configStatus -ne 0 ]]; then
    exit $configStatus
fi


##################################################
#
# Download analysis, forecast and simulation
#
##################################################

echo "[$APPNAME] -- Downloading analysis files"
$DIR/down_an.sh $CONFIGFILE

echo "[$APPNAME] -- Downloading simulation files"
$DIR/down_sim.sh $CONFIGFILE

echo "[$APPNAME] -- Downloading forecast files"
$DIR/down_fcst.sh $CONFIGFILE

echo "[$APPNAME] -- Shyrel completed!"
