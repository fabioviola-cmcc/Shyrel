#!/bin/bash

##################################################
#
# Initialization
#
##################################################

DIR=$(dirname $0)
APPNAME="down_an"

# load config files and utils
source $DIR/checkConfig.sh
source ~/.bashrc


##################################################
#
# parse command line arguments
#
##################################################

# invoke getopt on the list of arguments $@
PARSED_OPTIONS=$(getopt -n "$0" -o h --long "help,day:,lat:,lon:,conf:" -- "$@")

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
# Check/set the date
#
##################################################

if [[ -z $DATE ]]; then
    DATE=$(date "+%Y%m%d")
    echo "[$APPNAME] -- Setting date to $DATE"
else
    TODAY=$(date "+%Y%m%d")
    if [[ $DATE -gt $TODAY ]]; then    
	echo "[$APPNAME] -- $DATE cannot be in the future!"    
	exit
    fi
fi


##################################################
#
# Let's start with the rock'n'roll
#
##################################################

# activate conda
if [[ ! -z $CONDA_ENV ]]; then
    echo "[$APPNAME] -- Loading conda environment $CONDA_ENV"
    conda activate $CONDA_ENV
fi

# create output folder, if needed
OUTPUT_DIR=$AN_OUTPUT_DIR/$DATE
if [[ ! -d $OUTPUT_DIR ]]; then
    mkdir -p $OUTPUT_DIR
fi

# iterate over days
for DAY in $(seq ${AN_FIRST_DAY} ${AN_LAST_DAY}); do

    # setting the date to be processed
    CURRDATE=$(date -d "$DATE -${DAY}days" +%Y%m%d)
    echo "[$APPNAME] -- Day $CURRDATE"
    
    # iterate over variables
    for VAR in ${VARIABLES[*]}; do

	# debug print
	echo "[$APPNAME] ---- Processing variable $VAR"
	
	# get the file name to be created
	FILE_ACRONYM=$(echo $VAR | cut -f 1 -d ":")

	# build the variable list
	VAR_LIST=""
	for VARNAME in $(echo $VAR | cut -f 2 -d ":" | tr "," "\n"); do
	    VAR_LIST="${VAR_LIST} --variable ${VARNAME}"
	done

	# determine the output filename
	OUTFILE_NAME="${CURRDATE}_d-MERCATOR--${FILE_ACRONYM}--${REGION_ACRONYM}-b${DATE}_an-fv01.nc"

	# build the timesteps
	T1="${CURRDATE:0:4}-${CURRDATE:4:2}-${CURRDATE:6:2} 12:00:00"
	T2=${T1}
	
	# motu client invocation
	if [[ ! -e ${OUTPUT_DIR}/${OUTFILE_NAME} ]]; then
	    echo "[$APPNAME] ------ Downloading file ${OUTFILE_NAME}"
	    python -m motuclient --user ${MOTU_USER} --pwd ${MOTU_PASW} --motu ${MOTU_HOST} --depth-min=${MIN_DEPTH} --depth-max=${MAX_DEPTH} --latitude-min=${REGION_MINLAT} --latitude-max=${REGION_MAXLAT} --longitude-min=${REGION_MINLON} --longitude-max=${REGION_MAXLON} --service-id=${SERVICE_NAME} --product-id=${DAILY_PRODUCT_NAME} ${VAR_LIST} --out-name=${OUTFILE_NAME} --out-dir=${OUTPUT_DIR} --date-min=${T1} --date-max=${T2}

	    echo "[$APPNAME] ------ Manipulating file ${OUTFILE_NAME}"
	    ncrename -d latitude,lat -d longitude,log -v latitude,lat -v longitude,lon ${OUTPUT_DIR}/${OUTFILE_NAME}
	    
	else
	    echo "[$APPNAME] ------ File ${OUTFILE_NAME} already present"
	fi
       
    done

done
