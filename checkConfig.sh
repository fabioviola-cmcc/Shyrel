#!/bin/bash

function checkConfig() {

    CONFIGFILE=$1
    source $CONFIGFILE

    ##################################################
    #
    # Check the bounding box
    #
    ##################################################
    
    if [[ -z $REGION_MINLAT ]]; then
	echo "[$APPNAME][ERROR] -- Minimum latitude not set"
	return 1
    fi

    if [[ -z $REGION_MINLON ]]; then
	echo "[$APPNAME][ERROR] -- Minimum longitude not set"
	return 1
    fi

    if [[ -z $REGION_MAXLAT ]]; then
	echo "[$APPNAME][ERROR] -- Maximum latitude not set"
	return 1
    fi

    if [[ -z $REGION_MAXLON ]]; then
	echo "[$APPNAME][ERROR] -- Maximum longitude not set"
	return 1
    fi

    if [[ $(echo "$REGION_MINLAT < -90" | bc -l) -eq 1 ]]; then
	echo "[$APPNAME][ERROR] -- Minimum latitude can't be less than -90"
	return 1
    fi

    if [[ $(echo "$REGION_MINLON < -180" | bc -l) -eq 1 ]]; then
	echo "[$APPNAME][ERROR] -- Minimum longitude can't be less than -180"
	return 1
    fi

    if [[ $(echo "$REGION_MAXLAT > 90" | bc -l) -eq 1 ]]; then
	echo "[$APPNAME][ERROR] -- Maximum latitude can't be greater than 90"
	return 1
    fi

    if [[ $(echo "$REGION_MAXLON > 180" | bc -l) -eq 1 ]]; then
	echo "[$APPNAME][ERROR] -- Maximum longitude can't be greater than 180"
	return 1
    fi

    if [[ $(echo "$REGION_MINLAT >= $REGION_MAXLAT" | bc -l) -eq 1 ]]; then
	echo "[$APPNAME][ERROR] -- Maximum latitude is not greater than the minimum"
	return 1
    fi

    if [[ $(echo "$REGION_MINLON >= $REGION_MAXLON" | bc -l) -eq 1 ]]; then
	echo "[$APPNAME][ERROR] -- Maximum longitude is not greater than the minimum"
	return 1
    fi

    return 0
    
}
