#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#include <dlfcn.h>

/*
 * The WebKit backport exports the legacy C geolocation-provider SPI, but the
 * Mavericks SDK does not install its headers. In this backport WKContextRef
 * is the Objective-C WKProcessPool wrapper used by the Cocoa API.
 */
typedef const struct OpaqueWKContext *WKContextRef;
typedef const struct OpaqueWKGeolocationManager *WKGeolocationManagerRef;
typedef const struct OpaqueWKGeolocationPosition *WKGeolocationPositionRef;

typedef void (*WKGeolocationProviderStartUpdatingCallback)(
    WKGeolocationManagerRef manager, const void *clientInfo);
typedef void (*WKGeolocationProviderStopUpdatingCallback)(
    WKGeolocationManagerRef manager, const void *clientInfo);
typedef void (*WKGeolocationProviderSetEnableHighAccuracyCallback)(
    WKGeolocationManagerRef manager, bool enabled, const void *clientInfo);

typedef struct {
    int version;
    const void *clientInfo;
} WKGeolocationProviderBase;

typedef struct {
    WKGeolocationProviderBase base;
    WKGeolocationProviderStartUpdatingCallback startUpdating;
    WKGeolocationProviderStopUpdatingCallback stopUpdating;
    WKGeolocationProviderSetEnableHighAccuracyCallback setEnableHighAccuracy;
} WKGeolocationProviderV1;

typedef WKGeolocationManagerRef (*WKContextGetGeolocationManagerFunction)(WKContextRef context);
typedef WKContextRef (*WKContextCreateFunction)(void);
typedef void (*WKGeolocationManagerSetProviderFunction)(
    WKGeolocationManagerRef manager, const WKGeolocationProviderBase *provider);
typedef void (*WKGeolocationManagerProviderDidChangePositionFunction)(
    WKGeolocationManagerRef manager, WKGeolocationPositionRef position);
typedef void (*WKGeolocationManagerProviderDidFailToDeterminePositionFunction)(
    WKGeolocationManagerRef manager);
typedef WKGeolocationPositionRef (*WKGeolocationPositionCreateFunction)(
    double timestamp, double latitude, double longitude, double accuracy,
    bool providesAltitude, double altitude,
    bool providesAltitudeAccuracy, double altitudeAccuracy,
    bool providesHeading, double heading,
    bool providesSpeed, double speed);
typedef void (*WKReleaseFunction)(const void *object);

/*
 * The backport also exports the C notification-provider SPI. Page-created
 * notifications (`new Notification()`) reach the app only through a provider
 * registered on the process pool's notification manager.
 */
typedef const struct OpaqueWKNotificationManager *WKNotificationManagerRef;
typedef const struct OpaqueWKNotification *WKNotificationRef;
typedef const struct OpaqueWKPage *WKPageRef;
typedef const struct OpaqueWKString *WKStringRef;
typedef const struct OpaqueWKSecurityOrigin *WKSecurityOriginRef;
typedef const struct OpaqueWKArray *WKArrayRef;
typedef const struct OpaqueWKDictionary *WKDictionaryRef;
typedef const struct OpaqueWKDictionary *WKMutableDictionaryRef;
typedef const struct OpaqueWKBoolean *WKBooleanRef;
typedef const struct OpaqueWKUInt64 *WKUInt64Ref;
typedef const void *WKTypeRef;

typedef void (*WKNotificationProviderShowCallback)(
    WKPageRef page, WKNotificationRef notification, const void *clientInfo);
typedef void (*WKNotificationProviderCancelCallback)(
    WKNotificationRef notification, const void *clientInfo);
typedef void (*WKNotificationProviderDidDestroyNotificationCallback)(
    WKNotificationRef notification, const void *clientInfo);
typedef void (*WKNotificationProviderAddNotificationManagerCallback)(
    WKNotificationManagerRef manager, const void *clientInfo);
typedef void (*WKNotificationProviderRemoveNotificationManagerCallback)(
    WKNotificationManagerRef manager, const void *clientInfo);
typedef WKDictionaryRef (*WKNotificationProviderNotificationPermissionsCallback)(
    const void *clientInfo);
typedef void (*WKNotificationProviderClearNotificationsCallback)(
    WKArrayRef notificationIDs, const void *clientInfo);

typedef struct {
    int version;
    const void *clientInfo;
} WKNotificationProviderBase;

typedef struct {
    WKNotificationProviderBase base;
    WKNotificationProviderShowCallback show;
    WKNotificationProviderCancelCallback cancel;
    WKNotificationProviderDidDestroyNotificationCallback didDestroyNotification;
    WKNotificationProviderAddNotificationManagerCallback addNotificationManager;
    WKNotificationProviderRemoveNotificationManagerCallback removeNotificationManager;
    WKNotificationProviderNotificationPermissionsCallback notificationPermissions;
    WKNotificationProviderClearNotificationsCallback clearNotifications;
} WKNotificationProviderV0;

/* WKNotificationGetAlert values: 1 default, 2 silent, 3 sound enabled. */
static const uint32_t WebAppWKNotificationAlertSilent = 2;

typedef WKNotificationManagerRef (*WKContextGetNotificationManagerFunction)(WKContextRef context);
typedef void (*WKNotificationManagerSetProviderFunction)(
    WKNotificationManagerRef manager, const WKNotificationProviderBase *provider);
typedef void (*WKNotificationManagerProviderDidShowNotificationFunction)(
    WKNotificationManagerRef manager, uint64_t notificationID);
typedef void (*WKNotificationManagerProviderDidClickNotificationFunction)(
    WKNotificationManagerRef manager, uint64_t notificationID);
typedef void (*WKNotificationManagerProviderDidCloseNotificationsFunction)(
    WKNotificationManagerRef manager, WKArrayRef notificationIDs);
typedef uint64_t (*WKNotificationGetIDFunction)(WKNotificationRef notification);
typedef WKStringRef (*WKNotificationCopyStringFunction)(WKNotificationRef notification);
typedef uint32_t (*WKNotificationGetAlertFunction)(WKNotificationRef notification);
typedef WKSecurityOriginRef (*WKNotificationGetSecurityOriginFunction)(
    WKNotificationRef notification);
typedef WKStringRef (*WKSecurityOriginCopyToStringFunction)(WKSecurityOriginRef origin);
typedef CFStringRef (*WKStringCopyCFStringFunction)(CFAllocatorRef allocator, WKStringRef string);
typedef WKStringRef (*WKStringCreateWithCFStringFunction)(CFStringRef string);
typedef WKMutableDictionaryRef (*WKMutableDictionaryCreateFunction)(void);
typedef bool (*WKDictionarySetItemFunction)(
    WKMutableDictionaryRef dictionary, WKStringRef key, WKTypeRef item);
typedef WKBooleanRef (*WKBooleanCreateFunction)(bool value);
typedef WKUInt64Ref (*WKUInt64CreateFunction)(uint64_t value);
typedef uint64_t (*WKUInt64GetValueFunction)(WKUInt64Ref value);
typedef WKArrayRef (*WKArrayCreateFunction)(WKTypeRef *values, size_t count);
typedef size_t (*WKArrayGetSizeFunction)(WKArrayRef array);
typedef WKTypeRef (*WKArrayGetItemAtIndexFunction)(WKArrayRef array, size_t index);

static WKContextGetGeolocationManagerFunction WebAppWKContextGetGeolocationManager;
static WKContextCreateFunction WebAppWKContextCreate;
static WKGeolocationManagerSetProviderFunction WebAppWKGeolocationManagerSetProvider;
static WKGeolocationManagerProviderDidChangePositionFunction
    WebAppWKGeolocationManagerProviderDidChangePosition;
static WKGeolocationManagerProviderDidFailToDeterminePositionFunction
    WebAppWKGeolocationManagerProviderDidFailToDeterminePosition;
static WKGeolocationPositionCreateFunction WebAppWKGeolocationPositionCreate;
static WKReleaseFunction WebAppWKRelease;
static WKContextGetNotificationManagerFunction WebAppWKContextGetNotificationManager;
static WKNotificationManagerSetProviderFunction WebAppWKNotificationManagerSetProvider;
static WKNotificationManagerProviderDidShowNotificationFunction
    WebAppWKNotificationManagerProviderDidShowNotification;
static WKNotificationManagerProviderDidClickNotificationFunction
    WebAppWKNotificationManagerProviderDidClickNotification;
static WKNotificationManagerProviderDidCloseNotificationsFunction
    WebAppWKNotificationManagerProviderDidCloseNotifications;
static WKNotificationGetIDFunction WebAppWKNotificationGetID;
static WKNotificationCopyStringFunction WebAppWKNotificationCopyTitle;
static WKNotificationCopyStringFunction WebAppWKNotificationCopyBody;
static WKNotificationGetAlertFunction WebAppWKNotificationGetAlert;
static WKNotificationGetSecurityOriginFunction WebAppWKNotificationGetSecurityOrigin;
static WKSecurityOriginCopyToStringFunction WebAppWKSecurityOriginCopyToString;
static WKStringCopyCFStringFunction WebAppWKStringCopyCFString;
static WKStringCreateWithCFStringFunction WebAppWKStringCreateWithCFString;
static WKMutableDictionaryCreateFunction WebAppWKMutableDictionaryCreate;
static WKDictionarySetItemFunction WebAppWKDictionarySetItem;
static WKBooleanCreateFunction WebAppWKBooleanCreate;
static WKUInt64CreateFunction WebAppWKUInt64Create;
static WKUInt64GetValueFunction WebAppWKUInt64GetValue;
static WKArrayCreateFunction WebAppWKArrayCreate;
static WKArrayGetSizeFunction WebAppWKArrayGetSize;
static WKArrayGetItemAtIndexFunction WebAppWKArrayGetItemAtIndex;

static BOOL LoadWebKitGeolocationAPI(void)
{
    static BOOL attempted = NO;
    static BOOL usable = NO;
    if (attempted) return usable;
    attempted = YES;

    void *webKit2 = dlopen(
        "/System/Library/PrivateFrameworks/WebKit2.framework/Versions/A/WebKit2",
        RTLD_LAZY | RTLD_LOCAL);
    if (!webKit2) return NO;

    WebAppWKContextGetGeolocationManager =
        (WKContextGetGeolocationManagerFunction)dlsym(webKit2,
            "WKContextGetGeolocationManager");
    WebAppWKContextCreate =
        (WKContextCreateFunction)dlsym(webKit2, "WKContextCreate");
    WebAppWKGeolocationManagerSetProvider =
        (WKGeolocationManagerSetProviderFunction)dlsym(webKit2,
            "WKGeolocationManagerSetProvider");
    WebAppWKGeolocationManagerProviderDidChangePosition =
        (WKGeolocationManagerProviderDidChangePositionFunction)dlsym(webKit2,
            "WKGeolocationManagerProviderDidChangePosition");
    WebAppWKGeolocationManagerProviderDidFailToDeterminePosition =
        (WKGeolocationManagerProviderDidFailToDeterminePositionFunction)dlsym(webKit2,
            "WKGeolocationManagerProviderDidFailToDeterminePosition");
    WebAppWKGeolocationPositionCreate =
        (WKGeolocationPositionCreateFunction)dlsym(webKit2,
            "WKGeolocationPositionCreate_b");
    WebAppWKRelease = (WKReleaseFunction)dlsym(webKit2, "WKRelease");
    usable = WebAppWKContextCreate && WebAppWKContextGetGeolocationManager &&
        WebAppWKGeolocationManagerSetProvider &&
        WebAppWKGeolocationManagerProviderDidChangePosition &&
        WebAppWKGeolocationManagerProviderDidFailToDeterminePosition &&
        WebAppWKGeolocationPositionCreate && WebAppWKRelease;
    return usable;
}

static BOOL LoadWebKitNotificationAPI(void)
{
    static BOOL attempted = NO;
    static BOOL usable = NO;
    if (attempted) return usable;
    attempted = YES;

    void *webKit2 = dlopen(
        "/System/Library/PrivateFrameworks/WebKit2.framework/Versions/A/WebKit2",
        RTLD_LAZY | RTLD_LOCAL);
    if (!webKit2) return NO;

    WebAppWKContextGetNotificationManager =
        (WKContextGetNotificationManagerFunction)dlsym(webKit2,
            "WKContextGetNotificationManager");
    WebAppWKNotificationManagerSetProvider =
        (WKNotificationManagerSetProviderFunction)dlsym(webKit2,
            "WKNotificationManagerSetProvider");
    WebAppWKNotificationManagerProviderDidShowNotification =
        (WKNotificationManagerProviderDidShowNotificationFunction)dlsym(webKit2,
            "WKNotificationManagerProviderDidShowNotification");
    WebAppWKNotificationManagerProviderDidClickNotification =
        (WKNotificationManagerProviderDidClickNotificationFunction)dlsym(webKit2,
            "WKNotificationManagerProviderDidClickNotification");
    WebAppWKNotificationManagerProviderDidCloseNotifications =
        (WKNotificationManagerProviderDidCloseNotificationsFunction)dlsym(webKit2,
            "WKNotificationManagerProviderDidCloseNotifications");
    WebAppWKNotificationGetID =
        (WKNotificationGetIDFunction)dlsym(webKit2, "WKNotificationGetID");
    WebAppWKNotificationCopyTitle =
        (WKNotificationCopyStringFunction)dlsym(webKit2, "WKNotificationCopyTitle");
    WebAppWKNotificationCopyBody =
        (WKNotificationCopyStringFunction)dlsym(webKit2, "WKNotificationCopyBody");
    WebAppWKNotificationGetAlert =
        (WKNotificationGetAlertFunction)dlsym(webKit2, "WKNotificationGetAlert");
    WebAppWKNotificationGetSecurityOrigin =
        (WKNotificationGetSecurityOriginFunction)dlsym(webKit2,
            "WKNotificationGetSecurityOrigin");
    WebAppWKSecurityOriginCopyToString =
        (WKSecurityOriginCopyToStringFunction)dlsym(webKit2, "WKSecurityOriginCopyToString");
    WebAppWKStringCopyCFString =
        (WKStringCopyCFStringFunction)dlsym(webKit2, "WKStringCopyCFString");
    WebAppWKStringCreateWithCFString =
        (WKStringCreateWithCFStringFunction)dlsym(webKit2, "WKStringCreateWithCFString");
    WebAppWKMutableDictionaryCreate =
        (WKMutableDictionaryCreateFunction)dlsym(webKit2, "WKMutableDictionaryCreate");
    WebAppWKDictionarySetItem =
        (WKDictionarySetItemFunction)dlsym(webKit2, "WKDictionarySetItem");
    WebAppWKBooleanCreate = (WKBooleanCreateFunction)dlsym(webKit2, "WKBooleanCreate");
    WebAppWKUInt64Create = (WKUInt64CreateFunction)dlsym(webKit2, "WKUInt64Create");
    WebAppWKUInt64GetValue = (WKUInt64GetValueFunction)dlsym(webKit2, "WKUInt64GetValue");
    WebAppWKArrayCreate = (WKArrayCreateFunction)dlsym(webKit2, "WKArrayCreate");
    WebAppWKArrayGetSize = (WKArrayGetSizeFunction)dlsym(webKit2, "WKArrayGetSize");
    WebAppWKArrayGetItemAtIndex =
        (WKArrayGetItemAtIndexFunction)dlsym(webKit2, "WKArrayGetItemAtIndex");
    if (!WebAppWKRelease) WebAppWKRelease = (WKReleaseFunction)dlsym(webKit2, "WKRelease");
    usable = WebAppWKContextGetNotificationManager &&
        WebAppWKNotificationManagerSetProvider &&
        WebAppWKNotificationManagerProviderDidShowNotification &&
        WebAppWKNotificationManagerProviderDidClickNotification &&
        WebAppWKNotificationManagerProviderDidCloseNotifications &&
        WebAppWKNotificationGetID && WebAppWKNotificationCopyTitle &&
        WebAppWKNotificationCopyBody && WebAppWKNotificationGetAlert &&
        WebAppWKNotificationGetSecurityOrigin && WebAppWKSecurityOriginCopyToString &&
        WebAppWKStringCopyCFString && WebAppWKStringCreateWithCFString &&
        WebAppWKMutableDictionaryCreate && WebAppWKDictionarySetItem &&
        WebAppWKBooleanCreate && WebAppWKUInt64Create && WebAppWKUInt64GetValue &&
        WebAppWKArrayCreate && WebAppWKArrayGetSize && WebAppWKArrayGetItemAtIndex &&
        WebAppWKRelease;
    return usable;
}

/* Converts and releases a WKStringRef returned by a Copy function. */
static NSString *WebAppStringFromWKString(WKStringRef string)
{
    if (!string) return nil;
    CFStringRef cfString = WebAppWKStringCopyCFString(kCFAllocatorDefault, string);
    WebAppWKRelease(string);
    return cfString ? (__bridge_transfer NSString *)cfString : nil;
}

@protocol WebAppWKInspector <NSObject>
- (void)show;
@end

@protocol WebAppWKSecurityOrigin <NSObject>
- (NSString *)protocol;
- (NSString *)host;
- (NSNumber *)port;
@end

@protocol WebAppWKNavigationResponse <NSObject>
- (NSURLResponse *)response;
- (BOOL)canShowMIMEType;
- (BOOL)isForMainFrame;
@end

@protocol WebAppWKDownload <NSObject>
- (NSURLRequest *)originalRequest;
- (void)setDelegate:(id)delegate;
@end

/*
 * WKWebView is supplied by the updated WebKit backport on the target system,
 * but its headers are not present in the Mavericks SDK.  These declarations
 * describe only the small public API surface used here.  No WK class symbol is
 * referenced directly, so the executable can still start and report a useful
 * version error when an older system WebKit does not contain WKWebView.
 */
@interface NSObject (WebAppWKWebKit)
- (id)initWithFrame:(NSRect)frame configuration:(id)configuration;
- (id)initWithSource:(NSString *)source injectionTime:(NSInteger)injectionTime
    forMainFrameOnly:(BOOL)mainFrameOnly;
- (void)setNavigationDelegate:(id)delegate;
- (void)setUIDelegate:(id)delegate;
- (id)preferences;
- (id)defaultWebpagePreferences;
- (id)websiteDataStore;
- (void)set_delegate:(id)delegate;
- (void)_processPersistentNotificationClick:(NSDictionary *)notification
    completionHandler:(void (^)(BOOL handled))completionHandler;
