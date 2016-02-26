#!/bin/bash
###
# Script to extract Installer packages from the Apple AppStore for OS X
#
# This script was tested under OS X Mountain Lion v10.8.5 and OS X Mavericks 10.9.x
#
# Based on an idea from Rich Trouton for downloading from the AppStore:
# http://derflounder.wordpress.com/2013/10/19/downloading-microsofts-remote-desktop-installer-package-from-the-app-store/
###
# Edited and extended for internal use at ETH Zurich
# by Katiuscia Zehnder, Jan Hacker and Max Schlapfer
###


###
# Short documentation
# - This script needs the temporary download folder from the AppStore App, this is individual by host
#   and is extracted by "getconf DARWIN_USER_CACHE_DIR"
#   If you want to access the debug mode of the AppStore:
#	- Quit the AppStore.app if it is running
#   	- open the terminal and enter "defaults write com.apple.appstore ShowDebugMenu -bool true"
#   	- Start AppStore.app and browse the menu Debug
# - The folder /Users/Shared/AppStore_Packages is generated and used as the packages output folder
# - open Terminal and start this script (if needed make it executable first), keep the window open.
#   if the output wil be used with munikimport add the option "-m" to make the naming munki-friendly
# - Back in the AppStore.app login in to your account and navigate to your purchases
#   - Click "Install" for all desired packages
#   - wait till every download/installation has finished
# - go back to the terminal and continue the script by pressing any key to stop processing downloads
# - answer the following question with yes to finalize and clean up the downloaded packages
###

function ifError () {
	# check return code passed to function
	exitStatus=$?
	if [[ $exitStatus -ne 0 ]]; then
	# if rc > 0 then print error msg and quit
	echo -e "$0 Time:$TIME $1 Exit: $exitStatus"
	exit $exitStatus
	fi
}

###
# Definition of the local temporary AppStore folder
###
AppStoreRoot="$(getconf DARWIN_USER_CACHE_DIR)com.apple.appstore"

###
# Definition of the local output folder where the extracted packages are stored on your machine
###
Destination="./downloading/"
Completed="./completed/"
Outdated="./outdated/"

mkdir -p "$Destination"
mkdir -p "$Completed"
mkdir -p "$Outdated"

# Plist we track apps to download and current versions in:
appsPlist="AutoAppStore.plist"
# Update appsPlist with:
# PlistBuddy -c "Set appIDs 123456789 123456789 123456789 123456789"
# wehre each 123456789 is a different App ID

# let the user force a download of all apps
forceInstall="$1"

# Let users switch to munki naming convention by using -m as first argument to this script
separator="_"
if [ "$1" = "-m" ]; then
 separator="-"
fi

# Make sure we can find PlistBuddy
PlistBuddy="/usr/libexec/PlistBuddy"
if [[ -e "$PlistBuddy" ]] ; then
	PBUDDY="$PlistBuddy"
else
	echo "Can't find PlistBuddy. Aborting configuration script."
	exit
fi

# Check that we're logged into MAS
mas="/usr/local/bin/mas"
if [[ -e "$mas" ]]; then
	currMASUser=$($mas account)
	if [[ "$currMASUser" == "Not signed in" ]]; then
		echo "No MAS user logged in. Please log in before running this script"
		exit 1
		# Sign in for user?
		# mas signin rzm102@psu.edu Password123
	fi
fi


unset AppStoreIDs

if [[ ! -e "$appsPlist" ]]; then
	echo "   ERROR: Could not find plist with App IDs!"
	echo "   Please create a $appsPlist to store the"
	echo "   App Store App IDs you wish to download."
	echo "   Example:"
	echo "   803453959 = Slack"
	echo "   425424353 = The Unarchiver"
	echo "   /usr/libexec/PlistBuddy -c \"Set appIDs 425424353 803453959\" ./$appsPlist"
	exit 1
fi

for id in $($PBUDDY -c "Print appIDs" "$appsPlist"); do 
	if [[ $id =~ [0-9] ]]; then 
		AppStoreIDs=("$id" "${AppStoreIDs[@]}")
	fi
done

# warn about running the first time
if [ ! "$(ls -A "$Completed" | grep -v ".DS_Store")" ]; then
	echo "################################################"
	echo "The completed directory is empty"
	echo "I suspect you've never run this script before"
	echo "If you wish to force an install of all apps,"
	echo "rather than just the ones out of date"
	echo "Then run this script with the parameter: force"
	echo "Example: $0 force"
	echo "################################################"
	
