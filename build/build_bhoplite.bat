@ECHO OFF

:: Light version, targeted for LAN usage
CD %~dp0
main.bat bhoplite .\config\exclude_list_bhoplite.txt .\add_bhop\*