- (BOOL)isPersistent;
- (id)userContentController;
- (id)configuration;
- (id)processPool;
- (void)setProcessPool:(id)processPool;
- (void)addScriptMessageHandler:(id)handler name:(NSString *)name;
- (void)removeScriptMessageHandlerForName:(NSString *)name;
- (id)_inspector;
- (void)addUserScript:(id)script;
- (void)loadRequest:(NSURLRequest *)request;
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (void)setValue:(id)value forKey:(NSString *)key;
- (void)evaluateJavaScript:(NSString *)script completionHandler:(void (^)(id, NSError *))completionHandler;
- (NSURL *)URL;
- (NSString *)title;
- (NSURLRequest *)request;
- (id)targetFrame;
- (BOOL)isMainFrame;
- (BOOL)shouldPerformDownload;
- (id)hitTestResult;
- (NSURL *)absoluteImageURL;
- (NSURL *)absolutePDFURL;
- (NSURL *)absoluteLinkURL;
- (NSURL *)absoluteMediaURL;
- (NSString *)lookupText;
- (BOOL)isContentEditable;
- (BOOL)isSelected;
- (NSString *)body;
- (NSString *)origin;
- (NSString *)identifier;
- (NSDictionary *)userInfo;
- (NSDictionary *)dictionaryRepresentation;
- (NSUInteger)alert;
- (void)_setNotificationsEnabled:(BOOL)enabled;
- (BOOL)_notificationsEnabled;
- (void)_setPushAPIEnabled:(BOOL)enabled;
- (BOOL)_pushAPIEnabled;
- (void)_setNotificationEventEnabled:(BOOL)enabled;
- (BOOL)_notificationEventEnabled;
- (void)_setPushAndNotificationAPIEnabled:(BOOL)enabled;
- (BOOL)_pushAndNotificationAPIEnabled;
- (void)_setMediaCaptureEnabled:(BOOL)enabled;
- (BOOL)_mediaCaptureEnabled;
- (void)_setMediaCaptureRequiresSecureConnection:(BOOL)enabled;
- (BOOL)_mediaCaptureRequiresSecureConnection;
- (void)_setJavaScriptCanAccessClipboard:(BOOL)enabled;
- (BOOL)_javaScriptCanAccessClipboard;
- (void)_setDeviceOrientationEventEnabled:(BOOL)enabled;
- (BOOL)_deviceOrientationEventEnabled;
- (void)_setEnabled:(BOOL)enabled forFeature:(id)feature;
- (BOOL)_isEnabledForFeature:(id)feature;
- (NSString *)name;
- (NSString *)key;
+ (NSArray *)_features;
- (void)_setUsePlatformFindUI:(BOOL)enabled;
- (id)_ensureTextFinderClient;
- (BOOL)canGoBack;
- (BOOL)canGoForward;
- (void)goBack;
- (void)goForward;
- (void)reload;
- (void)stopLoading;
@end

@class BrowserWindowController, WebAppGeolocationProvider, WebAppNotificationProvider,
    WebAppDelegate;

typedef NS_ENUM(NSInteger, WebAppEditCommand) {
    WebAppEditCommandUndo = 1,
    WebAppEditCommandRedo,
    WebAppEditCommandCut,
    WebAppEditCommandCopy,
    WebAppEditCommandPaste,
    WebAppEditCommandSelectAll,
    WebAppEditCommandFind
};

@interface WebAppApplication : NSApplication
@end

@interface WebAppGeolocationProvider : NSObject <CLLocationManagerDelegate>
@property(nonatomic, retain) CLLocationManager *locationManager;
@property(nonatomic, retain) id processPool;
@property(nonatomic) WKGeolocationManagerRef webKitManager;
@property(nonatomic) BOOL configured;
@property(nonatomic) BOOL highAccuracyEnabled;
@property(nonatomic) BOOL testLocationEnabled;
@property(nonatomic) BOOL locationRequestsStarted;
- (id)initWithProcessPool:(id)processPool;
- (void)install;
- (void)startUpdating;
- (void)stopUpdating;
- (void)setHighAccuracyEnabled:(BOOL)enabled;
@end

/*
 * Shows notifications created by pages through the Mavericks Notification
 * Center and reports show, click, and close events back to WebKit.
 */
@interface WebAppNotificationProvider : NSObject
@property(nonatomic, assign) WebAppDelegate *appDelegate;
@property(nonatomic, retain) id processPool;
@property(nonatomic, retain) NSMutableDictionary *identifiersByPageNotificationID;
@property(nonatomic) WKNotificationManagerRef webKitManager;
@property(nonatomic) BOOL configured;
- (id)initWithProcessPool:(id)processPool appDelegate:(WebAppDelegate *)appDelegate;
- (void)install;
- (void)showNotification:(WKNotificationRef)notification;
- (void)cancelNotification:(WKNotificationRef)notification;
- (void)forgetNotification:(WKNotificationRef)notification;
- (void)clearNotificationIDs:(WKArrayRef)notificationIDs;
- (WKDictionaryRef)copyNotificationPermissions;
- (void)pageNotificationWithIDWasClicked:(uint64_t)notificationID;
@end

@interface WebAppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate,
                                      NSMenuDelegate>
@property(nonatomic, retain) NSDictionary *configuration;
@property(nonatomic, retain) NSMutableArray *browsers;
@property(nonatomic, retain) NSMutableArray *history;
@property(nonatomic, retain) NSMenu *historyMenu;
@property(nonatomic, retain) NSURL *homeURL;
@property(nonatomic, retain) id websiteDataStore;
@property(nonatomic, retain) id processPool;
@property(nonatomic, retain) WebAppGeolocationProvider *geolocationProvider;
@property(nonatomic, retain) WebAppNotificationProvider *notificationProvider;
@property(nonatomic, retain) NSMutableSet *grantedNotificationOrigins;
@property(nonatomic, retain) NSMutableDictionary *notificationRecords;
@property(nonatomic, retain) NSMapTable *downloadDestinations;
@property(nonatomic, retain) NSURL *downloadDirectoryURL;
@property(nonatomic, retain) NSURL *lastCompletedDownloadURL;
@property(nonatomic) BOOL terminateAfterLastWindowClosed;
@property(nonatomic) BOOL developerToolsEnabled;
- (BrowserWindowController *)newBrowserWithURL:(NSURL *)url;
- (void)beginDownload:(id<WebAppWKDownload>)download;
- (BrowserWindowController *)currentBrowser;
- (BrowserWindowController *)browserForURL:(NSURL *)url;
- (BOOL)isURLAllowedInApp:(NSURL *)url;
- (void)openURLExternally:(NSURL *)url;
- (void)browserDidClose:(BrowserWindowController *)browser;
- (void)grantNotificationPermissionForURL:(NSURL *)url;
- (void)grantNotificationPermissionForSecurityOrigin:(id)origin;
- (NSArray *)grantedNotificationOriginStrings;
- (NSString *)deliverNotificationWithTitle:(NSString *)title body:(NSString *)body
    silent:(BOOL)silent origin:(NSString *)origin record:(NSDictionary *)record;
- (void)removeDeliveredNotificationWithIdentifier:(NSString *)identifier;
- (void)forgetNotificationRecordWithIdentifier:(NSString *)identifier;
- (NSDictionary *)notificationPermissionsForWebsiteDataStore:(id)dataStore;
- (void)websiteDataStore:(id)dataStore showNotification:(id)notificationData;
- (void)websiteDataStore:(id)dataStore
    getDisplayedNotificationsForWorkerOrigin:(id)workerOrigin
    completionHandler:(void (^)(NSArray *notifications))completionHandler;
- (void)websiteDataStore:(id)dataStore navigateToNotificationActionURL:(NSURL *)url;
- (void)requestBackgroundFetchPermission:(NSURL *)topOrigin
    frameOrigin:(NSURL *)frameOrigin decisionHandler:(void (^)(BOOL allowed))decisionHandler;
- (void)requestStorageSpace:(NSURL *)topOrigin frameOrigin:(NSURL *)frameOrigin
    quota:(unsigned long long)quota currentSize:(unsigned long long)currentSize
    spaceRequired:(unsigned long long)spaceRequired
    decisionHandler:(void (^)(unsigned long long newQuota))decisionHandler;
- (void)recordHistoryURL:(NSURL *)url title:(NSString *)title;
- (void)pruneHistory;
- (void)updateHistoryMenu;
- (NSUInteger)applyConfiguredItemsForKey:(NSString *)key toMenu:(NSMenu *)menu
    insertingAtIndex:(NSInteger)insertionIndex;
- (void)buildMenus;
- (void)performWebEditCommand:(NSMenuItem *)sender;
- (void)performNativeEditCommand:(WebAppEditCommand)command;
- (BOOL)shouldSuppressWebEditKeyEvent:(NSEvent *)event;
@end

@interface BrowserWindowController : NSWindowController <NSWindowDelegate, NSTextFinderBarContainer> {
    NSView *_findBarView;
    BOOL _findBarVisible;
}
@property(nonatomic, assign) WebAppDelegate *appDelegate;
@property(nonatomic, retain) id webView;
@property(nonatomic, retain) NSURL *initialURL;
@property(nonatomic, retain) NSTextFinder *textFinder;
@property(nonatomic) BOOL navigationFinished;
@property(nonatomic) BOOL userCSSConfigured;
@property(nonatomic) BOOL userJavaScriptConfigured;
@property(nonatomic) BOOL webPushConfigured;
@property(nonatomic) BOOL automaticPermissionsConfigured;
@property(nonatomic) BOOL geolocationPermissionRequestsHandled;
@property(nonatomic) NSInteger geolocationPermissionDelegateVariant;
@property(nonatomic) BOOL observingHistoryProperties;
@property(nonatomic) BOOL historyMessageHandlerConfigured;
@property(retain) NSView *findBarView;
@property(getter=isFindBarVisible) BOOL findBarVisible;
- (id)initWithOwner:(WebAppDelegate *)owner URL:(NSURL *)url;
- (NSURL *)currentURL;
- (void)loadURL:(NSURL *)url;
- (void)evaluateJavaScript:(NSString *)script;
- (void)layoutFindBar;
- (void)userContentController:(id)userContentController
    didReceiveScriptMessage:(id)message;
- (void)webView:(id)sender decidePolicyForNavigationAction:(id)action
        decisionHandler:(void (^)(NSInteger))decisionHandler;
- (void)webView:(id)sender decidePolicyForNavigationResponse:(id<WebAppWKNavigationResponse>)response
        decisionHandler:(void (^)(NSInteger))decisionHandler;
- (void)webView:(id)sender navigationAction:(id)action didBecomeDownload:(id<WebAppWKDownload>)download;
- (void)webView:(id)sender navigationResponse:(id)response didBecomeDownload:(id<WebAppWKDownload>)download;
- (NSMenu *)_webView:(id)webView contextMenu:(NSMenu *)menu forElement:(id)element;
- (void)_webView:(id)webView requestNotificationPermissionForSecurityOrigin:(id)origin
    decisionHandler:(void (^)(BOOL allowed))decisionHandler;
- (void)webView:(id)webView requestMediaCapturePermissionForOrigin:(id)origin
    initiatedByFrame:(id)frame type:(NSInteger)type
    decisionHandler:(void (^)(NSInteger decision))decisionHandler;
- (void)_webView:(id)webView requestUserMediaAuthorizationForDevices:(NSUInteger)devices
    url:(NSURL *)url mainFrameURL:(NSURL *)mainFrameURL
    decisionHandler:(void (^)(BOOL authorized))decisionHandler;
- (void)webView:(id)webView requestGeolocationPermissionForOrigin:(id)origin
    initiatedByFrame:(id)frame decisionHandler:(void (^)(NSInteger decision))decisionHandler;
- (void)_webView:(id)webView requestGeolocationPermissionForOrigin:(id)origin
    initiatedByFrame:(id)frame decisionHandler:(void (^)(NSInteger decision))decisionHandler;
- (void)_webView:(id)webView requestGeolocationPermissionForFrame:(id)frame
    decisionHandler:(void (^)(BOOL allowed))decisionHandler;
- (void)webView:(id)webView requestDeviceOrientationAndMotionPermissionForOrigin:(id)origin
    initiatedByFrame:(id)frame decisionHandler:(void (^)(NSInteger decision))decisionHandler;
- (void)_webView:(id)webView requestDisplayCapturePermissionForOrigin:(id)origin
    initiatedByFrame:(id)frame withSystemAudio:(BOOL)withSystemAudio
    decisionHandler:(void (^)(NSInteger decision))decisionHandler;
- (void)_webView:(id)webView decidePolicyForScreenCaptureUnmutingForOrigin:(id)origin
    initiatedByFrame:(id)frame decisionHandler:(void (^)(BOOL allowed))decisionHandler;
- (void)_webView:(id)webView queryPermission:(NSString *)permission
    forOrigin:(id)origin completionHandler:(void (^)(NSInteger decision))completionHandler;
- (void)_webView:(id)webView requestStorageAccessPanelForDomain:(NSString *)requestingDomain
    underCurrentDomain:(NSString *)currentDomain
    completionHandler:(void (^)(BOOL allowed))completionHandler;
- (void)_webViewDidRequestPointerLock:(id)webView
    completionHandler:(void (^)(BOOL allowed))completionHandler;
- (void)_webView:(id)webView includeSensitiveMediaDeviceDetails:
    (void (^)(BOOL includeSensitiveDetails))decisionHandler;
@end

enum {
    WebAppPermissionDecisionGrant = 1,
    WebAppDisplayCapturePermissionDecisionScreenPrompt = 1
};

static BOOL ResponseIsAttachment(NSURLResponse *response)
{
    if (![response isKindOfClass:[NSHTTPURLResponse class]]) return NO;
    NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
    for (NSString *name in headers) {
        if ([name caseInsensitiveCompare:@"Content-Disposition"] != NSOrderedSame) continue;
        NSString *value = [[headers objectForKey:name] lowercaseString];
        NSString *disposition = [[[value componentsSeparatedByString:@";"] objectAtIndex:0]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        return [disposition isEqualToString:@"attachment"];
    }
    return NO;
}

/* Returns a path in the directory that no existing file occupies. */
static NSURL *UnusedFileURLInDirectory(NSURL *directory, NSString *filename)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *base = [filename stringByDeletingPathExtension];
    NSString *extension = [filename pathExtension];
    NSURL *candidate = [directory URLByAppendingPathComponent:filename];
    for (NSUInteger counter = 2; [fileManager fileExistsAtPath:[candidate path]]; counter++) {
        NSString *numbered = [NSString stringWithFormat:@"%@-%lu", base, (unsigned long)counter];
        if ([extension length]) numbered = [numbered stringByAppendingPathExtension:extension];
        candidate = [directory URLByAppendingPathComponent:numbered];
    }
    return candidate;
}

static NSString *StringSetting(NSDictionary *settings, NSString *key)
{
    id value = [settings objectForKey:key];
    if ([value isKindOfClass:[NSString class]])
        return value;
    if ([value respondsToSelector:@selector(stringValue)])
        return [value stringValue];
    return @"";
}

static NSString *OriginString(NSString *scheme, NSString *host, NSNumber *port)
{
    if (![scheme length] || ![host length]) return nil;
    NSInteger portNumber = [port integerValue];
    BOOL isDefaultPort = ([scheme caseInsensitiveCompare:@"http"] == NSOrderedSame &&
                          portNumber == 80) ||
                         ([scheme caseInsensitiveCompare:@"https"] == NSOrderedSame &&
                          portNumber == 443);
    if (portNumber > 0 && !isDefaultPort)
        return [NSString stringWithFormat:@"%@://%@:%ld", [scheme lowercaseString],
                                          [host lowercaseString], (long)portNumber];
    return [NSString stringWithFormat:@"%@://%@", [scheme lowercaseString],
                                      [host lowercaseString]];
}

static NSString *OriginStringForURL(NSURL *url)
{
    return url ? OriginString([url scheme], [url host], [url port]) : nil;
}

/*
 * NSUserNotification rejects userInfo larger than 1 KB, so a delivered
 * notification's userInfo carries only its record identifier and origin. The
 * WebKit payload lives in WebAppDelegate's notificationRecords under that
 * identifier.
 */
static NSString * const WebAppNotificationRecordKey =
    @"WebAppWebKitNotificationRecord";
static NSString * const WebAppNotificationOriginKey =
    @"WebAppWebKitNotificationOrigin";
static NSString * const WebAppNotificationKindKey = @"Kind";
static NSString * const WebAppNotificationKindPage = @"Page";
static NSString * const WebAppNotificationKindPersistent = @"Persistent";
static NSString * const WebAppNotificationPageIDKey = @"PageNotificationID";
static NSString * const WebAppNotificationClickInfoKey = @"ClickInfo";
static NSString * const WebAppNotificationRepresentationKey = @"Representation";

static NSString * const WebAppHistoryDefaultsKey = @"WebAppBrowsingHistory";
static const NSUInteger WebAppHistoryMenuMaximumItems = 15;
static const NSTimeInterval WebAppHistoryMaximumAge = 90.0 * 24.0 * 60.0 * 60.0;
static void *WebAppHistoryObservationContext = &WebAppHistoryObservationContext;
static NSString * const WebAppHistoryMessageHandlerName = @"webAppHistory";

static void WebAppNotificationShow(WKPageRef page, WKNotificationRef notification,
                                   const void *clientInfo)
{
    (void)page;
    [(__bridge WebAppNotificationProvider *)clientInfo showNotification:notification];
}

static void WebAppNotificationCancel(WKNotificationRef notification, const void *clientInfo)
{
    [(__bridge WebAppNotificationProvider *)clientInfo cancelNotification:notification];
}

static void WebAppNotificationDidDestroy(WKNotificationRef notification,
                                         const void *clientInfo)
{
    [(__bridge WebAppNotificationProvider *)clientInfo forgetNotification:notification];
}

static void WebAppNotificationAddManager(WKNotificationManagerRef manager,
                                         const void *clientInfo)
{
    [(__bridge WebAppNotificationProvider *)clientInfo setWebKitManager:manager];
}

static void WebAppNotificationRemoveManager(WKNotificationManagerRef manager,
                                            const void *clientInfo)
{
    WebAppNotificationProvider *provider = (__bridge WebAppNotificationProvider *)clientInfo;
    if ([provider webKitManager] == manager) [provider setWebKitManager:NULL];
}

static WKDictionaryRef WebAppNotificationPermissions(const void *clientInfo)
{
    return [(__bridge WebAppNotificationProvider *)clientInfo copyNotificationPermissions];
}

static void WebAppNotificationClear(WKArrayRef notificationIDs, const void *clientInfo)
{
    [(__bridge WebAppNotificationProvider *)clientInfo clearNotificationIDs:notificationIDs];
}

