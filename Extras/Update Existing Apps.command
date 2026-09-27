#!/bin/bash

# Update apps created from this WebKit template while preserving their settings,
# icons, and userContent files.

set -e
cd "`dirname "$0"`"

template_app="../Web App Template.app"
template_contents="$template_app/Contents"

if [ ! -x "$template_contents/MacOS/WebApp" ] ||
   [ ! -x "$template_contents/MacOS/makeicns" ] ||
   [ ! -f "$template_contents/MacOS/update-app-icon" ]
then
	echo "Error: Build Web App Template.app before updating existing apps."
	exit 1
fi

selected_apps=()
interactive_mode=false

if [ "$1" = "--update-apps-folder" ]
then
	for app in /Applications/*.app
	do
		if [ -d "$app" ]
		then
			selected_apps+=("$app")
		fi
	done
elif [ $# -gt 0 ]
then
	for app in "$@"
	do
		selected_apps+=("$app")
	done
else
	interactive_mode=true
	input_apps=$(osascript <<'APPLESCRIPT'
tell application "System Events"
	activate
	set chosenFiles to choose file of type {"com.apple.application-bundle"} with multiple selections allowed with prompt "Select apps to update"
	set posixPaths to ""
	repeat with aFile in chosenFiles
		set posixPaths to posixPaths & POSIX path of aFile & linefeed
	end repeat
	if posixPaths is not "" then
		return text 1 thru -2 of posixPaths
	else
		return ""
	end if
end tell
APPLESCRIPT
)
	while IFS= read -r app
	do
		if [ -n "$app" ]
		then
			selected_apps+=("$app")
		fi
	done <<< "$input_apps"
fi

if [ ${#selected_apps[@]} -eq 0 ]
then
	exit 1
fi

updated_apps=()
invalid_apps=()
user_items=(
	"Resources/AppIcon.icns"
	"Resources/AppIcon.png"
	"Info.plist"
	"Resources/userContent.css"
	"Resources/userContent.js"
)

template_path=$(cd "$template_app" && pwd -P)

for input_app in "${selected_apps[@]}"
do
	if [ ! -d "$input_app/Contents" ]
	then
		invalid_apps+=("$(basename "$input_app")")
		continue
	fi

	input_path=$(cd "$input_app" && pwd -P)
	app_contents="$input_path/Contents"
	if [ "$input_path" = "$template_path" ] ||
	   [ ! -x "$app_contents/MacOS/WebApp" ] ||
	   [ ! -f "$app_contents/Info.plist" ] ||
	   [ ! -f "$app_contents/Resources/userContent.css" ] ||
	   [ ! -f "$app_contents/Resources/userContent.js" ]
	then
		invalid_apps+=("$(basename "$input_app")")
		continue
	fi

	if ! bundle_executable=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" \
		"$app_contents/Info.plist" 2>/dev/null) || [ "$bundle_executable" != "WebApp" ]
	then
		invalid_apps+=("$(basename "$input_app")")
		continue
	fi

	exclude_options=()
	for item in "${user_items[@]}"
	do
		exclude_options+=("--exclude=$item")
	done

	rsync -a --delete "${exclude_options[@]}" "$template_contents/" "$app_contents/"
	chmod 755 "$input_path"
	chmod 755 "$app_contents/MacOS/WebApp" "$app_contents/MacOS/makeicns" \
		"$app_contents/MacOS/update-app-icon"
	if [ -f "$app_contents/Resources/AppIcon.icns" ]
	then
		touch "$app_contents/Resources/AppIcon.icns"
	fi
	touch "$input_path"
	updated_apps+=("$(basename "$input_app")")
done

if [ "$interactive_mode" = true ]
then
	if [ ${#invalid_apps[@]} -eq 1 ]
	then
		osascript -e "display alert \"${invalid_apps[0]} was not modified because it is not an app created by this WebKit template.\" as critical"
	elif [ ${#invalid_apps[@]} -gt 1 ]
	then
		invalid_apps_list=$(printf "%s\\n" "${invalid_apps[@]}")
		osascript -e "display alert \"These apps were not modified because they are not apps created by this WebKit template:\" message \"$invalid_apps_list\" as critical"
	fi

	if [ ${#updated_apps[@]} -eq 1 ]
	then
		osascript -e "display alert \"${updated_apps[0]} updated successfully.\""
	elif [ ${#updated_apps[@]} -gt 1 ]
	then
		updated_apps_list=$(printf "%s\\n" "${updated_apps[@]}")
		osascript -e "display alert \"Applications updated successfully:\" message \"$updated_apps_list\""
	fi
else
	printf "Updated: %s\n" "${updated_apps[@]}"
	if [ ${#invalid_apps[@]} -gt 0 ]
	then
		printf "Skipped: %s\n" "${invalid_apps[@]}"
	fi
fi
