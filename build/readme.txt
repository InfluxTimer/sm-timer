------------
Requirements:
	spcomp.exe (scripting folder WITH ALL stock SM includes) in PATH
	7-Zip (also added to PATH)
------------


------------
Steps:
	1. Run smx_build
		You only have to do this step once (run again after updating plugin code).
		All plugin files (smx) will go into the smx-directory.
		
	2. Run the script you want to build (build_*.bat)
		build_bhop			- Targets bhop
		build_bhoplite		- Builds a light bhop version meant for LAN usage. (strips all fancy rankings, etc.)
		build_full			- Doesn't exclude anything
		build_surf			- Targets surf (Sets default mode to scroll, prespeed changes, etc.)
		
	2. The ZIP archive is now in output-directory
------------


------------
NOTE:
	Exclude lists are recursive, but exclude_list_all is not!!
------------