static void WebAppGeolocationStartUpdating(WKGeolocationManagerRef manager,
                                           const void *clientInfo)
{
    (void)manager;
    WebAppGeolocationProvider *provider =
        (__bridge WebAppGeolocationProvider *)clientInfo;
    [provider startUpdating];
}

static void WebAppGeolocationStopUpdating(WKGeolocationManagerRef manager,
                                          const void *clientInfo)
{
    (void)manager;
    WebAppGeolocationProvider *provider =
        (__bridge WebAppGeolocationProvider *)clientInfo;
    [provider stopUpdating];
}

static void WebAppGeolocationSetEnableHighAccuracy(WKGeolocationManagerRef manager,
                                                   bool enabled,
                                                   const void *clientInfo)
{
    (void)manager;
    WebAppGeolocationProvider *provider =
        (__bridge WebAppGeolocationProvider *)clientInfo;
    [provider setHighAccuracyEnabled:enabled];
}

static NSString *HistoryTrackingJavaScript(void)
{
    return
        @"(function(){"
         "if(window.__webAppHistoryBridgeInstalled)return;"
         "window.__webAppHistoryBridgeInstalled=true;"
         "var routeTimer=0,titleTimer=0;"
         "function post(){"
           "try{window.webkit.messageHandlers.webAppHistory.postMessage({"
             "url:String(location.href),title:String(document.title||'')});"
           "}catch(e){}"
         "}"
         "function titleChanged(){"
           "clearTimeout(routeTimer);clearTimeout(titleTimer);"
           "titleTimer=setTimeout(post,50);"
         "}"
         "function routeChanged(){"
           "clearTimeout(routeTimer);"
           "routeTimer=setTimeout(post,5000);"
         "}"
         "function observeTitle(){"
           "if(!document.head){setTimeout(observeTitle,25);return;}"
           "new MutationObserver(titleChanged).observe(document.head,{"
             "subtree:true,childList:true,characterData:true});"
         "}"
         "['pushState','replaceState'].forEach(function(name){"
           "var original=history[name];"
           "history[name]=function(){"
             "var result=original.apply(this,arguments);routeChanged();return result;"
           "};"
         "});"
         "addEventListener('popstate',routeChanged);"
         "addEventListener('hashchange',routeChanged);"
         "addEventListener('pageshow',titleChanged);"
         "observeTitle();"
         "if(document.readyState==='loading')"
           "addEventListener('DOMContentLoaded',titleChanged,{once:true});"
         "else titleChanged();"
        "})();";
}

