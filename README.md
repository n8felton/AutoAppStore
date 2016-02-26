Auto-Download MacApp Store Apps

This project's aim is to simplify the downloading of App Store pkgs.
Using other open source tools, it allows the admin to specify the
App IDs to download in a plist. That plist is then used to check
each app for updates. By default, the script will only download apps
that are out of date. If you want do download all apps, regardless of
their status, use the parameter "force".

Basic Overview of steps:

1. Login to App Store, Turn off Automatic Updates

2. Run appStoreExtract.sh

The script then...

...creates these working directories:
./downloading/
./completed/
./outdated/

...creates array of App Store apps ID (e.g. Slack = 803453959) from plist

...Starts watching for new pkgs in temp folder
https://github.com/maxschlapfer/MacAdminHelpers/blob/master/AppStoreExtract/AppStoreExtract.sh

...Runs mas to check for new updates
https://github.com/argon/mas

...installs updates for apps that are in plist array

...Links new packages to downloading folder

...Stops watching for new packages

...Moves completed packages to completed folder, renames them

...Adds name of package to plist with App ID as key

...Moves older versions of packages from completed to outdated

3. Profit? Ideally, we'll link this with AutoPkg
