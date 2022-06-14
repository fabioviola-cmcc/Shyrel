#!/bin/bash

##################################################
#
# initial config
#
##################################################

# set the app name
APPNAME="ECMWF"

# load config file
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
    pwd
    realpath $CONFIGFILE
    source $(realpath $CONFIGFILE)

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
# Set paths
#
##################################################

YEAR=${DATE:0:4}
MONTH=${DATE:4:2}

# paths
WORK_DIR="./workdir"
GRIB_FCST_BASE_DIR="/data/inputs/metocean/rolling/atmos/ECMWF/IFS_010/1.0forecast/1h/grib/"
GRIB_AN_BASE_DIR="/data/inputs/metocean/historical/model/atmos/ECMWF/IFS_010/analysis/6h/grib/"

GRIB_FCST_DIR="/data/inputs/metocean/rolling/atmos/ECMWF/IFS_010/1.0forecast/1h/grib/${DATE}"
GRIB_AN_DIR="/data/inputs/metocean/historical/model/atmos/ECMWF/IFS_010/analysis/6h/grib/${YEAR}/${MONTH}"


##################################################
#
# Process analysis files
#
##################################################

# Take three days back
for D in $(seq 1 3); do

    # Determining the date
    DAY_PATTERN1=$(date -d "$DATE -${D}days" +"%m%d")
    DAY_PATTERN2=$(date -d "$DATE -${D}days" +"%Y%m%d")
    DAY_PATTERN3=$(date -d "$DATE -${D}days" +"%Y/%m")
    DAY_PATTERN4=$(date -d "$DATE -${D}days" +"%Y-%m-%d")
    DD=$(echo "$D - 1" | bc -l)
    DAY_PATTERN_TOM1=$(date -d "$DATE -${DD}days" +"%m%d")
    DAY_PATTERN_TOM2=$(date -d "$DATE -${DD}days" +"%Y%m%d")
    DAY_PATTERN_TOM3=$(date -d "$DATE -${DD}days" +"%Y/%m")
    echo "[$APPNAME] -- Processing analysis for date $DAY_PATTERN1"

    # Build the list of files to process
    FILES_TO_PROCESS=()
    for FILE in $(ls ${GRIB_AN_BASE_DIR}/${DAY_PATTERN3}/JLD*${DAY_PATTERN1}*00${DAY_PATTERN1}*001); do
        FILES_TO_PROCESS+=($FILE)
    done
    FILES_TO_PROCESS+=(${GRIB_AN_BASE_DIR}/${DAY_PATTERN_TOM3}/JLD${DAY_PATTERN_TOM1}0000${DAY_PATTERN_TOM1}00001)
    
    # Processing
    for FILE in ${FILES_TO_PROCESS[*]}; do
        
        BASENAME_FILE=$(basename $FILE)
        
        # Get the hour
        HOUR=${BASENAME_FILE:15:2}
        DAY=${BASENAME_FILE:11:4}
        echo "[$APPNAME] -- -- $BASENAME_FILE -- Timestep $HOUR -- $DAY"        

        # Determining the output filename
        OUTPUT_FILE="step1_ECMWF_an_${DAY}_${HOUR}_noprecip.nc"
        
        # Convert the file to netcdf
        if [[ -e $WORK_DIR/step0_$OUTPUT_FILE ]]; then
           rm $WORK_DIR/step0_$OUTPUT_FILE
        fi
        cdo -r -f nc -t ecmwf copy $FILE $WORK_DIR/step0_$OUTPUT_FILE

        # select only the desired variables and crop on the area of interest
        if [[ -e $WORK_DIR/$OUTPUT_FILE ]]; then
            rm $WORK_DIR/$OUTPUT_FILE
        fi     
        ncks -O -h -O -d lon,${REGION_MINLON},${REGION_MAXLON} -d lat,${REGION_MINLAT},${REGION_MAXLAT} -v time,lon,lat,U10M,V10M,T2M,D2M,TCC,MSL ${WORK_DIR}/step0_${OUTPUT_FILE} ${WORK_DIR}/${OUTPUT_FILE}

        # clear the step0 files
        rm $WORK_DIR/step0_$OUTPUT_FILE        
        
    done

    # merge files
    echo "[$APPNAME] -- Merging files for day ${DAY_PATTERN1}"
    if [[ -e ${WORK_DIR}/step2_ECMWF_an_${DAY_PATTERN1}_noprecip.nc ]]; then
        rm ${WORK_DIR}/step2_ECMWF_an_${DAY_PATTERN1}_noprecip.nc
    fi    
    ncrcat ${WORK_DIR}/step1_ECMWF_an_${DAY_PATTERN1}_*_noprecip.nc ${WORK_DIR}/step1_ECMWF_an_${DAY_PATTERN_TOM1}_00_noprecip.nc ${WORK_DIR}/step2_ECMWF_an_${DAY_PATTERN1}_noprecip.nc

    # clean
    rm ${WORK_DIR}/step1_ECMWF_an_${DAY_PATTERN1}_*_noprecip.nc
    rm ${WORK_DIR}/step1_ECMWF_an_${DAY_PATTERN_TOM1}_00_noprecip.nc

    # temporal interpolation
    if [[ -e ${WORK_DIR}/step3_ECMWF_an_${DAY_PATTERN1}_noprecip.nc ]]; then
        rm ${WORK_DIR}/step3_ECMWF_an_${DAY_PATTERN1}_noprecip.nc
    fi        
    cdo -inttime,${DAY_PATTERN4},00:00,1hour ${WORK_DIR}/step2_ECMWF_an_${DAY_PATTERN1}_noprecip.nc ${WORK_DIR}/step3_ECMWF_an_${DAY_PATTERN1}_noprecip.nc
    rm ${WORK_DIR}/step2_ECMWF_an_${DAY_PATTERN1}_noprecip.nc
    
    # remove last timestep
    if [[ -e ${WORK_DIR}/step4_ECMWF_an_${DAY_PATTERN1}_noprecip.nc ]]; then
        rm ${WORK_DIR}/step4_ECMWF_an_${DAY_PATTERN1}_noprecip.nc
    fi        
    ncks -O -d time,0,23 ${WORK_DIR}/step3_ECMWF_an_${DAY_PATTERN1}_noprecip.nc ${WORK_DIR}/step4_ECMWF_an_${DAY_PATTERN1}_noprecip.nc
    rm ${WORK_DIR}/step3_ECMWF_an_${DAY_PATTERN1}_noprecip.nc
    
