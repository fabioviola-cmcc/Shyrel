#!/bin/bash

################################################
#
# initial config
#
################################################

# set the app name
APPNAME="ECMWF_an"

# load config file
source ~/.bashrc

# paths
GRIB_FCST_DIR="/data/inputs/metocean/rolling/atmos/ECMWF/IFS_010/1.0forecast/6h/grib/"
GRIB_AN_DIR="/data/inputs/metocean/historical/model/atmos/ECMWF/IFS_010/analysis/6h/grib/"

# clean? 1 = True
CLEAN=1


################################################
#
# Read input params
#
################################################

# invoke getopt on the list of arguments $@
PARSED_OPTIONS=$(getopt -n "$0" -o h --long "help,day:,lat:,lon:,conf:" -- "$@")

# check if getopt went fine
if [ $? -ne 0 ];
then
    echo "[$APPNAME][ERROR] === Wrong arguments!"
    exit 1
fi

# now let's process getopt output
eval set -- "$PARSED_OPTIONS"
while true;
do
    case "$1" in
	    -h|--help)	    
	        echo "[$APPNAME] === Mandatory parameters:"
	        echo "[$APPNAME] === * --conf=<CONFIGFILE>"
	        echo "[$APPNAME] === Optional parameters:"
	        echo "[$APPNAME] === * --day=<YYYYMMDD>"
	        shift;;
	    --conf)
	        echo "[$APPNAME] === Config file set to $2"
	        CONFIGFILE=$2
	        shift 2;;
	    --day)
	        echo "[$APPNAME] === Date set to $2"
	        PRODDATE=$2
	        shift 2;;		
	    --)
	        shift
	        break;;
    esac
done


################################################
#
# Check/load the config file provided as input
#
################################################

if [[ -z $CONFIGFILE ]]; then
    echo "[$APPNAME][ERROR] === Configuration file not provided!"
    exit 2
else
    echo "[$APPNAME] === Loading config file $CONFIGFILE"
    source $(realpath $CONFIGFILE)

fi


################################################
#
# Check/set the date
#
################################################

if [[ -z $PRODDATE ]]; then
    PRODDATE=$(date "+%Y%m%d")
    echo "[$APPNAME] === Setting date to $PRODDATE"
else
    TODAY=$(date "+%Y%m%d")
    if [[ $PRODDATE -gt $TODAY ]]; then    
	    echo "[$APPNAME] === $PRODDATE cannot be in the future!"    
	    exit 3
    fi
fi


################################################
#
# Check input availability
#
################################################

for D in $(seq 1 3); do

    # determine REFDATE
    REFDATE=$(date -d "$PRODDATE -${D}days" +"%Y%m%d")
    REFYEAR=${REFDATE:0:4}
    REFMONTH=${REFDATE:4:2}
    REFDAY=${REFDATE:6:2}    

    # determine TEMP_REFDATE needed to calculate TP
    TEMP_REFDATE=$(date -d "$REFDATE -1days" +"%Y%m%d")
    TEMP_REFYEAR=${TEMP_REFDATE:0:4}
    TEMP_REFMONTH=${TEMP_REFDATE:4:2}
    TEMP_REFDAY=${TEMP_REFDATE:6:2}

    
    # Build the list of file to process
    FILE_TO_PROCESS=()
    FILE_TO_PROCESS+=($GRIB_FCST_DIR/$TEMP_REFDATE/JLS${TEMP_REFMONTH}${TEMP_REFDAY}1200${TEMP_REFMONTH}${TEMP_REFDAY}18001)
    FILE_TO_PROCESS+=($GRIB_FCST_DIR/$TEMP_REFDATE/JLS${TEMP_REFMONTH}${TEMP_REFDAY}1200${REFMONTH}${REFDAY}00001) 
    FILE_TO_PROCESS+=($GRIB_FCST_DIR/$REFDATE/JLS${REFMONTH}${REFDAY}0000${REFMONTH}${REFDAY}06001)
    FILE_TO_PROCESS+=($GRIB_FCST_DIR/$REFDATE/JLS${REFMONTH}${REFDAY}0000${REFMONTH}${REFDAY}12001)
    FILE_TO_PROCESS+=($GRIB_FCST_DIR/$REFDATE/JLS${REFMONTH}${REFDAY}1200${REFMONTH}${REFDAY}18001)
    for FILE in $(ls $GRIB_AN_DIR/$REFYEAR/$REFMONTH/JLD${REFMONTH}${REFDAY}*${REFMONTH}${REFDAY}*001); do
        FILES_TO_PROCESS+=($FILE)
    done

    for FILE in ${FILE_TO_PROCESS[*]}; do
        if [[ ! -e $FILE ]]; then
            echo "[$APPNAME] === ERROR! Missing input file $FILE"
            exit 4
        fi
    done
    
