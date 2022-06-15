#!/bin/bash

################################################
#
# initial config
#
################################################

# set the app name
APPNAME="ECMWF_fcst"

# load config file
source ~/.bashrc

# paths
GRIB_FCST_DIR="/data/inputs/metocean/rolling/atmos/ECMWF/IFS_010/1.0forecast/1h/grib/"
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

# determine PRODDATE year, month and day
PRODYEAR=${PRODDATE:0:4}
PRODMONTH=${PRODDATE:4:2}
PRODDAY=${PRODDATE:6:2}

for D in $(seq 0 2); do
    
    REFDATE=$(date -d "$PRODDATE +${D}days" +"%Y%m%d")
    REFYEAR=${REFDATE:0:4}
    REFMONTH=${REFDATE:4:2}
    REFDAY=${REFDATE:6:2}
    JLS_FILES=$(ls ${GRIB_FCST_DIR}/${PRODDATE}/JLS${PRODMONTH}${PRODDAY}0000${REFMONTH}${REFDAY}*001 | wc -l)
    
    if [[ $D -eq 0 ]]; then        
        TEMP_PRODDATE=$(date -d "$PRODDATE -1days" +"%Y%m%d")
        TEMP_PRODYEAR=${TEMP_PRODDATE:0:4}
        TEMP_PRODMONTH=${TEMP_PRODDATE:4:2}
        TEMP_PRODDAY=${TEMP_PRODDATE:6:2}
        ANFILE0=${GRIB_FCST_DIR}/${TEMP_PRODDATE}/JLS${TEMP_PRODMONTH}${TEMP_PRODDAY}1200${TEMP_PRODMONTH}${TEMP_PRODDAY}23001
        ANFILE1=${GRIB_FCST_DIR}/${TEMP_PRODDATE}/JLS${TEMP_PRODMONTH}${TEMP_PRODDAY}1200${REFMONTH}${REFDAY}00001
        
        if [[ ! -e $ANFILE0 ]]; then
            echo "[$APPNAME][ERROR] === Missing input file $ANFILE0 !!!"
            exit 4
        fi

        if [[ ! -e $ANFILE1 ]]; then
            echo "[$APPNAME][ERROR] === Missing input file $ANFILE1 !!!"
            exit 4
        fi

        if [[ ! $JLS_FILES -eq 23 ]]; then
            echo "[$APPNAME][ERROR] === Missing input JLS files for day $REFDATE !!!"
            exit 4
        fi
        
    else
        if [[ ! $JLS_FILES -eq 24 ]]; then
            echo "[$APPNAME][ERROR] === Missing input JLS files for day $REFDATE !!!"
            exit 4          
        fi        
    fi
    
done


################################################
#
# Process forecasts
#
################################################

# determine PRODDATE year, month and day
PRODYEAR=${PRODDATE:0:4}
PRODMONTH=${PRODDATE:4:2}
PRODDAY=${PRODDATE:6:2}

