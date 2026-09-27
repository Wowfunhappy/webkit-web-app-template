APP_DIR := Web App Template.app
EXECUTABLE := Web\ App\ Template.app/Contents/MacOS/WebApp
INFO_PLIST := Web\ App\ Template.app/Contents/Info.plist
INFO_PLIST_TEMPLATE := Info.plist.template
MAKEICNS_SOURCE := Reference/Old/Web\ App\ Template.app/Contents/MacOS/makeicns
MAKEICNS := Web\ App\ Template.app/Contents/MacOS/makeicns
ICON_SCRIPT_SOURCE := Scripts/update-app-icon.sh
ICON_SCRIPT := Web\ App\ Template.app/Contents/MacOS/update-app-icon
SOURCE := Sources/main.m

.PHONY: all clean check

all: $(EXECUTABLE) $(MAKEICNS) $(ICON_SCRIPT)

$(INFO_PLIST): $(INFO_PLIST_TEMPLATE)
	mkdir -p "$(APP_DIR)/Contents"
	cp "$<" "$@"

$(EXECUTABLE): $(SOURCE) $(INFO_PLIST)
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	clang -fobjc-arc -fblocks -Wall -Wextra -Wno-deprecated-declarations \
		-mmacosx-version-min=10.9 -framework Cocoa -framework CoreLocation \
		-framework WebKit \
		-o "$@" "$<"

$(MAKEICNS): $(MAKEICNS_SOURCE)
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	cp "$<" "$@"
	chmod +x "$@"

$(ICON_SCRIPT): $(ICON_SCRIPT_SOURCE)
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	cp "$<" "$@"
	chmod +x "$@"

check: all
	plutil -lint "$(APP_DIR)/Contents/Info.plist"
	sh -n "$(APP_DIR)/Contents/MacOS/update-app-icon"
	bash -n "Extras/Update Existing Apps.command"
	test -x "Extras/Update Existing Apps.command"
	cmp "Reference/Old/Web App Template.app/Contents/MacOS/makeicns" "$(APP_DIR)/Contents/MacOS/makeicns"
	file "$(APP_DIR)/Contents/MacOS/WebApp"
	file "$(APP_DIR)/Contents/MacOS/makeicns"
	otool -L "$(APP_DIR)/Contents/MacOS/WebApp"
	"$(APP_DIR)/Contents/MacOS/WebApp" --check-webkit

clean:
	rm -f "$(APP_DIR)/Contents/MacOS/WebApp" \
		"$(APP_DIR)/Contents/MacOS/makeicns" \
		"$(APP_DIR)/Contents/MacOS/update-app-icon" \
		"$(APP_DIR)/Contents/Info.plist"