done


##################################################
#
# Process forecast files for analysis days in
# order to get the precipitation to be added to
# the real analysis files
#
##################################################

# Take three days back
for D in $(seq 1 3); do

    FILES_TO_PROCESS=()
    
    # Determining the date
    DAY_PATTERN1=$(date -d "$DATE -${D}days" +"%m%d")
    DAY_PATTERN2=$(date -d "$DATE -${D}days" +"%Y%m%d")
    DD=$(echo "$D + 1" | bc -l)
    DAY_PATTERN_YEST1=$(date -d "$DATE -${DD}days" +"%m%d")
    DAY_PATTERN_YEST2=$(date -d "$DATE -${DD}days" +"%Y%m%d")
    echo "[$APPNAME] -- Processing analysis for date $DAY_PATTERN2"

    # Determining the fcst temp path
    GRIB_ANFCST_DIR1="/data/inputs/metocean/rolling/atmos/ECMWF/IFS_010/1.0forecast/1h/grib/${DAY_PATTERN2}"
    GRIB_ANFCST_DIR2="/data/inputs/metocean/rolling/atmos/ECMWF/IFS_010/1.0forecast/1h/grib/${DAY_PATTERN_YEST2}"

    # Build the list of files to process
    for FILE in $(ls ${GRIB_ANFCST_DIR1}/JLS${DAY_PATTERN1}0000${DAY_PATTERN1}*001); do
        FILES_TO_PROCESS+=($FILE)
    done
    FILES_TO_PROCESS+=($GRIB_ANFCST_DIR2/JLS${DAY_PATTERN_YEST1}0000${DAY_PATTERN1}00001)
        
    # Processing
    for FILE in ${FILES_TO_PROCESS[*]}; do

        # get the basename
        BASENAME_FILE=$(basename $FILE)
        
        # Get the hour
        HOUR=${BASENAME_FILE:15:2}
        echo "[$APPNAME] -- -- $BASENAME_FILE -- Timestep $HOUR"        

        # Determining the output filename
        OUTPUT_FILE="step1_ECMWF_an_${DAY_PATTERN1}_${HOUR}_precip.nc"
        
        # Convert the file to netcdf
        if [[ -e $WORK_DIR/step0_$OUTPUT_FILE ]]; then
           rm $WORK_DIR/step0_$OUTPUT_FILE
        fi
        cdo -r -f nc -t ecmwf copy $FILE $WORK_DIR/step0_$OUTPUT_FILE

        # select only the desired variables and crop on the area of interest
        if [[ -e $WORK_DIR/$OUTPUT_FILE ]]; then
            rm $WORK_DIR/$OUTPUT_FILE
        fi     
        ncks -O -h -O -d lon,${REGION_MINLON},${REGION_MAXLON} -d lat,${REGION_MINLAT},${REGION_MAXLAT} -v time,lon,lat,CP ${WORK_DIR}/step0_${OUTPUT_FILE} ${WORK_DIR}/${OUTPUT_FILE}

        # clear the step0 files
        rm $WORK_DIR/step0_$OUTPUT_FILE
                
    done

    # merge files
    echo "[$APPNAME] -- Merging files for day ${DAY_PATTERN1}"
    if [[ -e ${WORK_DIR}/step2_ECMWF_an_${DAY_PATTERN1}_precip.nc ]]; then
        rm ${WORK_DIR}/step2_ECMWF_an_${DAY_PATTERN1}_precip.nc
    fi
    ncrcat ${WORK_DIR}/step1_ECMWF_an_${DAY_PATTERN1}_*_precip.nc ${WORK_DIR}/step2_ECMWF_an_${DAY_PATTERN1}_precip.nc

    # clean
    rm ${WORK_DIR}/step1_ECMWF_an_${DAY_PATTERN1}_*_precip.nc
    