for D in $(seq 0 2); do

    # determine REFDATE
    REFDATE=$(date -d "$PRODDATE +${D}days" +"%Y%m%d")
    REFYEAR=${REFDATE:0:4}
    REFMONTH=${REFDATE:4:2}
    REFDAY=${REFDATE:6:2}    
    echo "[$APPNAME][$REFDATE] === Processing day ${REFDATE}"

    # set workdir
    WDIR=${ECMWF_WORK_DIR}/${REFDATE}    
    rm -rf $WDIR
    mkdir -p $WDIR        
    
    # check if we are processing the first day
    if [[ $D = 0 ]]; then
        
        # PRODUCING TIMESTEP 0, then follow the rest of the procedure for the other timesteps
        echo "[$APPNAME][$REFDATE] ====== Producing timestep0 for day0"
        
        # 1 - get yesterday's forecast files in order to produce the first timestep
        TEMP_PRODDATE=$(date -d "$PRODDATE -1days" +"%Y%m%d")
        TEMP_PRODYEAR=${TEMP_PRODDATE:0:4}
        TEMP_PRODMONTH=${TEMP_PRODDATE:4:2}
        TEMP_PRODDAY=${TEMP_PRODDATE:6:2}
        ANFILE0=${GRIB_FCST_DIR}/${TEMP_PRODDATE}/JLS${TEMP_PRODMONTH}${TEMP_PRODDAY}1200${TEMP_PRODMONTH}${TEMP_PRODDAY}23001
        ANFILE1=${GRIB_FCST_DIR}/${TEMP_PRODDATE}/JLS${TEMP_PRODMONTH}${TEMP_PRODDAY}1200${REFMONTH}${REFDAY}00001

        # 2 - convert them to netcdf
        echo "[$APPNAME][$REFDATE] ========= Converting to NetCDF old forecast files"
        rm -f ${WDIR}/fc_${TEMP_PRODDATE}_23_CONVERTED.nc
        rm -f ${WDIR}/fc_${PRODDATE}_00_CONVERTED.nc
        cdo -r -f nc -t ecmwf copy $ANFILE0 ${WDIR}/fc_${TEMP_PRODDATE}_23_CONVERTED.nc
        cdo -r -f nc -t ecmwf copy $ANFILE1 ${WDIR}/fc_${PRODDATE}_00_CONVERTED.nc            

        # 3 - cut the on the area of interest
        echo "[$APPNAME][$REFDATE] ========= Cropping on the area of interest"
        rm -f ${WDIR}/fc_${TEMP_PRODDATE}_23_LSPCP.nc
        rm -f ${WDIR}/fc_${PRODDATE}_00_LSPCP.nc
        ncks -O -h -O -d lon,${REGION_MINLON},${REGION_MAXLON} -d lat,${REGION_MINLAT},${REGION_MAXLAT} -v time,lon,lat,LSP,CP ${WDIR}/fc_${TEMP_PRODDATE}_23_CONVERTED.nc ${WDIR}/fc_${TEMP_PRODDATE}_23_LSPCP.nc
        ncks -O -h -O -d lon,${REGION_MINLON},${REGION_MAXLON} -d lat,${REGION_MINLAT},${REGION_MAXLAT} -v time,lon,lat,LSP,CP ${WDIR}/fc_${PRODDATE}_00_CONVERTED.nc ${WDIR}/fc_${PRODDATE}_00_LSPCP.nc
        
        # 4 - create TP variable from both files
        echo "[$APPNAME][$REFDATE] ========= Creating TP variable"
        rm -f ${WDIR}/fc_${TEMP_PRODDATE}_23_TP.nc
        rm -f ${WDIR}/fc_${PRODDATE}_00_TP.nc
        ncap2 -s "precip=LSP+CP" ${WDIR}/fc_${TEMP_PRODDATE}_23_LSPCP.nc ${WDIR}/fc_${TEMP_PRODDATE}_23_TP.nc
        ncap2 -s "precip=LSP+CP" ${WDIR}/fc_${REFDATE}_00_LSPCP.nc ${WDIR}/fc_${REFDATE}_00_TP.nc        

        # 5 - calculate the difference of TP D1_00 - D0_23
        echo "[$APPNAME][$REFDATE] ========= Calculating the difference of TP"
        cdo sub ${WDIR}/fc_${REFDATE}_00_TP.nc ${WDIR}/fc_${TEMP_PRODDATE}_23_TP.nc ${WDIR}/fc_${REFDATE}_00_TP.nc

        # 6 - extract the other variables for timestep 0
        echo "[$APPNAME][$REFDATE] ========= Extract the other variables for TS 00"
        rm -f ${WDIR}/fc_${PRODDATE}_00_ALLNCVAR.nc
        ncks -O -h -O -d lon,${REGION_MINLON},${REGION_MAXLON} -d lat,${REGION_MINLAT},${REGION_MAXLAT} -v time,lon,lat,U10M,V10M,T2M,D2M,TCC,MSL ${WDIR}/fc_${PRODDATE}_00_CONVERTED.nc ${WDIR}/fc_${PRODDATE}_00_ALLNCVAR.nc

    fi    

    # build a list of file to process
    FILES_TO_PROCESS=$(ls ${GRIB_FCST_DIR}/${PRODDATE}/JLS${PRODMONTH}${PRODDAY}0000${REFMONTH}${REFDAY}*001)
    
    # convert grib to netcdf        
    for FILE in ${FILES_TO_PROCESS[*]}; do

        # get the basename and then the hour
        BFILE=$(basename $FILE)
        HOUR=${BFILE:15:2}
        echo "[$APPNAME][$REFDATE] ====== Processing hour $HOUR"
        
        # convert
        echo "[$APPNAME][$REFDATE] ====== Converting to NetCDF"
        rm -f ${WDIR}/fc_${REFDATE}_${HOUR}_CONVERTED.nc
        cdo -r -f nc -t ecmwf copy $FILE ${WDIR}/fc_${REFDATE}_${HOUR}_CONVERTED.nc

        # select only the desired variables and crop on the area of interest
        echo "[$APPNAME][$REFDATE] ====== Cropping on the area of interest"
        rm -f ${WDIR}/fc_${REFDATE}_${HOUR}_ALLNCVAR.nc
        ncks -O -h -O -d lon,${REGION_MINLON},${REGION_MAXLON} -d lat,${REGION_MINLAT},${REGION_MAXLAT} -v time,lon,lat,U10M,V10M,T2M,D2M,TCC,MSL ${WDIR}/fc_${REFDATE}_${HOUR}_CONVERTED.nc ${WDIR}/fc_${REFDATE}_${HOUR}_ALLNCVAR.nc

        # create a file with only TP
        echo "[$APPNAME][$REFDATE] ====== Calculating TP"
        rm -f ${WDIR}/fc_${REFDATE}_${HOUR}_LSPCP.nc
        rm -f ${WDIR}/fc_${REFDATE}_${HOUR}_TP.nc
        ncks -O -h -O -d lon,${REGION_MINLON},${REGION_MAXLON} -d lat,${REGION_MINLAT},${REGION_MAXLAT} -v time,lon,lat,LSP,CP ${WDIR}/fc_${REFDATE}_${HOUR}_CONVERTED.nc ${WDIR}/fc_${REFDATE}_${HOUR}_LSPCP.nc            
        ncap2 -s "precip=LSP+CP" ${WDIR}/fc_${REFDATE}_${HOUR}_LSPCP.nc ${WDIR}/fc_${REFDATE}_${HOUR}_TP.nc
        
    done
    
    # decumulate precip
    echo "[$APPNAME][$REFDATE] ====== Decumulating precipitation"
    for H in $(seq -w 0 23); do

        rm -f ${WDIR}/fc_${REFDATE}_${H}_TPinst.nc       
        if [[ $H = 00 ]]; then
            echo "here"
            cp ${WDIR}/fc_${REFDATE}_${H}_TP.nc ${WDIR}/fc_${REFDATE}_${H}_TPinst.nc
        else
            PREV_H=$(echo "$H - 1" | bc -l)
            PREV_H=$(printf "%02d" $H)
            cdo sub ${WDIR}/fc_${REFDATE}_${H}_TP.nc ${WDIR}/fc_${REFDATE}_${PREV_H}_TP.nc ${WDIR}/fc_${REFDATE}_${H}_TPinst.nc
        fi

        # merge 
        echo "[$APPNAME][$REFDATE] ========= Merging TP_inst with the other variables (timestep $H)"
        rm -f ${WDIR}/fc_${REFDATE}_${H}_MERGED.nc
        cdo merge ${WDIR}/fc_${REFDATE}_${H}_ALLNCVAR.nc ${WDIR}/fc_${REFDATE}_${H}_TPinst.nc ${WDIR}/fc_${REFDATE}_${H}_MERGED.nc

        # remove useless variables
        echo "[$APPNAME][$REFDATE] ========= Merging TP_inst with the other variables (timestep $H)"
        rm -f ${WDIR}/fc_${REFDATE}_${H}.nc
        ncks -x -v CP,LSP ${WDIR}/fc_${REFDATE}_${H}_MERGED.nc ${WDIR}/fc_${REFDATE}_${H}_CLEAN.nc
        
    done

    # merge 24 timesteps
    echo "[$APPNAME][$REFDATE] ====== Merging all the timesteps"    
    ncrcat ${WDIR}/fc_${REFDATE}_*_CLEAN.nc ${WDIR}/fc_${REFDATE}.nc

    # remove attributes
    echo "[$APPNAME][$REFDATE] ====== Cleaning attributes"    
    ncatted -O -a long_name,precip,m,c,"Total precipitation (instantaneous)" -a code,precip,d,,, -a table,precip,d,, -a history,global,d,, ${WDIR}/fc_${REFDATE}.nc

    # clean
    if [[ $CLEAN -eq 1 ]]; then
        rm ${WDIR}/*CLEAN.nc
        rm ${WDIR}/*MERGED.nc
        rm ${WDIR}/*TPinst.nc
        rm ${WDIR}/*TP.nc
        rm ${WDIR}/*LSPCP.nc
        rm ${WDIR}/*CONVERTED.nc
        rm ${WDIR}/*ALLNCVAR.nc            
    fi

    # move the final file
    mkdir -p ${ECMWF_FCST_OUTPUT_DIR}/
    mv ${WDIR}/fc_${REFDATE}.nc ${ECMWF_FCST_OUTPUT_DIR}/
    
done
