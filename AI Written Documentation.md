# System WebKit Web App Template

This is a native, single-site Mac application template that uses the WebKit
framework installed at `/System/Library/Frameworks/WebKit.framework`. It does
not bundle Firefox or another browser engine. The executable targets Mac OS X
10.9 Mavericks and dynamically uses the `WKWebView` API supplied by the
installed WebKit backport, even though the Mavericks headers do not declare it.
On Mavericks the template loads the modern Objective-C API from the installed
`WebKit2.framework` at runtime, then resolves every WK class by name.

## Configure an app

1. Duplicate `Web App Template.app`.
2. In the duplicate's `Contents/Info.plist`, change `CFBundleIdentifier`,
   `CFBundleName`, and `URL`.
3. Optionally adjust `MinimumWebKitVersion` and the other settings below the
   optional-settings marker.
4. Optionally put `AppIcon.png` in the duplicate's `Contents` folder. On first
   launch it is converted to `AppIcon.icns`, removed, and you are prompted to
   reopen the app. You can also replace `Contents/AppIcon.icns` directly.
5. Open the app.

`MinimumWebKitVersion` is compared numerically with the installed WebKit
framework's `CFBundleVersion`. For example, `615.1.1+` satisfies a minimum of
`615.1.1`. If the installed version is too old, the app shows the required
startup dialog and exits without opening a browser window.

Edit `Contents/Resources/userContent.css` and `userContent.js` to inject custom
content after each top-level page loads.

Web Notifications and Web Push are enabled through the installed WebKit
backport. Notification permission requests made inside the app are granted
automatically without a dialog, and the app's own origin is granted before the
first page loads, so `Notification.permission` already reads `granted` there.
The template reports those grants to WebKit's persistent website data store so
service workers can subscribe, and registers a notification provider on the
WebKit process pool for notifications that pages create with
`new Notification()`. Both kinds are delivered through the Mavericks
Notification Center, and clicks are routed back to WebKit. Subscriptions use
the bundled `webpushd` service. WebKit's built-in notification delivery stays
disabled: on this system it answers page-level permission checks through
`webpushd`, which reports every page origin as denied without consulting the
app.

The template also automatically grants WebKit permission requests for camera
and microphone capture, geolocation, device orientation and motion, clipboard
access, background fetch, persistent storage, pointer lock, and storage access.
Screen sharing is allowed automatically, but WebKit still displays its required
screen-source chooser because a page cannot choose a screen on the user's behalf.
For geolocation, the template also registers the host provider required by
WebKit and forwards positions from Mavericks CoreLocation. The web permission
is automatic; macOS may still request app-level Location Services authorization
the first time a generated app asks for a position.

Downloads are saved to the user's Downloads folder, with a numeric suffix added
when a file of the same name already exists. A download starts when a link
carries the `download` attribute (including `blob:` and `data:` links), when a
response is served with `Content-Disposition: attachment`, or when WebKit cannot
display the response's type. The Dock's Downloads folder bounces when a
download finishes, and a failed download shows an error dialog. `blob:` URLs
always stay inside the app.

## Plist settings

- `InitialWindowWidth`, `InitialWindowHeight`: first window's content size.
- `MinimumWindowWidth`, `MinimumWindowHeight`: minimum content size.
- `MaximumWindowWidth`, `MaximumWindowHeight`: optional maximum content size;
  leave empty for no limit. A maximum disables native full screen, removes the
  full-screen command, and removes the View menu when Refresh would be its
  only remaining item.
- `TerminateAfterLastWindowClosed`: whether closing the final window quits.
- `InAppURLs`: additional URL patterns that stay inside the app. `*` is a
  wildcard; `|`, `(`, and `)` can be used for groups. Other regular-expression
  punctuation is treated literally.
- `EnableShareMenuItem`, `EnablePrintMenuItem`, `EnableHistoryMenu`: menu
  switches.
- `AllowDeveloperTools`: enables the Web Inspector preference and adds
  Window > Web Inspector (Option-Command-I).
- `AppMenuItems`, `FileMenuItems`, `ViewMenuItems`: arrays of dictionaries that
  map menu titles to URLs or `javascript:` actions. A custom item whose title
  matches a default item replaces that default in place, preserving its menu
  position and keyboard shortcut.
- `HelpURL`: optional destination for the app's Help item. The Help menu and its
  standard app-specific Help item are present even when this is empty.

Edit menu commands are first offered to the web app as their standard macOS
keyboard events, so a site's Command-F, Command-Z, clipboard, or selection
handler also runs when the command is chosen from the menu. If the site does
not handle the event, the normal native action runs (including WKWebView's find
bar for Edit > Find…). User-defined macOS menu shortcuts are honored; after a
shortcut is replaced in System Settings, its old default keystroke is not sent
through to the site. View > Enter Full Screen changes to Exit Full Screen while
the current window is full screen.

When `EnableHistoryMenu` is enabled, History contains Back, Forward, a
separator, and the 15 most recent visits (matching the old Firefox menu). Each
generated app keeps its own persistent history. As in the old template's SSB
Helper, entries are retained for 90 days, external URLs are excluded, duplicate
titles keep only their newest visit, and generic titles containing the app name
are omitted. Single-page-app route changes are recorded after their page titles
settle. The current page is checked in the menu. Selecting an entry focuses an
existing window already displaying that URL; otherwise, it loads the entry in
the current window.

Absolute custom-menu URLs open in a new in-app window when allowed by `URL` or
`InAppURLs`; otherwise they open in the default browser. Relative URLs load in
the current window.

## Rebuild

The checked-in app bundle is built with the system command-line compiler and a
plain Makefile. Xcode, `xcodebuild`, and third-party dependencies are not used:

```sh
make check
```

The Makefile generates `Contents/Info.plist` from `Info.plist.template`.
It also copies the old template's Mavericks-compatible `makeicns` binary and
icon-conversion script into the generated app bundle.

To probe the installed backport without opening a window:

```sh
"Web App Template.app/Contents/MacOS/WebApp" --check-webkit
```

## Update existing apps

Run `Extras/Update Existing Apps.command` to select previously generated apps
and update their managed runtime files from the current built template. It
preserves each app's `Info.plist`, `AppIcon.png` or `AppIcon.icns`, and
`Contents/Resources/userContent.css` and `userContent.js` files.

For noninteractive use, pass one or more app paths, or use
`--update-apps-folder` to scan `/Applications`.
