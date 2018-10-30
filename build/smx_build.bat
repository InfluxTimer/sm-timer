:: Compile plugins
@ECHO OFF


CD %~dp0\smx


:: IMPORTANT: The spcomp directory has to have the default SourceMod includes!!!!
SET SCRIPT_WILDCARD=influx_*
SET SCRIPT_PATH=..\..\addons\sourcemod\scripting


FOR %%g IN ("%SCRIPT_PATH%\%SCRIPT_WILDCARD%.sp") DO (
	ECHO Compiling %%~ng.sp
	spcomp.exe "%%g" -i"%SCRIPT_PATH%\include" -v0
)
