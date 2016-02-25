Auto-Download MacApp Store Apps

1. Login to App Store, Turn off Automatic Updates

2. Start watch for new pkgs in temp folder
https://github.com/maxschlapfer/MacAdminHelpers/blob/master/AppStoreExtract/AppStoreExtract.sh

3. Run mas script to check for new updates
https://github.com/argon/mas

4. Process new updates with AutoPkg

Create working DIR
./downloading/
./completed/
./outdated/

Array of App Store apps ID (e.g. Slack = 803453959)

IF nothing has been completed, install each app().
ELSE check for outdated apps
   FOR each app in array
	IF outdated, move old pkg (name in plist) to outdated+date
	   install each app()
	   (link pkg in downloading, move to completed when done)
	   save new version pkg name to plist


install each app:
(Start folder watch for new pkgs
link found pkg in downloading
install new app with ID
stop watching folder
move to completed when done)