fi

echo "Processing ${#AppStoreIDs[@]} apps..."

# get outdated apps from mas
outdatedApps=$($mas outdated)

# outdatedApps="497799835 Xcode (7.0)
# 446107677 Screens VNC - Access Your Computer From Anywhere (3.6.7)
# 425424353 The Unarchiver (3.3.3)
# 803453959 Slack (2.0)
# 715768417 Something"

function capturePkgs () {
	echo "   ->Watching for Pkgs"
	# Run background process to link package
	while true; do 
		# echo "   ->yes"
		find "$AppStoreRoot" -name \*.pkg  | xargs -I {} sh -c 'ln "$1" "$2$(basename $1)" 2> /dev/null ; cp -n "$3/manifest.plist" "$2$(basename $1).plist" ' - {} "$Destination" "$AppStoreRoot"
	done & 
	# capture PID to kill watch later
	currentPID=$!
	# echo "Current PID=$currentPID"
	watchPID="$currentPID"
}

for appId in "${AppStoreIDs[@]}"; do

	currAppName=$($PBUDDY -c "Print $appId" "$appsPlist" 2>/dev/null)
	echo "##################################################"
	if [[ -z $currAppName ]]; then
		
		echo "Checking $appId = unkown"
		currAppName="unkown"
	else
		echo "Checking $appId $currAppName"
	fi

	outdatedApp=false
	for outdated in $(echo "$outdatedApps" | awk '{print $1}'); do
		appName=$(echo "$outdatedApps" | grep "$outdated" | cut -c 11-)
		if [[ $appId =~ "$outdated" ]]; then
			outdatedApp=true
		fi
	done
	if [[ $outdatedApp == "true" || "$forceInstall" == "force" ]]; then
		echo "   Mac App \"$currAppName\" is outdated"
		watchPID=""
		capturePkgs
		echo "   ->Watch loop pid: $watchPID"
		# Install Mac App Store App
		mas install "$appId"
		ifError "!!!->Failed to install new app: $appId $currAppName"
		
		# fake app install
		sleep 3
		# stop fake
		
		for swpkg in ${Destination}*.plist
		do
		#    plutil -convert xml1 $swpkg
		    mypackage=`echo  $(basename $swpkg) | perl -pe 's/\.plist$//'`
			# echo "My Package: $mypackage"
			i=0
			while [ 1 ]; do
		        pkgname=$($PBUDDY -c "Print :representations:${i}:assets:0:name" "$swpkg" 2>/dev/null)
		        if [ $? -ne 0 ]; then
		                # finish execution
		                break
		                #exit 0
		        fi
				if [ "$pkgname" == "$mypackage" ]; then
			    	version=$($PBUDDY -c "Print :representations:${i}:bundle-version" "$swpkg" 2>/dev/null)
			    	appname=$($PBUDDY -c "Print :representations:${i}:title" "$swpkg" 2>/dev/null)
			    	appname=`echo $appname | perl -pe 's/\ //g'`
					echo "   Pkg will be renamed from ${Destination}${mypackage} to ${Completed}${appname}${separator}${version}.pkg"
					#if [[ -e *"${Completed}${appname}${separator}"*.pkg ]]; then
					if [[ -e $(ls "${Completed}${appname}${separator}"*.pkg 2>/dev/null) ]]; then
						echo "   Found existing pacakge, moving it to ${Outdated}..."
						if [[ -e "${Outdated}${appname}${separator}${version}.pkg" ]]; then
							echo "   ...Found existing old package with same version, deleting first..."
							rm "${Outdated}${appname}${separator}${version}".pkg
						fi
						mv "${Completed}${appname}${separator}"*.pkg "${Outdated}"
					fi
					mv "${Destination}${mypackage}" "${Completed}${appname}${separator}${version}.pkg" 2>/dev/null
					rm "${Destination}${mypackage}.plist"
		        fi
				i=$(($i+1))
			done
		done
		
		echo "Updated app."
		$PBUDDY -c "Delete $appId" "$appsPlist" 2>/dev/null
		$PBUDDY -c "Add $appId string \"$currAppName\"" "$appsPlist" 2>/dev/null
		
		kill -2 "$watchPID"		
	else
		echo "   Mac App \"$currAppName\" is up to date"
	fi
done

killall bash
killall sleep

exit 0