done


################################################
#
# Process analysis
#
################################################

# determine PRODDATE year, month and day
PRODYEAR=${PRODDATE:0:4}
PRODMONTH=${PRODDATE:4:2}
PRODDAY=${PRODDATE:6:2}

for D in $(seq 1 3); do

    # determine REFDATE
    REFDATE=$(date -d "$PRODDATE -${D}days" +"%Y%m%d")
    REFYEAR=${REFDATE:0:4}
    REFMONTH=${REFDATE:4:2}
    REFDAY=${REFDATE:6:2}    
    echo "[$APPNAME][$REFDATE] === Processing day ${REFDATE}"

    # set workdir
    WDIR=${ECMWF_WORK_DIR}/${REFDATE}    
    rm -rf $WDIR
    mkdir -p $WDIR

    # determine TEMP_REFDATE needed to calculate TP
    TEMP_REFDATE=$(date -d "$REFDATE -1days" +"%Y%m%d")
    TEMP_REFYEAR=${TEMP_REFDATE:0:4}
    TEMP_REFMONTH=${TEMP_REFDATE:4:2}
    TEMP_REFDAY=${TEMP_REFDATE:6:2}

    ################################################
    #
    # Calculate TPinst
    #
    ################################################

    # Build the list of file to process
    FILE_TO_PROCESS=()
    FILE_TO_PROCESS+=($GRIB_FCST_DIR/$TEMP_REFDATE/JLS${TEMP_REFMONTH}${TEMP_REFDAY}1200${TEMP_REFMONTH}${TEMP_REFDAY}18001)
    FILE_TO_PROCESS+=($GRIB_FCST_DIR/$TEMP_REFDATE/JLS${TEMP_REFMONTH}${TEMP_REFDAY}1200${REFMONTH}${REFDAY}00001) 
    FILE_TO_PROCESS+=($GRIB_FCST_DIR/$REFDATE/JLS${REFMONTH}${REFDAY}0000${REFMONTH}${REFDAY}06001)
    FILE_TO_PROCESS+=($GRIB_FCST_DIR/$REFDATE/JLS${REFMONTH}${REFDAY}0000${REFMONTH}${REFDAY}12001)
    FILE_TO_PROCESS+=($GRIB_FCST_DIR/$REFDATE/JLS${REFMONTH}${REFDAY}1200${REFMONTH}${REFDAY}18001)

    COUNTER=0
    PREV_TP_FILE=""
    for FILE in ${FILE_TO_PROCESS[*]}; do

        # get the basename and then the hour
        BFILE=$(basename $FILE)
        HOUR=${BFILE:15:2}

        # convert to NetCDF
        echo "[$APPNAME][$REFDATE] ========= Converting to NetCDF"
        cdo -r -f nc -t ecmwf copy $FILE ${WDIR}/an_${REFDATE}_${HOUR}_CONVERTED.nc
        
        # extract the variables CP,LSP and crop on the area of interest
        echo "[$APPNAME][$REFDATE] ========= Cropping on the area of interest"
        rm -f ${WDIR}/an_${REFDATE}_${HOUR}_LSPCP.nc
        ncks -O -h -O -d lon,${REGION_MINLON},${REGION_MAXLON} -d lat,${REGION_MINLAT},${REGION_MAXLAT} -v time,lon,lat,LSP,CP ${WDIR}/an_${REFDATE}_${HOUR}_CONVERTED.nc ${WDIR}/an_${REFDATE}_${HOUR}_LSPCP.nc
        
        # generate the variable TP
        echo "[$APPNAME][$REFDATE] ====== Calculating TP"
        rm -f ${WDIR}/an_${REFDATE}_${HOUR}_TP.nc
        ncap2 -s "precip=LSP+CP" ${WDIR}/an_${REFDATE}_${HOUR}_LSPCP.nc ${WDIR}/an_${REFDATE}_${HOUR}_TP.nc

        # calculate TP_inst
        if [[ $COUNTER -gt 0 ]]; then

            # make the difference with previous TP file
            cdo sub ${WDIR}/an_${REFDATE}_${HOUR}_TP.nc $PREV_TP_FILE ${WDIR}/an_${REFDATE}_${HOUR}_TPinst.nc
            
        fi
        
        # increment the counter and store the TP file
        COUNTER=$(echo "$COUNTER + 1" | bc -l)
        PREV_TP_FILE=${WDIR}/an_${REFDATE}_${HOUR}_TP.nc
        
    done

    ################################################
    #
    # Take other variables
    #
    ################################################

    # build the list of files to process
    FILES_TO_PROCESS=()
    for FILE in $(ls $GRIB_AN_DIR/$REFYEAR/$REFMONTH/JLD${REFMONTH}${REFDAY}*${REFMONTH}${REFDAY}*001); do
        FILES_TO_PROCESS+=($FILE)
    done

    # process them!
    for FILE in ${FILES_TO_PROCESS[*]}; do

        # get the basename and then the hour
        BFILE=$(basename $FILE)
        HOUR=${BFILE:15:2}
        
        # convert to netcdf
        echo "[$APPNAME][$REFDATE] ========= Converting to NetCDF"
        rm -f ${WDIR}/an_${REFDATE}_${HOUR}_CONVERTED.nc
        cdo -r -f nc -t ecmwf copy $FILE ${WDIR}/an_${REFDATE}_${HOUR}_CONVERTED.nc            

        # cut the on the area of interest
        echo "[$APPNAME][$REFDATE] ========= Cropping on the area of interest"
        rm -f ${WDIR}/an_${REFDATE}_${HOUR}_ALLNCVAR.nc
        ncks -O -h -O -d lon,${REGION_MINLON},${REGION_MAXLON} -d lat,${REGION_MINLAT},${REGION_MAXLAT} -v time,lon,lat,U10M,V10M,T2M,D2M,TCC,MSL ${WDIR}/an_${REFDATE}_${HOUR}_CONVERTED.nc ${WDIR}/an_${REFDATE}_${HOUR}_ALLNCVAR.nc      

        # Merge TPinst with the other variables
        echo "[$APPNAME][$REFDATE] ========= Merging TPinst with other variables"
        cdo merge ${WDIR}/an_${REFDATE}_${HOUR}_ALLNCVAR.nc ${WDIR}/an_${REFDATE}_${HOUR}_TPinst.nc ${WDIR}/an_${REFDATE}_${HOUR}_MERGED.nc      
               
    done

    # merge files
    rm -f ${WDIR}/an_${REFDATE}_MERGED.nc
    ncrcat ${WDIR}/an_${REFDATE}_*_MERGED.nc ${WDIR}/an_${REFDATE}_MERGED.nc

    # Remove useless variables
    echo "[$APPNAME][$REFDATE] ========= Removing useless variables"
    rm -f ${WDIR}/an_${REFDATE}.nc
    ncks -x -v CP,LSP ${WDIR}/an_${REFDATE}_MERGED.nc ${WDIR}/an_${REFDATE}.nc
    
    # Clean attributes
    echo "[$APPNAME][$REFDATE] ====== Cleaning attributes"
    ncatted -O -a long_name,precip,m,c,"Total precipitation (instantaneous)" -a code,precip,d,,, -a table,precip,d,, -a history,global,d,, ${WDIR}/an_${REFDATE}.nc              
        
    # clean
    if [[ $CLEAN -eq 1 ]]; then
        rm ${WDIR}/*MERGED.nc
        rm ${WDIR}/*TPinst.nc
        rm ${WDIR}/*TP.nc
        rm ${WDIR}/*LSPCP.nc
        rm ${WDIR}/*CONVERTED.nc
        rm ${WDIR}/*ALLNCVAR.nc            
    fi

done
