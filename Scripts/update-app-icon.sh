#!/bin/sh

set -e
cd "`dirname "$0"`"

# Create App.icns from App.png, if needed.
if [ -f "../AppIcon.png" ]
then
	dimensions=$(sips -g pixelWidth -g pixelHeight ../AppIcon.png | awk '/pixelWidth|pixelHeight/ {print $2}')
	width=$(echo "$dimensions" | sed -n '1p')
	height=$(echo "$dimensions" | sed -n '2p')
	if [[ $width -ge 512 || $height -ge 512 ]]
	then
		size=512
	elif [[ $width -ge 256 || $height -ge 256 ]]
	then
		size=256
	else
		size=128
	fi
	./makeicns -$size ../AppIcon.png -out ../AppIcon.icns
	rm ../AppIcon.png
	osascript -e 'tell application "System Events" to display alert "App icon updated. Please open the app again."'
	touch ../AppIcon.icns
	touch ../Resources/AppIcon.icns
	touch ../..
	exit 0
fi
