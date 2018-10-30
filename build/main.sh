#!/bin/bash

OUTPUT_PREFIX=influx_v1_3
OUTPUT_PREFIX2=$(<version)

OUTPUT_FILENAME=output/$OUTPUT_PREFIX$OUTPUT_PREFIX2'_'$1.zip



MY_PATH=$(dirname $(readlink -f "$0"))


# Build the exclude lists
EXCLUDE_ARGS=-x"@$MY_PATH/config/exclude_list_all.txt"
if [ ! -z "$3" ] ; then
	TEMP=-x"@$MY_PATH/$3"
	EXCLUDE_ARGS="$EXCLUDE_ARGS $TEMP" 
fi


cd $MY_PATH

# Move the plugins
cp -p ./smx/*.smx ../addons/sourcemod/plugins

cd ..
zip -rq "build/$OUTPUT_FILENAME" * $EXCLUDE_ARGS


cd ./build/add_all
zip -rq "../$OUTPUT_FILENAME" * $EXCLUDE_ARGS

cd ..

# Add any additional files
if [ ! -z "$2" ] ; then
	cd $2
	zip -rq "$MY_PATH/$OUTPUT_FILENAME" * $EXCLUDE_ARGS
fi


cd $MY_PATH

# We no longer need the plugins, they're archived.
rm ../addons/sourcemod/plugins/*.smx


