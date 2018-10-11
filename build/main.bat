@ECHO OFF
:: DON'T EXECUTE ME DIRECTLY

SET OUTPUT_PREFIX="influx_v1_3"


:: Archive them
SET OUTPUT_DIR=output

SET OUTPUT_STR="%OUTPUT_DIR%\%OUTPUT_PREFIX%_%1.zip"

SET SCRIPT_OUTPUT=..\addons\sourcemod\plugins



COPY ".\smx\*.smx" "%SCRIPT_OUTPUT%"


SET ZIP_EXECUTE=7z a -tzip %OUTPUT_STR% -x@.\config\exclude_list_all.txt -x@%2

%ZIP_EXECUTE% ..\
%ZIP_EXECUTE% .\add_all\*
%ZIP_EXECUTE% .\*.smx
IF NOT [%3]==[] (
	%ZIP_EXECUTE% %3
)


:: Delete all the plugin files, they are now archived.
DEL %SCRIPT_OUTPUT%\*.smx