done


##################################################
#
# Merge precip and noprecip files
#
##################################################

# Take three days back
for D in $(seq 1 3); do

    # Determining the date
    DAY_PATTERN1=$(date -d "$DATE -${D}days" +"%m%d")
    DAY_PATTERN2=$(date -d "$DATE -${D}days" +"%Y%m%d")
    echo "[$APPNAME] -- Processing analysis for date $DAY_PATTERN2"

    # Merge
    if [[ -e ${WORK_DIR}/ECMWF_an_${DAY_PATTERN1}.nc ]]; then
        rm ${WORK_DIR}/ECMWF_an_${DAY_PATTERN1}.nc
    fi
    cdo merge ${WORK_DIR}/step2_ECMWF_an_${DAY_PATTERN1}_precip.nc ${WORK_DIR}/step4_ECMWF_an_${DAY_PATTERN1}_noprecip.nc ${WORK_DIR}/ECMWF_an_${DAY_PATTERN1}.nc
    rm ${WORK_DIR}/step2_ECMWF_an_${DAY_PATTERN1}_precip.nc ${WORK_DIR}/step4_ECMWF_an_${DAY_PATTERN1}_noprecip.nc
    
done

##################################################
#
# Process forecast files
#
##################################################

# Take two days forward
for D in $(seq 0 2); do
    
    # Determining the date
    DAY_PATTERN1=$(date -d "$DATE +${D}days" +"%m%d")
    DAY_PATTERN2=$(date -d "$DATE +${D}days" +"%Y%m%d")
    DD=$(echo "$D - 1" | bc -l)
    DAY_PATTERN_YEST1=$(date -d "$DATE +${DD}days" +"%m%d")
    DAY_PATTERN_YEST2=$(date -d "$DATE +${DD}days" +"%Y%m%d")
    echo "[$APPNAME] -- Processing forecast for date $DAY_PATTERN1"

    FILES_TO_PROCESS=()
    
    # Build the list of files to process
    for FILE in $(ls ${GRIB_FCST_DIR}/JLS*00${DAY_PATTERN1}*001); do
        FILES_TO_PROCESS+=($FILE)
    done
    if [[ $D = 0 ]] ;then        
        FILES_TO_PROCESS+=(${GRIB_FCST_BASE_DIR}/${DAY_PATTERN_YEST2}/JLS${DAY_PATTERN_YEST1}0000${DAY_PATTERN1}00001)
    fi

    # Processing
    for FILE in ${FILES_TO_PROCESS[*]}; do

        # Get the basename
        BASENAME_FILE=$(basename $FILE)
        
        # Get the hour
        HOUR=${BASENAME_FILE:15:2}
        DAY=${BASENAME_FILE:11:4}
        echo "[$APPNAME] -- -- $BASENAME_FILE -- Timestep $HOUR"        

        # Determining the output filename
        OUTPUT_FILE="fc_${DAY}_${HOUR}.nc"

        # - convert them to netcdf
        if [[ -e $WORK_DIR/step0_$OUTPUT_FILE ]]; then
            rm $WORK_DIR/step0_$OUTPUT_FILE
        fi
        cdo -r -f nc -t ecmwf copy $FILE $WORK_DIR/step0_$OUTPUT_FILE
        
        # select only the desired variables and crop on the area of interest
        if [[ -e $WORK_DIR/$OUTPUT_FILE ]]; then
            rm $WORK_DIR/$OUTPUT_FILE
        fi
        ncks -O -h -O -d lon,${REGION_MINLON},${REGION_MAXLON} -d lat,${REGION_MINLAT},${REGION_MAXLAT} -v time,lon,lat,U10M,V10M,T2M,D2M,TCC,MSL,CP ${WORK_DIR}/step0_${OUTPUT_FILE} ${WORK_DIR}/step1_${OUTPUT_FILE}
        
        # remove previous file
        rm $WORK_DIR/step0_${OUTPUT_FILE}        
        
    done

    # merge
    if [[ -e ${WORK_DIR}/ECMWF_fc_${DAY_PATTERN1}.nc ]]; then
        rm ${WORK_DIR}/ECMWF_fc_${DAY_PATTERN1}.nc
    fi
    ncrcat ${WORK_DIR}/step1_fc_${DAY_PATTERN1}_*.nc ${WORK_DIR}/ECMWF_fc_${DAY_PATTERN1}.nc 
    rm ${WORK_DIR}/step1_fc_${DAY_PATTERN1}_*.nc
    
done

