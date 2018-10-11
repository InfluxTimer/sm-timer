#!/bin/bash


cd ./smx

SCRIPT_WILDCARD=influx_*
SCRIPT_PATH=../../addons/sourcemod/scripting

for i in $SCRIPT_PATH/$SCRIPT_WILDCARD.sp; do
	[ -f "$i" ] || break

	echo "Compiling $i..."
	spcomp "$i" -i"$SCRIPT_PATH/include" -v0		
done