static NSString *CleanHistoryTitle(NSString *title, NSString *appName)
{
    if (![title isKindOfClass:[NSString class]]) return @"";
    NSString *cleaned = [title stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([appName length]) {
        NSArray *suffixes = [NSArray arrayWithObjects:
            [@"- " stringByAppendingString:appName],
            [@"| " stringByAppendingString:appName], nil];
        for (NSString *suffix in suffixes) {
            if ([cleaned hasSuffix:suffix]) {
                cleaned = [[cleaned substringToIndex:[cleaned length] - [suffix length]]
                    stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                break;
            }
        }
    }
    return cleaned;
}

static CGFloat NumberSetting(NSDictionary *settings, NSString *key, CGFloat fallback)
{
    id value = [settings objectForKey:key];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        double number = [value doubleValue];
        return number > 0 ? (CGFloat)number : fallback;
    }
    return fallback;
}

static BOOL BoolSetting(NSDictionary *settings, NSString *key, BOOL fallback)
{
    id value = [settings objectForKey:key];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}

static char WebAppForwardedEditEventKey;

static NSString *KeyEquivalentForEditCommand(WebAppEditCommand command)
{
    switch (command) {
    case WebAppEditCommandUndo: return @"z";
    case WebAppEditCommandRedo: return @"Z";
    case WebAppEditCommandCut: return @"x";
    case WebAppEditCommandCopy: return @"c";
    case WebAppEditCommandPaste: return @"v";
    case WebAppEditCommandSelectAll: return @"a";
    case WebAppEditCommandFind: return @"f";
    }
    return @"";
}

static NSUInteger ModifierMaskForEditCommand(WebAppEditCommand command)
{
    return NSCommandKeyMask |
        (command == WebAppEditCommandRedo ? NSShiftKeyMask : 0);
}

static unsigned short KeyCodeForEditCommand(WebAppEditCommand command)
{
    /* ANSI virtual key codes for A, Z, X, C, V, and F. */
    switch (command) {
    case WebAppEditCommandSelectAll: return 0;
    case WebAppEditCommandFind: return 3;
    case WebAppEditCommandUndo:
    case WebAppEditCommandRedo: return 6;
    case WebAppEditCommandCut: return 7;
    case WebAppEditCommandCopy: return 8;
    case WebAppEditCommandPaste: return 9;
    }
    return 0;
}

static SEL NativeActionForEditCommand(WebAppEditCommand command)
{
    switch (command) {
    case WebAppEditCommandUndo: return @selector(undo:);
    case WebAppEditCommandRedo: return @selector(redo:);
    case WebAppEditCommandCut: return @selector(cut:);
    case WebAppEditCommandCopy: return @selector(copy:);
    case WebAppEditCommandPaste: return @selector(paste:);
    case WebAppEditCommandSelectAll: return @selector(selectAll:);
    case WebAppEditCommandFind: return @selector(performTextFinderAction:);
    }
    return NULL;
}

static NSUInteger WebAppKeyboardModifierMask(NSUInteger modifiers)
{
    return modifiers & (NSCommandKeyMask | NSAlternateKeyMask |
                        NSControlKeyMask | NSShiftKeyMask);
}

static NSString *LowercaseKeyEquivalent(NSString *keyEquivalent)
{
    return [keyEquivalent length] ? [keyEquivalent lowercaseString] : @"";
}

static BOOL EventMatchesEditCommand(NSEvent *event, WebAppEditCommand command)
{
    if ([event type] != NSKeyDown) return NO;
    NSString *characters = LowercaseKeyEquivalent([event charactersIgnoringModifiers]);
    return [characters isEqualToString:
            LowercaseKeyEquivalent(KeyEquivalentForEditCommand(command))] &&
           WebAppKeyboardModifierMask([event modifierFlags]) ==
            ModifierMaskForEditCommand(command);
}

static NSUInteger EffectiveModifierMaskForMenuItem(NSMenuItem *item)
{
    NSUInteger modifiers = WebAppKeyboardModifierMask([item keyEquivalentModifierMask]);
    NSString *keyEquivalent = [item keyEquivalent];
    if ([keyEquivalent length]) {
        NSString *lowercase = [keyEquivalent lowercaseString];
        if (![keyEquivalent isEqualToString:lowercase]) modifiers |= NSShiftKeyMask;
    }
    return modifiers;
}

static BOOL MenuItemUsesEditCommandKeyEquivalent(NSMenuItem *item,
                                                  WebAppEditCommand command)
{
    return [LowercaseKeyEquivalent([item keyEquivalent]) isEqualToString:
            LowercaseKeyEquivalent(KeyEquivalentForEditCommand(command))] &&
           EffectiveModifierMaskForMenuItem(item) == ModifierMaskForEditCommand(command);
}

static BOOL MenuContainsKeyEquivalentForEvent(NSMenu *menu, NSEvent *event)
{
    NSString *characters = LowercaseKeyEquivalent([event charactersIgnoringModifiers]);
    NSUInteger modifiers = WebAppKeyboardModifierMask([event modifierFlags]);
    for (NSMenuItem *item in [menu itemArray]) {
        if (![item isSeparatorItem] && ![item isHidden] && [item isEnabled] &&
            [LowercaseKeyEquivalent([item keyEquivalent]) isEqualToString:characters] &&
            EffectiveModifierMaskForMenuItem(item) == modifiers) return YES;
        if ([item submenu] && MenuContainsKeyEquivalentForEvent([item submenu], event))
            return YES;
    }
    return NO;
}

static NSEvent *EventForEditCommand(WebAppEditCommand command, NSWindow *window)
{
    NSString *keyEquivalent = KeyEquivalentForEditCommand(command);
    NSString *characters = command == WebAppEditCommandRedo ? @"Z" :
                           [keyEquivalent lowercaseString];
    return [NSEvent keyEventWithType:NSKeyDown
                            location:NSZeroPoint
                       modifierFlags:ModifierMaskForEditCommand(command)
                           timestamp:[[NSProcessInfo processInfo] systemUptime]
                        windowNumber:[window windowNumber]
                             context:[NSGraphicsContext currentContext]
                          characters:characters
         charactersIgnoringModifiers:[keyEquivalent lowercaseString]
                           isARepeat:NO
                             keyCode:KeyCodeForEditCommand(command)];
}

static BOOL ConfiguredMenuHasItemsOtherThanTitle(NSDictionary *settings, NSString *key,
                                                  NSString *excludedTitle)
{
    id groups = [settings objectForKey:key];
    if (![groups isKindOfClass:[NSArray class]]) return NO;
    for (id group in groups) {
        if (![group isKindOfClass:[NSDictionary class]]) continue;
        for (id title in group) {
            if ([title isKindOfClass:[NSString class]] &&
                ![title isEqualToString:excludedTitle] &&
                [[group objectForKey:title] isKindOfClass:[NSString class]]) return YES;
        }
    }
    return NO;
}

static NSArray *NumericVersionComponents(NSString *version)
{
    NSMutableArray *parts = [NSMutableArray array];
    NSArray *rawParts = [version componentsSeparatedByString:@"."];
    for (NSString *part in rawParts) {
        NSScanner *scanner = [NSScanner scannerWithString:part];
        NSInteger value = 0;
        [scanner scanInteger:&value];
        [parts addObject:[NSNumber numberWithInteger:value]];
    }
    return parts;
}

static NSComparisonResult CompareVersions(NSString *installed, NSString *minimum)
{
    NSArray *left = NumericVersionComponents(installed);
    NSArray *right = NumericVersionComponents(minimum);
    NSUInteger count = MAX([left count], [right count]);
    for (NSUInteger i = 0; i < count; i++) {
        NSInteger a = i < [left count] ? [[left objectAtIndex:i] integerValue] : 0;
        NSInteger b = i < [right count] ? [[right objectAtIndex:i] integerValue] : 0;
        if (a < b) return NSOrderedAscending;
        if (a > b) return NSOrderedDescending;
    }
    return NSOrderedSame;
}

@implementation WebAppApplication

- (void)sendEvent:(NSEvent *)event
{
    NSNumber *forwardedCommand = objc_getAssociatedObject(
        event, &WebAppForwardedEditEventKey);
    id delegate = [self delegate];
    if (forwardedCommand &&
        [delegate respondsToSelector:@selector(performNativeEditCommand:)]) {
        objc_setAssociatedObject(event, &WebAppForwardedEditEventKey, nil,
                                 OBJC_ASSOCIATION_ASSIGN);
        [delegate performNativeEditCommand:
            (WebAppEditCommand)[forwardedCommand integerValue]];
        return;
    }

    if ([event type] == NSKeyDown &&
        [delegate respondsToSelector:@selector(shouldSuppressWebEditKeyEvent:)] &&
        [delegate shouldSuppressWebEditKeyEvent:event]) return;

    [super sendEvent:event];
}

@end

static Class BackportedWKWebViewClass(void)
{
    Class wkClass = NSClassFromString(@"WKWebView");
    if (wkClass) return wkClass;

    /* Mavericks packages the backported modern API in this private framework. */
    NSBundle *webKit2 = [NSBundle bundleWithPath:
        @"/System/Library/PrivateFrameworks/WebKit2.framework"];
    @try {
        [webKit2 load];
    } @catch (NSException *exception) {
        (void)exception;
    }
    return NSClassFromString(@"WKWebView");
}

static NSString *JavaScriptStringLiteral(NSString *string)
{
    if (!string) return @"\"\"";
    NSData *data = [NSJSONSerialization dataWithJSONObject:[NSArray arrayWithObject:string]
                                                   options:0 error:NULL];
    NSString *array = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([array length] >= 2)
        return [array substringWithRange:NSMakeRange(1, [array length] - 2)];
    return @"\"\"";
}

static BOOL IsBareContextMenuElement(id element)
{
    id hitTestResult = [element respondsToSelector:@selector(hitTestResult)] ?
                       [element hitTestResult] : element;
    if (!hitTestResult) return YES;

    if ([hitTestResult respondsToSelector:@selector(absoluteImageURL)] &&
        [hitTestResult absoluteImageURL]) return NO;
    if ([hitTestResult respondsToSelector:@selector(absolutePDFURL)] &&
        [hitTestResult absolutePDFURL]) return NO;
    if ([hitTestResult respondsToSelector:@selector(absoluteLinkURL)] &&
        [hitTestResult absoluteLinkURL]) return NO;
    if ([hitTestResult respondsToSelector:@selector(absoluteMediaURL)] &&
        [hitTestResult absoluteMediaURL]) return NO;
    if ([hitTestResult respondsToSelector:@selector(lookupText)] &&
        [[hitTestResult lookupText] length]) return NO;
    if ([hitTestResult respondsToSelector:@selector(isContentEditable)] &&
        [hitTestResult isContentEditable]) return NO;
    if ([hitTestResult respondsToSelector:@selector(isSelected)] &&
        [hitTestResult isSelected]) return NO;
    return YES;
}

static NSMenu *ContextMenuByRemovingNavigationItems(NSMenu *proposedMenu, id element)
{
    if (!proposedMenu) return proposedMenu;

    BOOL bareElement = IsBareContextMenuElement(element);
    NSMenu *menu = [proposedMenu copy];
    for (NSInteger index = [menu numberOfItems] - 1; index >= 0; index--) {
        NSMenuItem *item = [menu itemAtIndex:index];
        NSString *actionName = [item action] ? NSStringFromSelector([item action]) : @"";
        NSString *title = [item title];
        BOOL isBackOrForward =
            [title caseInsensitiveCompare:@"Back"] == NSOrderedSame ||
            [title caseInsensitiveCompare:@"Forward"] == NSOrderedSame ||
            [actionName rangeOfString:@"goBack"
                              options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [actionName rangeOfString:@"goForward"
                              options:NSCaseInsensitiveSearch].location != NSNotFound;
        BOOL isReload = bareElement &&
            ([actionName rangeOfString:@"reload"
                               options:NSCaseInsensitiveSearch].location != NSNotFound ||
             [title caseInsensitiveCompare:@"Reload"] == NSOrderedSame);
        if (isBackOrForward || isReload) [menu removeItemAtIndex:index];
    }

    BOOL previousWasSeparator = YES;
    for (NSInteger index = [menu numberOfItems] - 1; index >= 0; index--) {
        NSMenuItem *item = [menu itemAtIndex:index];
        if ([item isSeparatorItem] && previousWasSeparator)
            [menu removeItemAtIndex:index];
        else
            previousWasSeparator = [item isSeparatorItem];
    }
    if ([menu numberOfItems] && [[menu itemAtIndex:0] isSeparatorItem])
        [menu removeItemAtIndex:0];
    return menu;
}

static BOOL ConfigureWebPush(id configuration)
{
    id preferences = [configuration preferences];
    id webpagePreferences = [configuration defaultWebpagePreferences];
    @try {
        [preferences _setNotificationsEnabled:YES];
        [preferences _setPushAPIEnabled:YES];
        [preferences _setNotificationEventEnabled:YES];
        [webpagePreferences _setPushAndNotificationAPIEnabled:YES];

        /*
         * WebKit's built-in notification delivery answers page-level
         * permission checks through webpushd, which on this system reports
         * every page origin as denied and never consults the app. With the
         * feature off, page permissions come from the website data store
         * delegate and page notifications reach WebAppNotificationProvider.
         */
        BOOL builtInNotificationsDisabled = YES;
        Class preferencesClass = [preferences class];
        if ([preferencesClass respondsToSelector:@selector(_features)]) {
            for (id feature in [preferencesClass _features]) {
                NSString *name = [feature respondsToSelector:@selector(name)] ?
                                 [feature name] : @"";
                NSString *key = [feature respondsToSelector:@selector(key)] ?
                                [feature key] : @"";
                if ([name isEqualToString:@"Built-In Web Notifications"] ||
                    [key isEqualToString:@"BuiltInNotificationsEnabled"]) {
                    [preferences _setEnabled:NO forFeature:feature];
                    builtInNotificationsDisabled =
                        ![preferences _isEnabledForFeature:feature];
                    break;
                }
            }
        }

        return [preferences _notificationsEnabled] &&
               [preferences _pushAPIEnabled] &&
               [preferences _notificationEventEnabled] &&
               [webpagePreferences _pushAndNotificationAPIEnabled] &&
               builtInNotificationsDisabled &&
               [[configuration websiteDataStore] isPersistent];
    } @catch (NSException *exception) {
        fprintf(stderr, "Web Push configuration failed: %s\n",
                [[exception reason] UTF8String]);
        return NO;
    }
}

static BOOL ConfigureAutomaticPermissions(id configuration, id dataStoreDelegate)
{
    id preferences = [configuration preferences];
    id dataStore = [configuration websiteDataStore];
    @try {
        BOOL clipboard = [preferences respondsToSelector:@selector(_setJavaScriptCanAccessClipboard:)];
        BOOL orientation = [preferences respondsToSelector:@selector(_setDeviceOrientationEventEnabled:)];
        BOOL secureCapture =
            [preferences respondsToSelector:@selector(_setMediaCaptureRequiresSecureConnection:)];
        BOOL supportsDataStoreDelegate = [dataStore respondsToSelector:@selector(set_delegate:)];
        if (!clipboard || !orientation || !secureCapture || !supportsDataStoreDelegate) {
            fprintf(stderr, "Automatic permission APIs: clipboard=%d orientation=%d "
                    "secure-capture=%d data-store-delegate=%d\n",
                    clipboard, orientation, secureCapture, supportsDataStoreDelegate);
            return NO;
        }

        [preferences _setJavaScriptCanAccessClipboard:YES];
        [preferences _setDeviceOrientationEventEnabled:YES];
        [preferences _setMediaCaptureRequiresSecureConnection:NO];
        BOOL geolocation = NO;
        Class preferencesClass = [preferences class];
        if ([preferencesClass respondsToSelector:@selector(_features)]) {
            for (id feature in [preferencesClass _features]) {
                NSString *name = [feature respondsToSelector:@selector(name)] ?
                                 [feature name] : @"";
                NSString *key = [feature respondsToSelector:@selector(key)] ?
                                [feature key] : @"";
                if ([name isEqualToString:@"Geolocation API"] ||
                    [key isEqualToString:@"GeolocationAPIEnabled"]) {
                    [preferences _setEnabled:YES forFeature:feature];
                    geolocation = [preferences _isEnabledForFeature:feature];
                    break;
                }
            }
        }
        [dataStore set_delegate:dataStoreDelegate];
        if ([dataStoreDelegate isKindOfClass:[WebAppDelegate class]])
            [(WebAppDelegate *)dataStoreDelegate setWebsiteDataStore:dataStore];

        return [preferences _javaScriptCanAccessClipboard] &&
               [preferences _deviceOrientationEventEnabled] &&
               ![preferences _mediaCaptureRequiresSecureConnection] &&
               geolocation;
    } @catch (NSException *exception) {
        fprintf(stderr, "Automatic permission configuration failed: %s\n",
                [[exception reason] UTF8String]);
        return NO;
    }
}

@implementation WebAppGeolocationProvider

- (id)initWithProcessPool:(id)processPool
{
    self = [super init];
    if (!self) return nil;

    self.processPool = processPool;
    if (!LoadWebKitGeolocationAPI()) return self;
    self.webKitManager = processPool ? WebAppWKContextGetGeolocationManager(
        (__bridge WKContextRef)processPool) : NULL;
    if (!self.webKitManager) return self;

    [self install];
    return self;
}

- (void)install
{
    if (!self.webKitManager) return;
    WKGeolocationProviderV1 provider = {
        { 1, (__bridge const void *)self },
        WebAppGeolocationStartUpdating,
        WebAppGeolocationStopUpdating,
        WebAppGeolocationSetEnableHighAccuracy
    };
    WebAppWKGeolocationManagerSetProvider(self.webKitManager, &provider.base);
    self.configured = YES;
}

- (void)dealloc
{
    [self stopUpdating];
    if (self.webKitManager)
        WebAppWKGeolocationManagerSetProvider(self.webKitManager, NULL);
}

- (void)startUpdating
{
    self.locationRequestsStarted = YES;
    if (self.testLocationEnabled) {
        CLLocation *location = [[CLLocation alloc]
            initWithCoordinate:CLLocationCoordinate2DMake(37.3349, -122.0090)
            altitude:10.0 horizontalAccuracy:5.0 verticalAccuracy:5.0
            timestamp:[NSDate date]];
        [self deliverLocation:location];
        return;
    }

    if (![CLLocationManager locationServicesEnabled]) {
        WebAppWKGeolocationManagerProviderDidFailToDeterminePosition(self.webKitManager);
        return;
    }

    if (!self.locationManager) {
        CLLocationManager *manager = [[CLLocationManager alloc] init];
        [manager setDelegate:self];
        [manager setPurpose:[NSString stringWithFormat:@"%@ uses your location for web content.",
            StringSetting([[NSBundle mainBundle] infoDictionary], @"CFBundleName")]];
        self.locationManager = manager;
    }
    [self.locationManager setDesiredAccuracy:self.highAccuracyEnabled ?
        kCLLocationAccuracyBest : kCLLocationAccuracyHundredMeters];
    [self.locationManager startUpdatingLocation];
}

- (void)stopUpdating
{
    [self.locationManager stopUpdatingLocation];
    [self.locationManager setDelegate:nil];
    self.locationManager = nil;
}

- (void)setHighAccuracyEnabled:(BOOL)enabled
{
    _highAccuracyEnabled = enabled;
    if (self.locationManager) {
        [self.locationManager setDesiredAccuracy:enabled ?
            kCLLocationAccuracyBest : kCLLocationAccuracyHundredMeters];
    }
}

- (void)deliverLocation:(CLLocation *)location
{
    if (!location || [location horizontalAccuracy] < 0 || !self.webKitManager) return;

    BOOL providesAltitude = [location verticalAccuracy] >= 0;
    BOOL providesHeading = [location course] >= 0;
    BOOL providesSpeed = [location speed] >= 0;
    WKGeolocationPositionRef position = WebAppWKGeolocationPositionCreate(
        [[location timestamp] timeIntervalSince1970],
        [location coordinate].latitude,
        [location coordinate].longitude,
        [location horizontalAccuracy],
        providesAltitude, [location altitude],
        providesAltitude, [location verticalAccuracy],
        providesHeading, [location course],
        providesSpeed, [location speed]);
    if (!position) return;
    WebAppWKGeolocationManagerProviderDidChangePosition(self.webKitManager, position);
    WebAppWKRelease(position);
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateLocations:(NSArray *)locations
{
    (void)manager;
    [self deliverLocation:[locations lastObject]];
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
    fromLocation:(CLLocation *)oldLocation
{
    (void)manager; (void)oldLocation;
    [self deliverLocation:newLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    (void)manager; (void)error;
    if (self.webKitManager)
        WebAppWKGeolocationManagerProviderDidFailToDeterminePosition(self.webKitManager);
}

@end

@implementation BrowserWindowController

- (id)initWithOwner:(WebAppDelegate *)owner URL:(NSURL *)url
{
    NSDictionary *settings = owner.configuration;
    CGFloat width = NumberSetting(settings, @"InitialWindowWidth", 1024);
    CGFloat height = NumberSetting(settings, @"InitialWindowHeight", 700);
    NSUInteger style = NSTitledWindowMask | NSClosableWindowMask |
                       NSMiniaturizableWindowMask | NSResizableWindowMask;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, width, height)
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (!self) return nil;

    self.appDelegate = owner;
    self.initialURL = url;
    [window setReleasedWhenClosed:NO];
    [window setDelegate:self];
    [window setTitle:StringSetting(settings, @"CFBundleName")];
    [window center];

    CGFloat minimumWidth = NumberSetting(settings, @"MinimumWindowWidth", 670);
    CGFloat minimumHeight = NumberSetting(settings, @"MinimumWindowHeight", 500);
    [window setContentMinSize:NSMakeSize(minimumWidth, minimumHeight)];

    CGFloat maximumWidth = NumberSetting(settings, @"MaximumWindowWidth", 0);
    CGFloat maximumHeight = NumberSetting(settings, @"MaximumWindowHeight", 0);
    if (maximumWidth > 0 || maximumHeight > 0) {
        NSSize maximum = NSMakeSize(maximumWidth > 0 ? maximumWidth : FLT_MAX,
                                    maximumHeight > 0 ? maximumHeight : FLT_MAX);
        [window setContentMaxSize:maximum];
        [window setCollectionBehavior:([window collectionBehavior] &
                                       ~NSWindowCollectionBehaviorFullScreenPrimary)];
    } else {
        [window setCollectionBehavior:([window collectionBehavior] |
                                       NSWindowCollectionBehaviorFullScreenPrimary)];
    }

    Class webViewClass = BackportedWKWebViewClass();
    Class configurationClass = NSClassFromString(@"WKWebViewConfiguration");
    Class userScriptClass = NSClassFromString(@"WKUserScript");
    id configuration = [[configurationClass alloc] init];
    if (!configuration || !webViewClass || !userScriptClass) return nil;
    if (!owner.processPool) {
        if (!LoadWebKitGeolocationAPI()) return nil;
        WKContextRef context = WebAppWKContextCreate();
        owner.processPool = (__bridge_transfer id)(void *)context;
    }
    if (!owner.processPool) return nil;
    [configuration setProcessPool:owner.processPool];
    self.webPushConfigured = ConfigureWebPush(configuration);
    self.automaticPermissionsConfigured = ConfigureAutomaticPermissions(configuration, owner);

    id preferences = [configuration preferences];
    @try {
        [preferences setValue:[NSNumber numberWithBool:owner.developerToolsEnabled]
                       forKey:@"developerExtrasEnabled"];
    } @catch (NSException *exception) {
        (void)exception;
    }

    id contentController = [configuration userContentController];
    [contentController addScriptMessageHandler:self name:WebAppHistoryMessageHandlerName];
    self.historyMessageHandlerConfigured = YES;
    id historyScript = [[userScriptClass alloc]
        initWithSource:HistoryTrackingJavaScript() injectionTime:0 forMainFrameOnly:YES];
    [contentController addUserScript:historyScript];

    NSBundle *bundle = [NSBundle mainBundle];
    NSString *cssPath = [bundle pathForResource:@"userContent" ofType:@"css"];
    NSString *css = [NSString stringWithContentsOfFile:cssPath
                                              encoding:NSUTF8StringEncoding error:NULL];
    if ([css length]) {
        NSString *source = [NSString stringWithFormat:
            @"(function(){var s=document.getElementById('__web_app_user_css');"
             "if(!s){s=document.createElement('style');s.id='__web_app_user_css';"
             "(document.head||document.documentElement).appendChild(s);}"
             "s.textContent=%@;})();", JavaScriptStringLiteral(css)];
        id script = [[userScriptClass alloc] initWithSource:source injectionTime:1
                                           forMainFrameOnly:YES];
        [contentController addUserScript:script];
        self.userCSSConfigured = YES;
    }

    NSString *jsPath = [bundle pathForResource:@"userContent" ofType:@"js"];
    NSString *js = [NSString stringWithContentsOfFile:jsPath
                                             encoding:NSUTF8StringEncoding error:NULL];
    if ([js length]) {
        id script = [[userScriptClass alloc] initWithSource:js injectionTime:1
                                           forMainFrameOnly:YES];
        [contentController addUserScript:script];
        self.userJavaScriptConfigured = YES;
    }

    self.webView = [[webViewClass alloc] initWithFrame:[[window contentView] bounds]
                                         configuration:configuration];
    if (!self.webView) return nil;
    if (!owner.geolocationProvider) {
        owner.processPool = [[self.webView configuration] processPool];
        owner.geolocationProvider = [[WebAppGeolocationProvider alloc]
            initWithProcessPool:owner.processPool];
    } else {
        [owner.geolocationProvider install];
    }
    if (!owner.geolocationProvider.configured) return nil;
    if (!owner.notificationProvider) {
        owner.notificationProvider = [[WebAppNotificationProvider alloc]
            initWithProcessPool:owner.processPool appDelegate:owner];
    }
    if (!owner.notificationProvider.configured) return nil;
    if ([self.webView respondsToSelector:@selector(_setMediaCaptureEnabled:)]) {
        [self.webView _setMediaCaptureEnabled:YES];
        self.automaticPermissionsConfigured = self.automaticPermissionsConfigured &&
                                              [self.webView _mediaCaptureEnabled];
    } else {
        self.automaticPermissionsConfigured = NO;
    }

    [(NSView *)self.webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.webView setNavigationDelegate:self];
    [self.webView setUIDelegate:self];
    [self.webView addObserver:self forKeyPath:@"title" options:0
                      context:WebAppHistoryObservationContext];
    self.observingHistoryProperties = YES;
    [[window contentView] addSubview:(NSView *)self.webView];

    [self.webView _setUsePlatformFindUI:YES];
    self.textFinder = [[NSTextFinder alloc] init];
    [self.textFinder setClient:[self.webView _ensureTextFinderClient]];
    [self.textFinder setFindBarContainer:self];
    [self.textFinder setIncrementalSearchingEnabled:YES];

    [self loadURL:url];
    return self;
}

- (NSURL *)currentURL
{
    NSURL *url = [self.webView URL];
    return url ?: self.initialURL;
}

- (void)loadURL:(NSURL *)url
{
    if (!url) return;
    [self.appDelegate grantNotificationPermissionForURL:url];
    self.initialURL = url;
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
}

- (void)evaluateJavaScript:(NSString *)script
{
    if ([script length])
        [self.webView evaluateJavaScript:script completionHandler:nil];
}

- (void)windowWillClose:(NSNotification *)notification
{
    (void)notification;
    if (self.observingHistoryProperties && self.webView) {
        [self.webView removeObserver:self forKeyPath:@"title"];
        self.observingHistoryProperties = NO;
    }
    if (self.historyMessageHandlerConfigured && self.webView) {
        [[[self.webView configuration] userContentController]
            removeScriptMessageHandlerForName:WebAppHistoryMessageHandlerName];
        self.historyMessageHandlerConfigured = NO;
    }
    [self.textFinder setClient:nil];
    [self.textFinder setFindBarContainer:nil];
    [self.webView setNavigationDelegate:nil];
    [self.webView setUIDelegate:nil];
    [(NSView *)self.webView removeFromSuperview];
    self.webView = nil;
    [self.appDelegate browserDidClose:self];
}

- (NSView *)findBarView
{
    return _findBarView;
}

- (BOOL)isFindBarVisible
{
    return _findBarVisible;
}

- (void)setFindBarView:(NSView *)view
{
    if (_findBarView == view) return;
    [_findBarView removeFromSuperview];
    _findBarView = view;
    if (_findBarVisible && _findBarView)
        [[[self window] contentView] addSubview:_findBarView];
    [self layoutFindBar];
}

- (void)setFindBarVisible:(BOOL)visible
{
    if (_findBarVisible == visible) return;
    _findBarVisible = visible;
    if (visible && self.findBarView) {
        if (![self.findBarView superview])
            [[[self window] contentView] addSubview:self.findBarView];
    } else {
        [self.findBarView removeFromSuperview];
    }
    [self layoutFindBar];
}

- (void)findBarViewDidChangeHeight
{
    [self layoutFindBar];
}

- (NSView *)contentView
{
    return (NSView *)self.webView;
}

- (void)layoutFindBar
{
    NSView *content = [[self window] contentView];
    NSRect bounds = [content bounds];
    CGFloat barHeight = self.isFindBarVisible && self.findBarView ?
                        NSHeight([self.findBarView frame]) : 0;
    if (barHeight > 0) {
        [self.findBarView setFrame:NSMakeRect(0, NSMaxY(bounds) - barHeight,
                                             NSWidth(bounds), barHeight)];
        [self.findBarView setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    }
    [(NSView *)self.webView setFrame:NSMakeRect(0, 0, NSWidth(bounds),
                                                MAX(0, NSHeight(bounds) - barHeight))];
}

- (void)webView:(id)sender didFinishNavigation:(id)navigation
{
    (void)navigation;
    self.navigationFinished = YES;
    NSString *title = [sender title];
    if ([title length]) [[self window] setTitle:title];
    [self.appDelegate recordHistoryURL:[sender URL] title:title];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
    change:(NSDictionary *)change context:(void *)context
{
    (void)keyPath; (void)change;
    if (context == WebAppHistoryObservationContext && object == self.webView) {
        [self.appDelegate recordHistoryURL:[self.webView URL] title:[self.webView title]];
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)userContentController:(id)userContentController
    didReceiveScriptMessage:(id)message
{
    (void)userContentController;
    id body = [message body];
    if (![body isKindOfClass:[NSDictionary class]]) return;
    NSString *urlString = [body objectForKey:@"url"];
    NSString *title = [body objectForKey:@"title"];
    if (![urlString isKindOfClass:[NSString class]] ||
        ![title isKindOfClass:[NSString class]]) return;

    NSURL *url = [NSURL URLWithString:urlString];
    if (![self.appDelegate isURLAllowedInApp:url]) return;
    if ([title length]) [[self window] setTitle:title];
    [self.appDelegate recordHistoryURL:url title:title];
}

/*
 * WebKit only honours a link's download attribute when the navigation delegate
 * answers with the download policy; allowing the navigation displays the
 * resource inline instead.
 */
- (void)webView:(id)sender decidePolicyForNavigationAction:(id)action
        decisionHandler:(void (^)(NSInteger))decisionHandler
{
    (void)sender;
    if ([action respondsToSelector:@selector(shouldPerformDownload)] &&
        [action shouldPerformDownload]) {
        decisionHandler(2); /* WKNavigationActionPolicyDownload */
        return;
    }
    id targetFrame = [action targetFrame];
    NSURL *url = [[action request] URL];
    if (!targetFrame || ![targetFrame isMainFrame] || [self.appDelegate isURLAllowedInApp:url]) {
        decisionHandler(1); /* WKNavigationActionPolicyAllow */
    } else {
        decisionHandler(0); /* WKNavigationActionPolicyCancel */
        [self.appDelegate openURLExternally:url];
    }
}

- (void)webView:(id)sender decidePolicyForNavigationResponse:(id<WebAppWKNavigationResponse>)response
        decisionHandler:(void (^)(NSInteger))decisionHandler
{
    (void)sender;
    if (![response canShowMIMEType] || ResponseIsAttachment([response response]))
        decisionHandler(2); /* WKNavigationResponsePolicyDownload */
    else
        decisionHandler(1); /* WKNavigationResponsePolicyAllow */
}

- (void)webView:(id)sender navigationAction:(id)action didBecomeDownload:(id<WebAppWKDownload>)download
{
    (void)sender; (void)action;
    [self.appDelegate beginDownload:download];
}

- (void)webView:(id)sender navigationResponse:(id)response didBecomeDownload:(id<WebAppWKDownload>)download
{
    (void)sender; (void)response;
    [self.appDelegate beginDownload:download];
}

- (id)webView:(id)sender createWebViewWithConfiguration:(id)configuration
        forNavigationAction:(id)action windowFeatures:(id)windowFeatures
{
    (void)sender; (void)configuration; (void)windowFeatures;
    if ([action targetFrame]) return nil;
    NSURL *url = [[action request] URL];
    if ([self.appDelegate isURLAllowedInApp:url])
        [self.appDelegate newBrowserWithURL:url];
    else
        [self.appDelegate openURLExternally:url];
    return nil;
}

- (NSMenu *)_webView:(id)webView contextMenu:(NSMenu *)menu forElement:(id)element
{
    (void)webView;
    return ContextMenuByRemovingNavigationItems(menu, element);
}

- (void)_webView:(id)webView requestNotificationPermissionForSecurityOrigin:(id)origin
    decisionHandler:(void (^)(BOOL allowed))decisionHandler
{
    (void)webView;
    [self.appDelegate grantNotificationPermissionForSecurityOrigin:origin];
    decisionHandler(YES);
}

- (void)webView:(id)webView requestMediaCapturePermissionForOrigin:(id)origin
    initiatedByFrame:(id)frame type:(NSInteger)type
    decisionHandler:(void (^)(NSInteger decision))decisionHandler
{
    (void)webView; (void)origin; (void)frame; (void)type;
    decisionHandler(WebAppPermissionDecisionGrant);
}

- (void)_webView:(id)webView requestUserMediaAuthorizationForDevices:(NSUInteger)devices
    url:(NSURL *)url mainFrameURL:(NSURL *)mainFrameURL
    decisionHandler:(void (^)(BOOL authorized))decisionHandler
{
    (void)webView; (void)devices; (void)url; (void)mainFrameURL;
    decisionHandler(YES);
}

- (void)webView:(id)webView requestGeolocationPermissionForOrigin:(id)origin
    initiatedByFrame:(id)frame decisionHandler:(void (^)(NSInteger decision))decisionHandler
{
    (void)webView; (void)origin; (void)frame;
    self.geolocationPermissionRequestsHandled = YES;
    self.geolocationPermissionDelegateVariant = 1;
    decisionHandler(WebAppPermissionDecisionGrant);
}

- (void)_webView:(id)webView requestGeolocationPermissionForOrigin:(id)origin
    initiatedByFrame:(id)frame decisionHandler:(void (^)(NSInteger decision))decisionHandler
{
    (void)webView; (void)origin; (void)frame;
    self.geolocationPermissionRequestsHandled = YES;
    self.geolocationPermissionDelegateVariant = 2;
    decisionHandler(WebAppPermissionDecisionGrant);
}

- (void)_webView:(id)webView requestGeolocationPermissionForFrame:(id)frame
    decisionHandler:(void (^)(BOOL allowed))decisionHandler
{
    (void)webView; (void)frame;
    self.geolocationPermissionRequestsHandled = YES;
    self.geolocationPermissionDelegateVariant = 3;
    decisionHandler(YES);
}

- (void)webView:(id)webView requestDeviceOrientationAndMotionPermissionForOrigin:(id)origin
    initiatedByFrame:(id)frame decisionHandler:(void (^)(NSInteger decision))decisionHandler
{
    (void)webView; (void)origin; (void)frame;
    decisionHandler(WebAppPermissionDecisionGrant);
}

- (void)_webView:(id)webView requestDisplayCapturePermissionForOrigin:(id)origin
    initiatedByFrame:(id)frame withSystemAudio:(BOOL)withSystemAudio
    decisionHandler:(void (^)(NSInteger decision))decisionHandler
{
    (void)webView; (void)origin; (void)frame; (void)withSystemAudio;
    decisionHandler(WebAppDisplayCapturePermissionDecisionScreenPrompt);
}

- (void)_webView:(id)webView decidePolicyForScreenCaptureUnmutingForOrigin:(id)origin
    initiatedByFrame:(id)frame decisionHandler:(void (^)(BOOL allowed))decisionHandler
{
    (void)webView; (void)origin; (void)frame;
    decisionHandler(YES);
}

- (void)_webView:(id)webView queryPermission:(NSString *)permission
    forOrigin:(id)origin completionHandler:(void (^)(NSInteger decision))completionHandler
{
    (void)webView; (void)permission; (void)origin;
    completionHandler(WebAppPermissionDecisionGrant);
}

- (void)_webView:(id)webView requestStorageAccessPanelForDomain:(NSString *)requestingDomain
    underCurrentDomain:(NSString *)currentDomain
    completionHandler:(void (^)(BOOL allowed))completionHandler
{
    (void)webView; (void)requestingDomain; (void)currentDomain;
    completionHandler(YES);
}

- (void)_webViewDidRequestPointerLock:(id)webView
    completionHandler:(void (^)(BOOL allowed))completionHandler
{
    (void)webView;
    completionHandler(YES);
}

- (void)_webView:(id)webView includeSensitiveMediaDeviceDetails:
    (void (^)(BOOL includeSensitiveDetails))decisionHandler
{
    (void)webView;
    decisionHandler(YES);
}

@end

@implementation WebAppNotificationProvider

- (id)initWithProcessPool:(id)processPool appDelegate:(WebAppDelegate *)appDelegate
{
    self = [super init];
    if (!self) return nil;

    self.processPool = processPool;
    self.appDelegate = appDelegate;
    self.identifiersByPageNotificationID = [NSMutableDictionary dictionary];
    if (!LoadWebKitNotificationAPI()) return self;
    self.webKitManager = processPool ? WebAppWKContextGetNotificationManager(
        (__bridge WKContextRef)processPool) : NULL;
    if (!self.webKitManager) return self;

    [self install];
    return self;
}

- (void)install
{
    if (!self.webKitManager) return;
    WKNotificationProviderV0 provider = {
        { 0, (__bridge const void *)self },
        WebAppNotificationShow,
        WebAppNotificationCancel,
        WebAppNotificationDidDestroy,
        WebAppNotificationAddManager,
        WebAppNotificationRemoveManager,
        WebAppNotificationPermissions,
        WebAppNotificationClear
    };
    WebAppWKNotificationManagerSetProvider(self.webKitManager, &provider.base);
    self.configured = YES;
}

- (void)dealloc
{
    if (self.webKitManager)
        WebAppWKNotificationManagerSetProvider(self.webKitManager, NULL);
}

- (void)showNotification:(WKNotificationRef)notification
{
    if (!notification) return;
    uint64_t notificationID = WebAppWKNotificationGetID(notification);
    NSString *title = WebAppStringFromWKString(WebAppWKNotificationCopyTitle(notification));
    NSString *body = WebAppStringFromWKString(WebAppWKNotificationCopyBody(notification));
    WKSecurityOriginRef securityOrigin = WebAppWKNotificationGetSecurityOrigin(notification);
    NSString *origin = securityOrigin ?
        WebAppStringFromWKString(WebAppWKSecurityOriginCopyToString(securityOrigin)) : nil;
    BOOL silent = WebAppWKNotificationGetAlert(notification) == WebAppWKNotificationAlertSilent;
    NSNumber *pageID = [NSNumber numberWithUnsignedLongLong:notificationID];
    NSMutableDictionary *record = [NSMutableDictionary dictionary];
    [record setObject:WebAppNotificationKindPage forKey:WebAppNotificationKindKey];
    [record setObject:pageID forKey:WebAppNotificationPageIDKey];
    if (origin) [record setObject:origin forKey:WebAppNotificationOriginKey];
    NSString *identifier = [self.appDelegate deliverNotificationWithTitle:title body:body
        silent:silent origin:origin record:record];
    if (identifier) [self.identifiersByPageNotificationID setObject:identifier forKey:pageID];
    if (self.webKitManager)
        WebAppWKNotificationManagerProviderDidShowNotification(self.webKitManager,
                                                                notificationID);
}

- (void)removeDeliveredPageNotificationWithID:(uint64_t)notificationID
{
    NSNumber *pageID = [NSNumber numberWithUnsignedLongLong:notificationID];
    NSString *identifier = [self.identifiersByPageNotificationID objectForKey:pageID];
    if (!identifier) return;
    [self.appDelegate removeDeliveredNotificationWithIdentifier:identifier];
    [self.identifiersByPageNotificationID removeObjectForKey:pageID];
}

- (void)cancelNotification:(WKNotificationRef)notification
{
    if (!notification) return;
    uint64_t notificationID = WebAppWKNotificationGetID(notification);
    [self removeDeliveredPageNotificationWithID:notificationID];
    if (!self.webKitManager) return;
    WKUInt64Ref value = WebAppWKUInt64Create(notificationID);
    WKTypeRef values[1] = { value };
    WKArrayRef notificationIDs = WebAppWKArrayCreate(values, 1);
    WebAppWKNotificationManagerProviderDidCloseNotifications(self.webKitManager,
                                                              notificationIDs);
    if (notificationIDs) WebAppWKRelease(notificationIDs);
    if (value) WebAppWKRelease(value);
}

- (void)forgetNotification:(WKNotificationRef)notification
{
    if (!notification) return;
    NSNumber *pageID = [NSNumber numberWithUnsignedLongLong:
                        WebAppWKNotificationGetID(notification)];
    NSString *identifier = [self.identifiersByPageNotificationID objectForKey:pageID];
    if (!identifier) return;
    [self.appDelegate forgetNotificationRecordWithIdentifier:identifier];
    [self.identifiersByPageNotificationID removeObjectForKey:pageID];
}

- (void)clearNotificationIDs:(WKArrayRef)notificationIDs
{
    if (!notificationIDs) return;
    size_t count = WebAppWKArrayGetSize(notificationIDs);
    for (size_t index = 0; index < count; index++) {
        WKUInt64Ref value = (WKUInt64Ref)WebAppWKArrayGetItemAtIndex(notificationIDs, index);
        if (value) [self removeDeliveredPageNotificationWithID:WebAppWKUInt64GetValue(value)];
    }
}

- (WKDictionaryRef)copyNotificationPermissions
{
    WKMutableDictionaryRef permissions = WebAppWKMutableDictionaryCreate();
    if (!permissions) return NULL;
    for (NSString *origin in [self.appDelegate grantedNotificationOriginStrings]) {
        WKStringRef key = WebAppWKStringCreateWithCFString((__bridge CFStringRef)origin);
        WKBooleanRef granted = WebAppWKBooleanCreate(true);
        if (key && granted) WebAppWKDictionarySetItem(permissions, key, granted);
        if (key) WebAppWKRelease(key);
        if (granted) WebAppWKRelease(granted);
    }
    return permissions;
}

- (void)pageNotificationWithIDWasClicked:(uint64_t)notificationID
{
    [self.identifiersByPageNotificationID removeObjectForKey:
        [NSNumber numberWithUnsignedLongLong:notificationID]];
    if (self.webKitManager)
        WebAppWKNotificationManagerProviderDidClickNotification(self.webKitManager,
                                                                 notificationID);
}

@end

@implementation WebAppDelegate

- (id)init
{
    self = [super init];
    if (self) {
        self.configuration = [[NSBundle mainBundle] infoDictionary];
        self.browsers = [NSMutableArray array];
        NSArray *savedHistory = [[NSUserDefaults standardUserDefaults]
            arrayForKey:WebAppHistoryDefaultsKey];
        self.history = savedHistory ? [savedHistory mutableCopy] : [NSMutableArray array];
        self.grantedNotificationOrigins = [NSMutableSet set];
        self.notificationRecords = [NSMutableDictionary dictionary];
        self.downloadDestinations = [NSMapTable strongToStrongObjectsMapTable];
        self.homeURL = [NSURL URLWithString:StringSetting(self.configuration, @"URL")];
        [self grantNotificationPermissionForURL:self.homeURL];
        self.terminateAfterLastWindowClosed = BoolSetting(self.configuration,
                                                          @"TerminateAfterLastWindowClosed", YES);
        self.developerToolsEnabled = BoolSetting(self.configuration, @"AllowDeveloperTools", NO);
    }
    return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    (void)notification;
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    [self buildMenus];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    (void)notification;
    if (![self verifyWebKitVersion]) {
        [NSApp terminate:self];
        return;
    }

    NSString *urlString = StringSetting(self.configuration, @"URL");
    self.homeURL = [NSURL URLWithString:urlString];
    if (!self.homeURL || ![self.homeURL scheme]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"The application URL is invalid."];
        [alert setInformativeText:@"Set URL in Contents/Info.plist to an absolute URL, such as https://example.com."];
        [alert runModal];
        [NSApp terminate:self];
        return;
    }
    [self newBrowserWithURL:self.homeURL];
    [self pruneHistory];
    [self updateHistoryMenu];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return self.terminateAfterLastWindowClosed;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)visible
{
    (void)sender;
    if (!visible) [self newBrowserWithURL:self.homeURL];
    return YES;
}

- (BOOL)verifyWebKitVersion
{
    NSString *minimum = StringSetting(self.configuration, @"MinimumWebKitVersion");
    if (![minimum length]) minimum = @"0";

    Class webViewClass = BackportedWKWebViewClass();
    NSBundle *webKitBundle = webViewClass ? [NSBundle bundleForClass:webViewClass] : nil;
    if (!webKitBundle)
        webKitBundle = [NSBundle bundleWithPath:@"/System/Library/Frameworks/WebKit.framework"];
    NSString *installed = [webKitBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (![installed length])
        installed = [webKitBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (![installed length]) installed = @"0";

    if (webViewClass && CompareVersions(installed, minimum) != NSOrderedAscending) return YES;

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:[NSString stringWithFormat:
        @"This application requires WebKit %@ or later.", minimum]];
    [alert setInformativeText:[NSString stringWithFormat:
        @"You have WebKit %@. To use this application, you must install WebKit %@ or later.",
        installed, minimum]];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    return NO;
}

- (BrowserWindowController *)newBrowserWithURL:(NSURL *)url
{
    BrowserWindowController *browser = [[BrowserWindowController alloc] initWithOwner:self URL:url];
    if (!browser) return nil;
    [self.browsers addObject:browser];
    [browser showWindow:self];
    [[browser window] makeKeyAndOrderFront:self];
    return browser;
}

- (BrowserWindowController *)currentBrowser
{
    NSWindowController *controller = [[NSApp keyWindow] windowController];
    if ([controller isKindOfClass:[BrowserWindowController class]])
        return (BrowserWindowController *)controller;
    return [self.browsers lastObject];
}

- (BrowserWindowController *)browserForURL:(NSURL *)url
{
    NSString *urlString = [url absoluteString];
    if (![urlString length]) return nil;

    BrowserWindowController *current = [self currentBrowser];
    if ([[[current currentURL] absoluteString] isEqualToString:urlString]) return current;
    for (BrowserWindowController *browser in self.browsers) {
        if ([[[browser currentURL] absoluteString] isEqualToString:urlString])
            return browser;
    }
    return nil;
}

- (void)browserDidClose:(BrowserWindowController *)browser
{
    [self.browsers removeObject:browser];
}

- (void)pruneHistory
{
    NSString *appName = StringSetting(self.configuration, @"CFBundleName");
    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-WebAppHistoryMaximumAge];
    NSArray *sorted = [self.history sortedArrayUsingComparator:
        ^NSComparisonResult(id left, id right) {
            NSDate *leftDate = [left isKindOfClass:[NSDictionary class]] ?
                [left objectForKey:@"LastVisitTime"] : nil;
            NSDate *rightDate = [right isKindOfClass:[NSDictionary class]] ?
                [right objectForKey:@"LastVisitTime"] : nil;
            if (![leftDate isKindOfClass:[NSDate class]] &&
                ![rightDate isKindOfClass:[NSDate class]]) return NSOrderedSame;
            if (![leftDate isKindOfClass:[NSDate class]]) return NSOrderedDescending;
            if (![rightDate isKindOfClass:[NSDate class]]) return NSOrderedAscending;
            return [rightDate compare:leftDate];
        }];
    NSMutableArray *cleaned = [NSMutableArray array];
    NSMutableSet *seenTitles = [NSMutableSet set];
    NSMutableSet *seenURLs = [NSMutableSet set];

    for (id value in sorted) {
        if (![value isKindOfClass:[NSDictionary class]]) continue;
        NSString *urlString = [value objectForKey:@"URL"];
        NSDate *lastVisit = [value objectForKey:@"LastVisitTime"];
        NSString *title = CleanHistoryTitle([value objectForKey:@"Title"], appName);
        if (![urlString isKindOfClass:[NSString class]] ||
            ![lastVisit isKindOfClass:[NSDate class]] ||
            [lastVisit compare:cutoff] == NSOrderedAscending ||
            ![title length] ||
            ([appName length] &&
             [title rangeOfString:appName].location != NSNotFound)) continue;

        NSURL *url = [NSURL URLWithString:urlString];
        NSString *scheme = [[url scheme] lowercaseString];
        if ((![scheme isEqualToString:@"http"] &&
             ![scheme isEqualToString:@"https"]) ||
            ![self isURLAllowedInApp:url] ||
            [seenTitles containsObject:title] ||
            [seenURLs containsObject:urlString]) continue;

        [seenTitles addObject:title];
        [seenURLs addObject:urlString];
        [cleaned addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            title, @"Title", urlString, @"URL", lastVisit, @"LastVisitTime", nil]];
    }

    self.history = cleaned;
    [[NSUserDefaults standardUserDefaults] setObject:self.history
                                             forKey:WebAppHistoryDefaultsKey];
}

- (void)recordHistoryURL:(NSURL *)url title:(NSString *)title
{
    if (!BoolSetting(self.configuration, @"EnableHistoryMenu", YES) ||
        !url || ![self isURLAllowedInApp:url]) return;
    NSString *scheme = [[url scheme] lowercaseString];
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return;

    NSString *appName = StringSetting(self.configuration, @"CFBundleName");
    NSString *cleanedTitle = CleanHistoryTitle(title, appName);
    if (![cleanedTitle length] ||
        ([appName length] &&
         [cleanedTitle rangeOfString:appName].location != NSNotFound)) return;

    [self pruneHistory];
    NSString *urlString = [url absoluteString];
    for (NSInteger index = [self.history count] - 1; index >= 0; index--) {
        NSDictionary *entry = [self.history objectAtIndex:index];
        if ([[entry objectForKey:@"Title"] isEqualToString:cleanedTitle] ||
            [[entry objectForKey:@"URL"] isEqualToString:urlString])
            [self.history removeObjectAtIndex:index];
    }
    [self.history insertObject:[NSDictionary dictionaryWithObjectsAndKeys:
        cleanedTitle, @"Title", urlString, @"URL",
        [NSDate date], @"LastVisitTime", nil] atIndex:0];
    [[NSUserDefaults standardUserDefaults] setObject:self.history
                                             forKey:WebAppHistoryDefaultsKey];
}

- (void)updateHistoryMenu
{
    if (!self.historyMenu) return;
    while ([self.historyMenu numberOfItems] > 2)
        [self.historyMenu removeItemAtIndex:2];

    NSUInteger count = MIN([self.history count], WebAppHistoryMenuMaximumItems);
    if (!count) return;
    [self.historyMenu addItem:[NSMenuItem separatorItem]];
    NSString *currentURL = [[[[self currentBrowser] currentURL] absoluteString] copy];
    for (NSUInteger index = 0; index < count; index++) {
        NSDictionary *entry = [self.history objectAtIndex:index];
        NSMenuItem *item = [self.historyMenu
            addItemWithTitle:[entry objectForKey:@"Title"]
                      action:@selector(openHistoryItem:) keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:[entry objectForKey:@"URL"]];
        if ([[entry objectForKey:@"URL"] isEqualToString:currentURL])
            [item setState:NSOnState];
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    if (menu != self.historyMenu) return;
    [self pruneHistory];
    [self updateHistoryMenu];
}

- (void)openHistoryItem:(NSMenuItem *)sender
{
    NSURL *url = [NSURL URLWithString:[sender representedObject]];
    if (!url || ![self isURLAllowedInApp:url]) return;
    BrowserWindowController *openBrowser = [self browserForURL:url];
    if (openBrowser) {
        [openBrowser showWindow:self];
        [[openBrowser window] makeKeyAndOrderFront:self];
        [NSApp activateIgnoringOtherApps:YES];
        return;
    }
    BrowserWindowController *browser = [self currentBrowser];
    if (browser) [browser loadURL:url];
    else [self newBrowserWithURL:url];
}

- (void)grantNotificationPermissionForURL:(NSURL *)url
{
    NSString *origin = OriginStringForURL(url);
    if (!origin) return;
    @synchronized (self.grantedNotificationOrigins) {
        [self.grantedNotificationOrigins addObject:origin];
    }
}

- (void)grantNotificationPermissionForSecurityOrigin:(id)origin
{
    if (!origin) return;
    id<WebAppWKSecurityOrigin> securityOrigin = origin;
    NSString *originString = OriginString([securityOrigin protocol],
        [securityOrigin host], [securityOrigin port]);
    if (!originString) return;
    @synchronized (self.grantedNotificationOrigins) {
        [self.grantedNotificationOrigins addObject:originString];
    }
}

- (NSArray *)grantedNotificationOriginStrings
{
    @synchronized (self.grantedNotificationOrigins) {
        return [self.grantedNotificationOrigins allObjects];
    }
}

- (NSDictionary *)notificationPermissionsForWebsiteDataStore:(id)dataStore
{
    (void)dataStore;
    NSMutableDictionary *permissions = [NSMutableDictionary dictionary];
    for (NSString *origin in [self grantedNotificationOriginStrings])
        [permissions setObject:[NSNumber numberWithBool:YES] forKey:origin];
    return permissions;
}

- (NSString *)deliverNotificationWithTitle:(NSString *)title body:(NSString *)body
    silent:(BOOL)silent origin:(NSString *)origin record:(NSDictionary *)record
{
    NSString *identifier = [[NSUUID UUID] UUIDString];
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    [notification setTitle:[title length] ? title : StringSetting(self.configuration, @"CFBundleName")];
    [notification setInformativeText:body ?: @""];
    [notification setIdentifier:identifier];
    if (!silent) [notification setSoundName:NSUserNotificationDefaultSoundName];

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:identifier forKey:WebAppNotificationRecordKey];
    if (origin) [userInfo setObject:origin forKey:WebAppNotificationOriginKey];
    [notification setUserInfo:userInfo];
    [self.notificationRecords setObject:(record ?: [NSDictionary dictionary])
                                 forKey:identifier];
    [[NSUserNotificationCenter defaultUserNotificationCenter]
        deliverNotification:notification];
    return identifier;
}

- (void)forgetNotificationRecordWithIdentifier:(NSString *)identifier
{
    if (identifier) [self.notificationRecords removeObjectForKey:identifier];
}

- (void)removeDeliveredNotificationWithIdentifier:(NSString *)identifier
{
    if (!identifier) return;
    NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
    for (NSUserNotification *notification in [center deliveredNotifications]) {
        if ([[notification identifier] isEqualToString:identifier])
            [center removeDeliveredNotification:notification];
    }
    [self forgetNotificationRecordWithIdentifier:identifier];
}

- (NSDictionary *)recordForDeliveredNotification:(NSUserNotification *)notification
{
    NSString *identifier = [[notification userInfo] objectForKey:WebAppNotificationRecordKey];
    return identifier ? [self.notificationRecords objectForKey:identifier] : nil;
}

- (void)websiteDataStore:(id)dataStore showNotification:(id)notificationData
{
    (void)dataStore;
    NSMutableDictionary *record = [NSMutableDictionary dictionary];
    [record setObject:WebAppNotificationKindPersistent forKey:WebAppNotificationKindKey];
    NSDictionary *clickInfo = [notificationData userInfo];
    NSDictionary *representation = [notificationData dictionaryRepresentation];
    if (clickInfo) [record setObject:clickInfo forKey:WebAppNotificationClickInfoKey];
    if (representation)
        [record setObject:representation forKey:WebAppNotificationRepresentationKey];
    [self deliverNotificationWithTitle:[notificationData title]
                                  body:[notificationData body]
                                silent:[notificationData alert] == 1 /* _WKNotificationAlertSilent */
                                origin:[notificationData origin]
                                record:record];
}

- (void)websiteDataStore:(id)dataStore
    getDisplayedNotificationsForWorkerOrigin:(id)workerOrigin
    completionHandler:(void (^)(NSArray *notifications))completionHandler
{
    (void)dataStore;
    id<WebAppWKSecurityOrigin> securityOrigin = workerOrigin;
    NSString *requestedOrigin = securityOrigin ?
        OriginString([securityOrigin protocol], [securityOrigin host], [securityOrigin port]) : nil;
    NSMutableArray *representations = [NSMutableArray array];
    for (NSUserNotification *notification in
         [[NSUserNotificationCenter defaultUserNotificationCenter] deliveredNotifications]) {
        NSString *origin = [[notification userInfo] objectForKey:WebAppNotificationOriginKey];
        NSDictionary *representation = [[self recordForDeliveredNotification:notification]
            objectForKey:WebAppNotificationRepresentationKey];
        if (representation && (!requestedOrigin || [origin isEqualToString:requestedOrigin]))
            [representations addObject:representation];
    }
    completionHandler(representations);
}

- (void)websiteDataStore:(id)dataStore navigateToNotificationActionURL:(NSURL *)url
{
    (void)dataStore;
    if ([self isURLAllowedInApp:url]) [self newBrowserWithURL:url];
    else [self openURLExternally:url];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
    shouldPresentNotification:(NSUserNotification *)notification
{
    (void)center; (void)notification;
    return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center
    didActivateNotification:(NSUserNotification *)notification
{
    NSDictionary *record = [self recordForDeliveredNotification:notification];
    NSString *kind = [record objectForKey:WebAppNotificationKindKey];
    NSDictionary *clickInfo = [record objectForKey:WebAppNotificationClickInfoKey];
    if ([kind isEqualToString:WebAppNotificationKindPage]) {
        [self.notificationProvider pageNotificationWithIDWasClicked:
            [[record objectForKey:WebAppNotificationPageIDKey] unsignedLongLongValue]];
    } else if (clickInfo && [self.websiteDataStore
                             respondsToSelector:@selector(_processPersistentNotificationClick:
                                                           completionHandler:)]) {
        [self.websiteDataStore _processPersistentNotificationClick:clickInfo
            completionHandler:^(BOOL handled) { (void)handled; }];
    }
    [self forgetNotificationRecordWithIdentifier:
        [[notification userInfo] objectForKey:WebAppNotificationRecordKey]];
    [center removeDeliveredNotification:notification];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)requestBackgroundFetchPermission:(NSURL *)topOrigin
    frameOrigin:(NSURL *)frameOrigin decisionHandler:(void (^)(BOOL allowed))decisionHandler
{
    (void)topOrigin; (void)frameOrigin;
    decisionHandler(YES);
}

- (void)requestStorageSpace:(NSURL *)topOrigin frameOrigin:(NSURL *)frameOrigin
    quota:(unsigned long long)quota currentSize:(unsigned long long)currentSize
    spaceRequired:(unsigned long long)spaceRequired
    decisionHandler:(void (^)(unsigned long long newQuota))decisionHandler
{
    (void)topOrigin; (void)frameOrigin;
    unsigned long long needed = ULLONG_MAX - currentSize < spaceRequired ?
                                ULLONG_MAX : currentSize + spaceRequired;
    decisionHandler(MAX(quota, needed));
}

- (BOOL)isURLAllowedInApp:(NSURL *)url
{
    if (!url) return NO;
    NSString *absolute = [url absoluteString];
    if ([[url scheme] isEqualToString:@"about"] || [[url scheme] isEqualToString:@"data"] ||
        [[url scheme] isEqualToString:@"blob"])
        return YES;
    if ([[self.homeURL absoluteString] length] &&
        [absolute hasPrefix:[self.homeURL absoluteString]]) return YES;

    id values = [self.configuration objectForKey:@"InAppURLs"];
    if (![values isKindOfClass:[NSArray class]]) return NO;
    for (id value in values) {
        if (![value isKindOfClass:[NSString class]] || ![value length]) continue;
        NSString *pattern = [self regularExpressionForPattern:value];
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                     options:NSRegularExpressionCaseInsensitive
                                                                                       error:NULL];
        if ([expression firstMatchInString:absolute options:0
                                      range:NSMakeRange(0, [absolute length])]) return YES;
    }
    return NO;
}

- (NSString *)regularExpressionForPattern:(NSString *)input
{
    NSMutableString *result = [NSMutableString string];
    NSCharacterSet *escape = [NSCharacterSet characterSetWithCharactersInString:@". +?^$[]{}\\"];
    for (NSUInteger i = 0; i < [input length]; i++) {
        unichar c = [input characterAtIndex:i];
        if (c == '*') [result appendString:@".*"];
        else if (c == '|' || c == '(' || c == ')') [result appendFormat:@"%C", c];
        else {
            if ([escape characterIsMember:c]) [result appendString:@"\\"];
            [result appendFormat:@"%C", c];
        }
    }
    return result;
}

- (void)openURLExternally:(NSURL *)url
{
    if (url) [[NSWorkspace sharedWorkspace] openURL:url];
}

/*
 * WKDownload keeps only a weak reference to its delegate, so downloads are
 * owned here rather than by the window that started them, and they survive
 * that window closing.
 */
- (void)beginDownload:(id<WebAppWKDownload>)download
{
    if (!download) return;
    [self.downloadDestinations setObject:[NSNull null] forKey:download];
    [download setDelegate:self];
}

- (NSURL *)effectiveDownloadDirectoryURL
{
    if (self.downloadDirectoryURL) return self.downloadDirectoryURL;
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory,
                                                               NSUserDomainMask, YES);
    NSString *path = [directories count] ? [directories objectAtIndex:0] :
        [NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"];
    return [NSURL fileURLWithPath:path isDirectory:YES];
}

- (void)download:(id<WebAppWKDownload>)download decideDestinationUsingResponse:(NSURLResponse *)response
    suggestedFilename:(NSString *)suggestedFilename
    completionHandler:(void (^)(NSURL *destination))completionHandler
{
    (void)response;
    NSString *filename = [suggestedFilename lastPathComponent];
    if (![filename length] || [filename hasPrefix:@"."]) filename = @"Download";
    NSURL *directory = [self effectiveDownloadDirectoryURL];
    [[NSFileManager defaultManager] createDirectoryAtPath:[directory path]
        withIntermediateDirectories:YES attributes:nil error:NULL];
    NSURL *destination = UnusedFileURLInDirectory(directory, filename);
    [self.downloadDestinations setObject:destination forKey:download];
    completionHandler(destination);
}

- (void)downloadDidFinish:(id<WebAppWKDownload>)download
{
    NSURL *destination = [self.downloadDestinations objectForKey:download];
    [self.downloadDestinations removeObjectForKey:download];
    if (![destination isKindOfClass:[NSURL class]]) return;
    self.lastCompletedDownloadURL = destination;
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:@"com.apple.DownloadFileFinished" object:[destination path]];
}

- (void)download:(id<WebAppWKDownload>)download didFailWithError:(NSError *)error resumeData:(NSData *)resumeData
{
    (void)resumeData;
    [self.downloadDestinations removeObjectForKey:download];
    if ([[error domain] isEqualToString:NSURLErrorDomain] && [error code] == NSURLErrorCancelled)
        return;
    NSString *name = [[[download originalRequest] URL] lastPathComponent];
    fprintf(stderr, "Download failed: %s\n", [[error description] UTF8String]);
    if ([NSApp delegate] != (id)self) return;
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:[name length] ?
        [NSString stringWithFormat:@"\u201c%@\u201d could not be downloaded.", name] :
        @"The file could not be downloaded."];
    [alert setInformativeText:[error localizedDescription] ?: @""];
    [alert runModal];
}

- (void)buildMenus
{
    NSString *appName = StringSetting(self.configuration, @"CFBundleName");
    NSMenu *menuBar = [[NSMenu alloc] initWithTitle:@""];
    [NSApp setMainMenu:menuBar];

    NSMenuItem *appRoot = [[NSMenuItem alloc] initWithTitle:appName action:NULL keyEquivalent:@""];
    [menuBar addItem:appRoot];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:appName];
    [appRoot setSubmenu:appMenu];
    [appMenu addItemWithTitle:[@"About " stringByAppendingString:appName]
                       action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[@"Hide " stringByAppendingString:appName]
                       action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem *hideOthers = [appMenu addItemWithTitle:@"Hide Others"
                                               action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    [hideOthers setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask];
    [appMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[@"Quit " stringByAppendingString:appName]
                       action:@selector(terminate:) keyEquivalent:@"q"];
    NSUInteger customAppItemCount = [self applyConfiguredItemsForKey:@"AppMenuItems"
        toMenu:appMenu insertingAtIndex:2];
    if (customAppItemCount)
        [appMenu insertItem:[NSMenuItem separatorItem] atIndex:2 + customAppItemCount];

    NSMenu *fileMenu = [self addMenuNamed:@"File" toMenuBar:menuBar];
    NSMenuItem *newWindow = [fileMenu addItemWithTitle:@"New Window"
                                               action:@selector(newWindow:) keyEquivalent:@"n"];
    [newWindow setTarget:self];
    [fileMenu addItemWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];
    BOOL showShare = BoolSetting(self.configuration, @"EnableShareMenuItem", NO);
    BOOL showPrint = BoolSetting(self.configuration, @"EnablePrintMenuItem", YES);
    if (showShare || showPrint) [fileMenu addItem:[NSMenuItem separatorItem]];
    if (showShare) {
        NSMenuItem *share = [fileMenu addItemWithTitle:@"Share…"
                                               action:@selector(share:) keyEquivalent:@""];
        [share setTarget:self];
    }
    if (showPrint) {
        NSMenuItem *print = [fileMenu addItemWithTitle:@"Print…"
                                               action:@selector(print:) keyEquivalent:@"p"];
        [print setTarget:self];
    }
    [self applyConfiguredItemsForKey:@"FileMenuItems" toMenu:fileMenu
                    insertingAtIndex:1];

    NSMenu *editMenu = [self addMenuNamed:@"Edit" toMenuBar:menuBar];
    NSMenuItem *undo = [editMenu addItemWithTitle:@"Undo"
        action:@selector(performWebEditCommand:) keyEquivalent:@"z"];
    [undo setTag:WebAppEditCommandUndo];
    [undo setTarget:self];
    NSMenuItem *redo = [editMenu addItemWithTitle:@"Redo"
        action:@selector(performWebEditCommand:) keyEquivalent:@"Z"];
    [redo setTag:WebAppEditCommandRedo];
    [redo setTarget:self];
    [editMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *cut = [editMenu addItemWithTitle:@"Cut"
        action:@selector(performWebEditCommand:) keyEquivalent:@"x"];
    [cut setTag:WebAppEditCommandCut];
    [cut setTarget:self];
    NSMenuItem *copy = [editMenu addItemWithTitle:@"Copy"
        action:@selector(performWebEditCommand:) keyEquivalent:@"c"];
    [copy setTag:WebAppEditCommandCopy];
    [copy setTarget:self];
    NSMenuItem *paste = [editMenu addItemWithTitle:@"Paste"
        action:@selector(performWebEditCommand:) keyEquivalent:@"v"];
    [paste setTag:WebAppEditCommandPaste];
    [paste setTarget:self];
    NSMenuItem *selectAll = [editMenu addItemWithTitle:@"Select All"
        action:@selector(performWebEditCommand:) keyEquivalent:@"a"];
    [selectAll setTag:WebAppEditCommandSelectAll];
    [selectAll setTarget:self];
    [editMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *find = [editMenu addItemWithTitle:@"Find…"
                                          action:@selector(performWebEditCommand:) keyEquivalent:@"f"];
    [find setTag:WebAppEditCommandFind];
    [find setTarget:self];

    BOOL hasMaximumSize = NumberSetting(self.configuration, @"MaximumWindowWidth", 0) > 0 ||
                          NumberSetting(self.configuration, @"MaximumWindowHeight", 0) > 0;
    BOOL hasConfiguredViewItems = ConfiguredMenuHasItemsOtherThanTitle(
        self.configuration, @"ViewMenuItems", @"Refresh");
    if (!hasMaximumSize || hasConfiguredViewItems) {
        NSMenu *viewMenu = [self addMenuNamed:@"View" toMenuBar:menuBar];
        NSMenuItem *refresh = [viewMenu addItemWithTitle:@"Refresh"
                                                  action:@selector(reload:) keyEquivalent:@"r"];
        [refresh setTarget:self];
        if (!hasMaximumSize) {
            [viewMenu addItem:[NSMenuItem separatorItem]];
            NSMenuItem *fullScreen = [viewMenu addItemWithTitle:@"Enter Full Screen"
                                                         action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
            [fullScreen setTarget:self];
            [fullScreen setKeyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask];
        }
        [self applyConfiguredItemsForKey:@"ViewMenuItems" toMenu:viewMenu
                        insertingAtIndex:1];
    }

    self.historyMenu = nil;
    if (BoolSetting(self.configuration, @"EnableHistoryMenu", YES)) {
        NSMenu *historyMenu = [self addMenuNamed:@"History" toMenuBar:menuBar];
        NSMenuItem *back = [historyMenu addItemWithTitle:@"Back"
                                                  action:@selector(goBack:) keyEquivalent:@"["];
        NSMenuItem *forward = [historyMenu addItemWithTitle:@"Forward"
                                                     action:@selector(goForward:) keyEquivalent:@"]"];
        [back setTarget:self];
        [forward setTarget:self];
        self.historyMenu = historyMenu;
        [historyMenu setDelegate:self];
        [self updateHistoryMenu];
    }

    NSMenu *windowMenu = [self addMenuNamed:@"Window" toMenuBar:menuBar];
    [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    if (self.developerToolsEnabled) {
        [windowMenu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *inspector = [windowMenu addItemWithTitle:@"Web Inspector"
                                                     action:@selector(showWebInspector:) keyEquivalent:@"i"];
        [inspector setTarget:self];
        [inspector setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask];
    }
    [NSApp setWindowsMenu:windowMenu];

    NSString *helpURL = StringSetting(self.configuration, @"HelpURL");
    NSMenu *helpMenu = [self addMenuNamed:@"Help" toMenuBar:menuBar];
    SEL helpAction = [helpURL length] ? @selector(openConfiguredMenuItem:) : @selector(showHelp:);
    NSMenuItem *help = [helpMenu addItemWithTitle:[appName stringByAppendingString:@" Help"]
                                          action:helpAction keyEquivalent:@"?"];
    if ([helpURL length]) {
        [help setTarget:self];
        [help setRepresentedObject:helpURL];
    } else {
        [help setTarget:NSApp];
    }
    [NSApp setHelpMenu:helpMenu];
}

- (NSMenu *)addMenuNamed:(NSString *)name toMenuBar:(NSMenu *)menuBar
{
    NSMenuItem *root = [[NSMenuItem alloc] initWithTitle:name action:NULL keyEquivalent:@""];
    [menuBar addItem:root];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:name];
    [root setSubmenu:menu];
    return menu;
}

- (NSUInteger)applyConfiguredItemsForKey:(NSString *)key toMenu:(NSMenu *)menu
    insertingAtIndex:(NSInteger)insertionIndex
{
    id groups = [self.configuration objectForKey:key];
    if (![groups isKindOfClass:[NSArray class]]) return 0;
    NSUInteger insertedItemCount = 0;
    for (id group in groups) {
        if (![group isKindOfClass:[NSDictionary class]]) continue;
        for (NSString *title in group) {
            id destination = [group objectForKey:title];
            if (![title isKindOfClass:[NSString class]] ||
                ![destination isKindOfClass:[NSString class]]) continue;

            NSMenuItem *item = [menu itemWithTitle:title];
            if (!item) {
                item = [[NSMenuItem alloc] initWithTitle:title
                    action:@selector(openConfiguredMenuItem:) keyEquivalent:@""];
                NSInteger index = MIN(insertionIndex + (NSInteger)insertedItemCount,
                                      [menu numberOfItems]);
                [menu insertItem:item atIndex:index];
                insertedItemCount++;
            }
            [item setAction:@selector(openConfiguredMenuItem:)];
            [item setTarget:self];
            [item setRepresentedObject:destination];
        }
    }
    return insertedItemCount;
}

- (void)newWindow:(id)sender
{
    (void)sender;
    [self newBrowserWithURL:self.homeURL];
}

- (void)goBack:(id)sender { (void)sender; [[[self currentBrowser] webView] goBack]; }
- (void)goForward:(id)sender { (void)sender; [[[self currentBrowser] webView] goForward]; }
- (void)reload:(id)sender { (void)sender; [[[self currentBrowser] webView] reload]; }
- (void)stopLoading:(id)sender { (void)sender; [[[self currentBrowser] webView] stopLoading]; }

- (void)toggleFullScreen:(id)sender
{
    [[[self currentBrowser] window] toggleFullScreen:sender];
}

- (void)performWebEditCommand:(NSMenuItem *)sender
{
    WebAppEditCommand command = (WebAppEditCommand)[sender tag];
    if (![KeyEquivalentForEditCommand(command) length]) return;

    BrowserWindowController *browser = [self currentBrowser];
    NSWindow *window = [browser window];
    id webView = [browser webView];
    if (!window || !webView || [window firstResponder] != webView) {
        [self performNativeEditCommand:command];
        return;
    }

    NSEvent *event = EventForEditCommand(command, window);
    objc_setAssociatedObject(event, &WebAppForwardedEditEventKey,
        [NSNumber numberWithInteger:command], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (![(NSView *)webView performKeyEquivalent:event]) {
        objc_setAssociatedObject(event, &WebAppForwardedEditEventKey, nil,
                                 OBJC_ASSOCIATION_ASSIGN);
        [self performNativeEditCommand:command];
    }
}

- (void)performNativeEditCommand:(WebAppEditCommand)command
{
    if (command == WebAppEditCommandFind) {
        BrowserWindowController *browser = [self currentBrowser];
        [[browser textFinder] performAction:NSTextFinderActionShowFindInterface];
        return;
    }

    SEL action = NativeActionForEditCommand(command);
    if (action) [NSApp sendAction:action to:nil from:self];
}

- (BOOL)shouldSuppressWebEditKeyEvent:(NSEvent *)event
{
    NSMenu *editMenu = [[[NSApp mainMenu] itemWithTitle:@"Edit"] submenu];
    BOOL shouldSuppress = NO;
    for (NSMenuItem *item in [editMenu itemArray]) {
        if ([item action] != @selector(performWebEditCommand:)) continue;
        WebAppEditCommand command = (WebAppEditCommand)[item tag];
        if (EventMatchesEditCommand(event, command) &&
            !MenuItemUsesEditCommandKeyEquivalent(item, command)) {
            shouldSuppress = !MenuContainsKeyEquivalentForEvent([NSApp mainMenu], event);
            break;
        }
    }
    return shouldSuppress;
}

- (void)performTextFinderAction:(id)sender
{
    BrowserWindowController *browser = [self currentBrowser];
    [[browser textFinder] performAction:(NSTextFinderAction)[sender tag]];
}

- (void)print:(id)sender
{
    BrowserWindowController *browser = [self currentBrowser];
    [(NSView *)[browser webView] print:sender];
}

- (void)share:(id)sender
{
    (void)sender;
    BrowserWindowController *browser = [self currentBrowser];
    NSURL *url = [browser currentURL];
    if (!url) return;
    NSSharingServicePicker *picker = [[NSSharingServicePicker alloc]
                                      initWithItems:[NSArray arrayWithObject:url]];
    NSView *view = (NSView *)[browser webView];
    [picker showRelativeToRect:NSMakeRect(NSMidX([view bounds]), NSMaxY([view bounds]), 1, 1)
                        ofView:view preferredEdge:NSMinYEdge];
}

- (void)openConfiguredMenuItem:(NSMenuItem *)sender
{
    NSString *destination = [sender representedObject];
    BrowserWindowController *browser = [self currentBrowser];
    if ([destination hasPrefix:@"javascript:"]) {
        [browser evaluateJavaScript:[destination substringFromIndex:[@"javascript:" length]]];
        return;
    }

    NSURL *url = [NSURL URLWithString:destination];
    if ([url scheme]) {
        if ([self isURLAllowedInApp:url]) [self newBrowserWithURL:url];
        else [self openURLExternally:url];
        return;
    }
    NSURL *base = [browser currentURL] ?: self.homeURL;
    url = [NSURL URLWithString:destination relativeToURL:base];
    [browser loadURL:[url absoluteURL]];
}

- (void)showWebInspector:(id)sender
{
    (void)sender;
    id webView = [[self currentBrowser] webView];
    if (![webView respondsToSelector:@selector(_inspector)]) return;
    id<WebAppWKInspector> inspector = [webView _inspector];
    if ([inspector respondsToSelector:@selector(show)]) [inspector show];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(goBack:)) {
        id webView = [[self currentBrowser] webView];
        return webView && [webView canGoBack];
    }
    if ([menuItem action] == @selector(goForward:)) {
        id webView = [[self currentBrowser] webView];
        return webView && [webView canGoForward];
    }
    if ([menuItem action] == @selector(showWebInspector:)) {
        id webView = [[self currentBrowser] webView];
        id<WebAppWKInspector> inspector =
            [webView respondsToSelector:@selector(_inspector)] ? [webView _inspector] : nil;
        return self.developerToolsEnabled &&
               [inspector respondsToSelector:@selector(show)];
    }
    if ([menuItem action] == @selector(performWebEditCommand:) &&
        [menuItem tag] == WebAppEditCommandFind)
        return [[self.currentBrowser textFinder]
            validateAction:NSTextFinderActionShowFindInterface];
    if ([menuItem action] == @selector(performTextFinderAction:))
        return [[self.currentBrowser textFinder] validateAction:(NSTextFinderAction)[menuItem tag]];
    if ([menuItem action] == @selector(toggleFullScreen:)) {
        BOOL fullScreen = ([[[self currentBrowser] window] styleMask] & NSFullScreenWindowMask) != 0;
        [menuItem setTitle:fullScreen ? @"Exit Full Screen" : @"Enter Full Screen"];
    }
    return YES;
}

@end


static BOOL ConvertPNGAppIconIfNeeded(void)
{
    NSString *contentsDirectory = [[[NSBundle mainBundle] bundlePath]
        stringByAppendingPathComponent:@"Contents"];
    NSString *pngPath = [contentsDirectory stringByAppendingPathComponent:@"AppIcon.png"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:pngPath]) return NO;

    NSString *scriptPath = [contentsDirectory
        stringByAppendingPathComponent:@"MacOS/update-app-icon"];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:[NSArray arrayWithObject:scriptPath]];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        fprintf(stderr, "App icon conversion failed: %s\n", [[exception reason] UTF8String]);
    }

    // As in the old loader, do not open the app until it is launched again.
    return YES;
}


int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc > 1 && [[[NSString alloc] initWithUTF8String:argv[1]]
                         isEqualToString:@"--check-webkit"]) {
            [WebAppApplication sharedApplication];
            Class wkClass = BackportedWKWebViewClass();
            NSBundle *bundle = wkClass ? [NSBundle bundleForClass:wkClass] :
                [NSBundle bundleWithPath:@"/System/Library/Frameworks/WebKit.framework"];
            NSString *version = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"unknown";
            BOOL usable = NO;
            BOOL findBarUsable = NO;
            BOOL fullScreenEligible = NO;
            BOOL userCSSUsable = NO;
            BOOL userJavaScriptUsable = NO;
            BOOL contextMenuFilterUsable = NO;
            BOOL inspectorMenuUsable = NO;
            BOOL refreshMenuUsable = NO;
            BOOL customMenuReplacementUsable = NO;
            BOOL webEditMenuRoutingUsable = NO;
            BOOL helpMenuUsable = NO;
            BOOL historyMenuUsable = NO;
            BOOL webPushUsable = NO;
            BOOL pageNotificationProviderUsable = NO;
            BOOL automaticPermissionsUsable = NO;
            BOOL coreLocationProviderUsable = NO;
            BOOL downloadsUsable = NO;
            @try {
                Class configurationClass = NSClassFromString(@"WKWebViewConfiguration");
                Class scriptClass = NSClassFromString(@"WKUserScript");
                id configuration = [[configurationClass alloc] init];
                id script = [[scriptClass alloc] initWithSource:@"void 0" injectionTime:1
                                                forMainFrameOnly:YES];
                [[configuration userContentController] addUserScript:script];
                id view = [[wkClass alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)
                                           configuration:configuration];
                usable = view != nil;
                WebAppDelegate *probeDelegate = [[WebAppDelegate alloc] init];
                [probeDelegate setDeveloperToolsEnabled:YES];
                NSMutableDictionary *probeConfiguration =
                    [[probeDelegate configuration] mutableCopy];
                [probeConfiguration setObject:@"https://example.com/" forKey:@"URL"];
                [probeDelegate setConfiguration:probeConfiguration];
                [probeDelegate setHomeURL:[NSURL URLWithString:
                    @"https://example.com/"]];
                BrowserWindowController *probeBrowser = [[BrowserWindowController alloc]
                    initWithOwner:probeDelegate URL:[NSURL URLWithString:@"about:blank"]];
                [[probeDelegate browsers] addObject:probeBrowser];
                probeDelegate.geolocationProvider.testLocationEnabled = YES;
                [[probeBrowser textFinder] performAction:NSTextFinderActionShowFindInterface];
                findBarUsable = [probeBrowser findBarView] != nil &&
                                [probeBrowser isFindBarVisible];
                fullScreenEligible = ([[probeBrowser window] collectionBehavior] &
                                      NSWindowCollectionBehaviorFullScreenPrimary) != 0;

                id probeScript = [[scriptClass alloc]
                    initWithSource:@"window.__webAppUserContentProbe = true;"
                    injectionTime:1 forMainFrameOnly:YES];
                [[[[probeBrowser webView] configuration] userContentController]
                    addUserScript:probeScript];
                [probeBrowser setNavigationFinished:NO];
                [[probeBrowser webView] loadHTMLString:
                    @"<!doctype html><meta charset='utf-8'><title>Web App Probe</title>"
                     "<p>Web App Probe</p>"
                    baseURL:[NSURL URLWithString:@"https://example.com/"]];

                NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
                while (!probeBrowser.navigationFinished && [deadline timeIntervalSinceNow] > 0) {
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                }
                [probeDelegate.geolocationProvider install];
                [probeDelegate.geolocationProvider startUpdating];

                NSString *cssPath = [[NSBundle mainBundle]
                    pathForResource:@"userContent" ofType:@"css"];
                NSString *expectedCSS = [NSString stringWithContentsOfFile:cssPath
                    encoding:NSUTF8StringEncoding error:NULL];
                NSString *contentProbe = [NSString stringWithFormat:
                    @"(function(){var s=document.getElementById('__web_app_user_css');"
                     "return [!!s&&s.textContent===%@,"
                     "window.__webAppUserContentProbe===true,"
                     "window.__webAppHistoryBridgeInstalled===true];})()",
                    JavaScriptStringLiteral(expectedCSS)];
                __block BOOL evaluationFinished = NO;
                __block BOOL cssExecuted = NO;
                __block BOOL javaScriptExecuted = NO;
                __block BOOL historyBridgeExecuted = NO;
                [[probeBrowser webView] evaluateJavaScript:contentProbe
                    completionHandler:^(id result, NSError *error) {
                        (void)error;
                        if ([result isKindOfClass:[NSArray class]] && [result count] == 3) {
                            cssExecuted = [[result objectAtIndex:0] boolValue];
                            javaScriptExecuted = [[result objectAtIndex:1] boolValue];
                            historyBridgeExecuted = [[result objectAtIndex:2] boolValue];
                        }
                        evaluationFinished = YES;
                    }];
                deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
                while (!evaluationFinished && [deadline timeIntervalSinceNow] > 0) {
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                }
                userCSSUsable = probeBrowser.userCSSConfigured && cssExecuted;
                userJavaScriptUsable = probeBrowser.userJavaScriptConfigured &&
                                       javaScriptExecuted;

                NSString *downloadDirectory = [NSTemporaryDirectory()
                    stringByAppendingPathComponent:[NSString stringWithFormat:
                        @"web-app-download-probe-%d", getpid()]];
                probeDelegate.downloadDirectoryURL =
                    [NSURL fileURLWithPath:downloadDirectory isDirectory:YES];
                NSString *downloadProbeContent = @"Web App download probe";
                NSString *downloadProbe = [NSString stringWithFormat:
                    @"(function(){var a=document.createElement('a');"
                     "a.href=URL.createObjectURL(new Blob([%@],{type:'text/plain'}));"
                     "a.download='web-app-download-probe.txt';"
                     "document.body.appendChild(a);a.click();return true;})()",
                    JavaScriptStringLiteral(downloadProbeContent)];
                [[probeBrowser webView] evaluateJavaScript:downloadProbe completionHandler:nil];
                deadline = [NSDate dateWithTimeIntervalSinceNow:10.0];
                while (!probeDelegate.lastCompletedDownloadURL &&
                       [deadline timeIntervalSinceNow] > 0) {
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                }
                NSURL *downloadedURL = probeDelegate.lastCompletedDownloadURL;
                NSString *downloadedContent = downloadedURL ?
                    [NSString stringWithContentsOfURL:downloadedURL
                                            encoding:NSUTF8StringEncoding error:NULL] : nil;
                downloadsUsable = NSClassFromString(@"WKDownload") != Nil &&
                    [NSClassFromString(@"WKNavigationAction")
                        instancesRespondToSelector:@selector(shouldPerformDownload)] &&
                    [[downloadedURL lastPathComponent]
                        isEqualToString:@"web-app-download-probe.txt"] &&
                    [downloadedContent isEqualToString:downloadProbeContent];
                if (!downloadsUsable) {
                    fprintf(stderr, "Download probe: class=%d attribute=%d file=%s\n",
                        NSClassFromString(@"WKDownload") != Nil,
                        [NSClassFromString(@"WKNavigationAction")
                            instancesRespondToSelector:@selector(shouldPerformDownload)],
                        [[downloadedURL path] UTF8String] ?: "none");
                }
                [[NSFileManager defaultManager] removeItemAtPath:downloadDirectory error:NULL];

                NSMenu *proposedContextMenu = [[NSMenu alloc] initWithTitle:@""];
                [proposedContextMenu addItemWithTitle:@"Back"
                                               action:@selector(goBack) keyEquivalent:@""];
                [proposedContextMenu addItemWithTitle:@"Forward"
                                               action:@selector(goForward) keyEquivalent:@""];
                [proposedContextMenu addItem:[NSMenuItem separatorItem]];
                [proposedContextMenu addItemWithTitle:@"Reload"
                                               action:@selector(reload:) keyEquivalent:@""];
                [proposedContextMenu addItemWithTitle:@"Keep This Item"
                                               action:NULL keyEquivalent:@""];
                NSMenu *filteredContextMenu = [probeBrowser _webView:nil
                    contextMenu:proposedContextMenu forElement:nil];
                contextMenuFilterUsable =
                    [probeBrowser respondsToSelector:
                        NSSelectorFromString(@"_webView:contextMenu:forElement:")] &&
                    [filteredContextMenu itemWithTitle:@"Back"] == nil &&
                    [filteredContextMenu itemWithTitle:@"Forward"] == nil &&
                    [filteredContextMenu itemWithTitle:@"Reload"] == nil &&
                    [filteredContextMenu itemWithTitle:@"Keep This Item"] != nil;

NSMutableDictionary *menuProbeConfiguration =
                    [[probeDelegate configuration] mutableCopy];
                NSString *probeAppName =
                    StringSetting(menuProbeConfiguration, @"CFBundleName");
                NSString *aboutTitle = [@"About " stringByAppendingString:probeAppName];
                [menuProbeConfiguration setObject:[NSArray arrayWithObjects:
                    [NSDictionary dictionaryWithObject:@"https://example.com/about"
                                                forKey:aboutTitle],
                    [NSDictionary dictionaryWithObject:@"https://example.com/preferences"
                                                forKey:@"Preferences…"], nil]
                                              forKey:@"AppMenuItems"];
                [menuProbeConfiguration setObject:[NSArray arrayWithObjects:
                    [NSDictionary dictionaryWithObject:@"https://example.com/close"
                                                forKey:@"Close Window"],
                    [NSDictionary dictionaryWithObject:@"https://example.com/dashboard"
                                                forKey:@"Open Dashboard"], nil]
                                              forKey:@"FileMenuItems"];
                [menuProbeConfiguration setObject:[NSArray arrayWithObjects:
                    [NSDictionary dictionaryWithObject:@"https://example.com/refresh"
                                                forKey:@"Refresh"],
                    [NSDictionary dictionaryWithObject:@"https://example.com/actual-size"
                                                forKey:@"Actual Size"], nil]
                                              forKey:@"ViewMenuItems"];
                [menuProbeConfiguration setObject:@"" forKey:@"HelpURL"];
                [probeDelegate setConfiguration:menuProbeConfiguration];
                [probeDelegate setDeveloperToolsEnabled:NO];
                [probeDelegate buildMenus];
                BOOL inspectorHidden = [[[[NSApp mainMenu] itemWithTitle:@"Window"] submenu]
                    itemWithTitle:@"Web Inspector"] == nil;
                [probeDelegate setDeveloperToolsEnabled:YES];
                [probeDelegate buildMenus];
                NSMenu *windowMenu = [[[NSApp mainMenu] itemWithTitle:@"Window"] submenu];
                NSMenu *viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
NSMenu *probeAppMenu = [[[NSApp mainMenu] itemWithTitle:probeAppName] submenu];
                NSMenu *fileMenu = [[[NSApp mainMenu] itemWithTitle:@"File"] submenu];
                NSMenu *editMenu = [[[NSApp mainMenu] itemWithTitle:@"Edit"] submenu];
                NSMenu *helpMenu = [[[NSApp mainMenu] itemWithTitle:@"Help"] submenu];
                NSUInteger aboutItemCount = 0;
                for (NSMenuItem *item in [probeAppMenu itemArray]) {
                    if ([[item title] isEqualToString:aboutTitle]) aboutItemCount++;
                }
                NSMenuItem *aboutItem = [probeAppMenu itemWithTitle:aboutTitle];
                NSMenuItem *closeItem = [fileMenu itemWithTitle:@"Close Window"];
                NSMenuItem *refreshItem = [viewMenu itemWithTitle:@"Refresh"];
                customMenuReplacementUsable =
                    aboutItemCount == 1 &&
                    [probeAppMenu indexOfItem:aboutItem] == 0 &&
                    [aboutItem action] == @selector(openConfiguredMenuItem:) &&
                    [[aboutItem representedObject] isEqualToString:@"https://example.com/about"] &&
                    [[[probeAppMenu itemAtIndex:2] title] isEqualToString:@"Preferences…"] &&
                    [[probeAppMenu itemAtIndex:3] isSeparatorItem] &&
                    [fileMenu indexOfItemWithTitle:@"Open Dashboard"] == 1 &&
                    [fileMenu indexOfItem:closeItem] == 2 &&
                    [closeItem action] == @selector(openConfiguredMenuItem:) &&
                    [[closeItem keyEquivalent] isEqualToString:@"w"] &&
                    [viewMenu indexOfItem:refreshItem] == 0 &&
                    [viewMenu indexOfItemWithTitle:@"Actual Size"] == 1 &&
                    [refreshItem action] == @selector(openConfiguredMenuItem:) &&
                    [[refreshItem keyEquivalent] isEqualToString:@"r"];
                NSMenuItem *helpItem = [helpMenu itemAtIndex:0];
                helpMenuUsable = helpMenu != nil &&
                    [helpMenu numberOfItems] == 1 &&
                    [[helpItem title] isEqualToString:
                        [probeAppName stringByAppendingString:@" Help"]] &&
                    [helpItem action] == @selector(showHelp:) &&
                    [helpItem target] == NSApp;
                NSMenuItem *inspectorItem = [windowMenu itemWithTitle:@"Web Inspector"];
                id<WebAppWKInspector> inspector =
                    [[probeBrowser webView] respondsToSelector:@selector(_inspector)] ?
                    [[probeBrowser webView] _inspector] : nil;
                inspectorMenuUsable = inspectorHidden && inspectorItem != nil &&
                    [inspectorItem action] == @selector(showWebInspector:) &&
                    [inspector respondsToSelector:@selector(show)] &&
                    [viewMenu itemWithTitle:@"Web Inspector"] == nil &&
                    [viewMenu itemWithTitle:@"Show Web Inspector"] == nil;
                refreshMenuUsable = [viewMenu itemWithTitle:@"Refresh"] != nil &&
                    [viewMenu itemWithTitle:@"Refresh Page"] == nil;
                NSArray *editTitles = [NSArray arrayWithObjects:@"Undo", @"Redo", @"Cut",
                    @"Copy", @"Paste", @"Select All", @"Find…", nil];
                BOOL allEditItemsRouted = YES;
                for (NSString *title in editTitles) {
                    NSMenuItem *item = [editMenu itemWithTitle:title];
                    allEditItemsRouted = allEditItemsRouted && item != nil &&
                        [item action] == @selector(performWebEditCommand:) &&
                        [item target] == probeDelegate;
                }
                NSMenuItem *customShortcutProbe = [[NSMenuItem alloc]
                    initWithTitle:@"Shortcut Probe" action:NULL keyEquivalent:@"g"];
                [customShortcutProbe setKeyEquivalentModifierMask:NSCommandKeyMask];
                NSEvent *canonicalFindEvent = EventForEditCommand(
                    WebAppEditCommandFind, [probeBrowser window]);
                NSMenuItem *findItem = [editMenu itemWithTitle:@"Find…"];
                NSString *savedFindKeyEquivalent = [[findItem keyEquivalent] copy];
                NSUInteger savedFindModifierMask = [findItem keyEquivalentModifierMask];
                [findItem setKeyEquivalent:@"g"];
                [findItem setKeyEquivalentModifierMask:NSCommandKeyMask];
                BOOL displacedDefaultSuppressed =
                    [probeDelegate shouldSuppressWebEditKeyEvent:canonicalFindEvent];
                [findItem setKeyEquivalent:savedFindKeyEquivalent];
                [findItem setKeyEquivalentModifierMask:savedFindModifierMask];
                BOOL webEditRoutingStructureUsable = allEditItemsRouted &&
                    [NSApp isKindOfClass:[WebAppApplication class]] &&
                    EventMatchesEditCommand(canonicalFindEvent, WebAppEditCommandFind) &&
                    !MenuItemUsesEditCommandKeyEquivalent(customShortcutProbe,
                                                          WebAppEditCommandFind) &&
                    displacedDefaultSuppressed;
                [[probeBrowser textFinder]
                    performAction:NSTextFinderActionHideFindInterface];
                evaluationFinished = NO;
                [[probeBrowser webView] evaluateJavaScript:
                    @"window.__webAppEditCommandProbe=null;"
                     "addEventListener('keydown',function(e){"
                       "if(e.metaKey&&String(e.key).toLowerCase()==='f'){"
                         "window.__webAppEditCommandProbe=[e.key,e.metaKey,e.isTrusted];"
                         "e.preventDefault();"
                       "}"
                     "},true);true"
                    completionHandler:^(id result, NSError *error) {
                        (void)result; (void)error;
                        evaluationFinished = YES;
                    }];
                deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
                while (!evaluationFinished && [deadline timeIntervalSinceNow] > 0) {
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                }
                [NSApp setDelegate:probeDelegate];
                [[probeBrowser window] makeFirstResponder:[probeBrowser webView]];
                [probeDelegate performWebEditCommand:findItem];
                __block BOOL webEditEventHandledByPage = NO;
                evaluationFinished = NO;
                [[probeBrowser webView] evaluateJavaScript:
                    @"window.__webAppEditCommandProbe"
                    completionHandler:^(id result, NSError *error) {
                        (void)error;
                        if ([result isKindOfClass:[NSArray class]] && [result count] == 3)
                            webEditEventHandledByPage =
                                [[[result objectAtIndex:0] lowercaseString]
                                    isEqualToString:@"f"] &&
                                [[result objectAtIndex:1] boolValue] &&
                                [[result objectAtIndex:2] boolValue];
                        evaluationFinished = YES;
                    }];
                deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
                while (!evaluationFinished && [deadline timeIntervalSinceNow] > 0) {
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                }
                webEditMenuRoutingUsable = webEditRoutingStructureUsable &&
                    webEditEventHandledByPage && ![probeBrowser isFindBarVisible];
                NSMutableArray *probeHistory = [NSMutableArray array];
                NSString *probeCurrentURL = [[probeBrowser currentURL] absoluteString];
                for (NSUInteger index = 0; index < 16; index++) {
                    [probeHistory addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        [NSString stringWithFormat:@"Page %lu", (unsigned long)index], @"Title",
                        index == 0 ? probeCurrentURL :
                            [NSString stringWithFormat:@"http://example.com/%lu",
                                (unsigned long)index], @"URL",
                        [NSDate dateWithTimeIntervalSinceNow:-(NSTimeInterval)index],
                        @"LastVisitTime", nil]];
                }
                [probeDelegate setHistory:probeHistory];
                [probeDelegate updateHistoryMenu];
                NSMenu *historyMenu = [[[NSApp mainMenu] itemWithTitle:@"History"] submenu];
                BOOL populatedHistoryMenuUsable =
                    historyMenu == [probeDelegate historyMenu] &&
                    [historyMenu delegate] == probeDelegate &&
                    [historyMenu numberOfItems] == 18 &&
                    [[[historyMenu itemAtIndex:0] title] isEqualToString:@"Back"] &&
                    [[[historyMenu itemAtIndex:1] title] isEqualToString:@"Forward"] &&
                    [[historyMenu itemAtIndex:2] isSeparatorItem] &&
                    [[[historyMenu itemAtIndex:3] title] isEqualToString:@"Page 0"] &&
                    [[[historyMenu itemAtIndex:17] title] isEqualToString:@"Page 14"] &&
                    [[historyMenu itemAtIndex:3] action] == @selector(openHistoryItem:) &&
                    [[historyMenu itemAtIndex:3] state] == NSOnState &&
                    [probeDelegate browserForURL:[probeBrowser currentURL]] == probeBrowser &&
                    [probeBrowser historyMessageHandlerConfigured] &&
                    historyBridgeExecuted &&
                    [CleanHistoryTitle(@"Settings - Your Title Goes Here",
                        @"Your Title Goes Here") isEqualToString:@"Settings"];
                [probeDelegate setHistory:[NSMutableArray array]];
                [probeDelegate updateHistoryMenu];
                historyMenuUsable = populatedHistoryMenuUsable &&
                    [historyMenu numberOfItems] == 2 &&
                    ![[historyMenu itemAtIndex:0] isSeparatorItem] &&
                    ![[historyMenu itemAtIndex:1] isSeparatorItem];

                __block BOOL notificationPermissionGranted = NO;
                [probeBrowser _webView:nil
                    requestNotificationPermissionForSecurityOrigin:nil
                    decisionHandler:^(BOOL allowed) {
                        notificationPermissionGranted = allowed;
                    }];
                NSURL *notificationProbeURL =
                    [NSURL URLWithString:@"https://notifications.example/path"];
                [probeDelegate grantNotificationPermissionForURL:notificationProbeURL];
                NSDictionary *persistentNotificationPermissions =
                    [probeDelegate notificationPermissionsForWebsiteDataStore:
                        probeDelegate.websiteDataStore];
                Class notificationDataClass = NSClassFromString(@"_WKNotificationData");
                BOOL persistentNotificationBridgeUsable =
                    [[[persistentNotificationPermissions objectForKey:
                        @"https://notifications.example"] description]
                        isEqualToString:@"1"] &&
                    probeDelegate.websiteDataStore != nil &&
                    [probeDelegate.websiteDataStore respondsToSelector:
                        @selector(_processPersistentNotificationClick:completionHandler:)] &&
                    [probeDelegate respondsToSelector:
                        @selector(notificationPermissionsForWebsiteDataStore:)] &&
                    [probeDelegate respondsToSelector:
                        @selector(websiteDataStore:showNotification:)] &&
                    [probeDelegate respondsToSelector:
                        @selector(websiteDataStore:getDisplayedNotificationsForWorkerOrigin:
                                  completionHandler:)] &&
                    notificationDataClass != Nil &&
                    [notificationDataClass instancesRespondToSelector:@selector(title)] &&
                    [notificationDataClass instancesRespondToSelector:@selector(body)] &&
                    [notificationDataClass instancesRespondToSelector:
                        @selector(dictionaryRepresentation)] &&
                    [NSUserNotificationCenter defaultUserNotificationCenter] != nil;
                NSString *webPushDaemon =
                    @"/System/Library/PrivateFrameworks/WebKit2.framework/Versions/A/Daemons/webpushd";
                webPushUsable = probeBrowser.webPushConfigured &&
                    notificationPermissionGranted &&
                    persistentNotificationBridgeUsable &&
                    [[NSFileManager defaultManager] isExecutableFileAtPath:webPushDaemon];

                WKDictionaryRef providerPermissions =
                    [probeDelegate.notificationProvider copyNotificationPermissions];
                pageNotificationProviderUsable = LoadWebKitNotificationAPI() &&
                    probeDelegate.notificationProvider.configured &&
                    probeDelegate.notificationProvider.webKitManager != NULL &&
                    providerPermissions != NULL;
                if (providerPermissions) WebAppWKRelease(providerPermissions);

                __block NSInteger mediaDecision = 0;
                __block NSInteger geolocationDecision = 0;
                __block NSInteger orientationDecision = 0;
                __block NSInteger queryDecision = 0;
                __block BOOL legacyMediaGranted = NO;
                __block BOOL screenUnmutingGranted = NO;
                __block BOOL storageAccessGranted = NO;
                __block BOOL pointerLockGranted = NO;
                __block BOOL backgroundFetchGranted = NO;
                __block unsigned long long storageQuota = 0;
                [probeBrowser webView:nil requestMediaCapturePermissionForOrigin:nil
                    initiatedByFrame:nil type:0 decisionHandler:^(NSInteger decision) {
                        mediaDecision = decision;
                    }];
                [probeBrowser webView:nil requestGeolocationPermissionForOrigin:nil
                    initiatedByFrame:nil decisionHandler:^(NSInteger decision) {
                        geolocationDecision = decision;
                    }];
                [probeBrowser webView:nil
                    requestDeviceOrientationAndMotionPermissionForOrigin:nil
                    initiatedByFrame:nil decisionHandler:^(NSInteger decision) {
                        orientationDecision = decision;
                    }];
                [probeBrowser _webView:nil requestUserMediaAuthorizationForDevices:0
                    url:nil mainFrameURL:nil decisionHandler:^(BOOL allowed) {
                        legacyMediaGranted = allowed;
                    }];
                [probeBrowser _webView:nil queryPermission:@"clipboard-read" forOrigin:nil
                    completionHandler:^(NSInteger decision) {
                        queryDecision = decision;
                    }];
                [probeBrowser _webView:nil decidePolicyForScreenCaptureUnmutingForOrigin:nil
                    initiatedByFrame:nil decisionHandler:^(BOOL allowed) {
                        screenUnmutingGranted = allowed;
                    }];
                [probeBrowser _webView:nil requestStorageAccessPanelForDomain:@"frame.example"
                    underCurrentDomain:@"top.example" completionHandler:^(BOOL allowed) {
                        storageAccessGranted = allowed;
                    }];
                [probeBrowser _webViewDidRequestPointerLock:nil
                    completionHandler:^(BOOL allowed) {
                        pointerLockGranted = allowed;
                    }];
                [probeDelegate requestBackgroundFetchPermission:nil frameOrigin:nil
                    decisionHandler:^(BOOL allowed) {
                        backgroundFetchGranted = allowed;
                    }];
                [probeDelegate requestStorageSpace:nil frameOrigin:nil quota:1024
                    currentSize:1024 spaceRequired:2048
                    decisionHandler:^(unsigned long long newQuota) {
                        storageQuota = newQuota;
                    }];
                automaticPermissionsUsable = probeBrowser.automaticPermissionsConfigured &&
                    mediaDecision == WebAppPermissionDecisionGrant &&
                    geolocationDecision == WebAppPermissionDecisionGrant &&
                    orientationDecision == WebAppPermissionDecisionGrant &&
                    queryDecision == WebAppPermissionDecisionGrant &&
                    legacyMediaGranted && screenUnmutingGranted &&
                    storageAccessGranted && pointerLockGranted &&
                    backgroundFetchGranted && storageQuota >= 3072;
                coreLocationProviderUsable =
                    probeDelegate.processPool != nil &&
                    probeDelegate.geolocationProvider.configured &&
                    probeDelegate.geolocationProvider.webKitManager != NULL &&
                    probeDelegate.geolocationProvider.locationRequestsStarted &&
                    geolocationDecision == WebAppPermissionDecisionGrant &&
                    LoadWebKitGeolocationAPI() &&
                    NSClassFromString(@"CLLocationManager") != Nil;
                if (!coreLocationProviderUsable) {
                    fprintf(stderr, "Geolocation probe: configured=%d manager=%d "
                        "permission-granted=%d request-started=%d\n",
                        probeDelegate.geolocationProvider.configured,
                        probeDelegate.geolocationProvider.webKitManager != NULL,
                        geolocationDecision == WebAppPermissionDecisionGrant,
                        probeDelegate.geolocationProvider.locationRequestsStarted);
                }
                [[probeBrowser window] close];
            } @catch (NSException *exception) {
                fprintf(stderr, "WKWebView probe failed: %s\n", [[exception reason] UTF8String]);
            }
            printf("WebKit %s\nWKWebView: %s\n", [version UTF8String], usable ? "usable" : "missing");
            printf("Native find bar: %s\n", findBarUsable ? "usable" : "missing");
            printf("Full screen: %s\n", fullScreenEligible ? "enabled" : "disabled");
            printf("User CSS injection: %s\n", userCSSUsable ? "usable" : "missing");
            printf("User JavaScript injection: %s\n",
                   userJavaScriptUsable ? "usable" : "missing");
            printf("Context-menu navigation filter: %s\n",
                   contextMenuFilterUsable ? "usable" : "missing");
            printf("Window Web Inspector menu: %s\n",
                   inspectorMenuUsable ? "usable" : "missing");
            printf("View Refresh menu: %s\n", refreshMenuUsable ? "usable" : "missing");
            printf("Custom menu replacement: %s\n",
                   customMenuReplacementUsable ? "usable" : "missing");
            printf("Web Edit menu routing: %s\n",
                   webEditMenuRoutingUsable ? "usable" : "missing");
            printf("Unconditional Help menu: %s\n",
                   helpMenuUsable ? "usable" : "missing");
            printf("Persistent History menu: %s\n",
                   historyMenuUsable ? "usable" : "missing");
            printf("Web Push: %s\n", webPushUsable ? "enabled" : "missing");
            printf("Page notification provider: %s\n",
                   pageNotificationProviderUsable ? "usable" : "missing");
            printf("Automatic Web permissions: %s\n",
                   automaticPermissionsUsable ? "enabled" : "missing");
            printf("CoreLocation geolocation provider: %s\n",
                   coreLocationProviderUsable ? "usable" : "missing");
            printf("File downloads: %s\n", downloadsUsable ? "usable" : "missing");
            return usable && findBarUsable && fullScreenEligible &&
                   userCSSUsable && userJavaScriptUsable &&
                   contextMenuFilterUsable && inspectorMenuUsable && refreshMenuUsable &&
                   customMenuReplacementUsable && webEditMenuRoutingUsable && helpMenuUsable &&
                   historyMenuUsable &&
                   webPushUsable && pageNotificationProviderUsable &&
                   automaticPermissionsUsable &&
                   coreLocationProviderUsable && downloadsUsable ? 0 : 1;
        }
        if (ConvertPNGAppIconIfNeeded()) return 0;
        NSApplication *application = [WebAppApplication sharedApplication];
        WebAppDelegate *delegate = [[WebAppDelegate alloc] init];
        [application setDelegate:delegate];
        [application run];
    }
    return 0;
}
