//========================================================================
// GLFW 3.4 macOS (modified for raylib) - www.glfw.org; www.raylib.com
//------------------------------------------------------------------------
// Copyright (c) 2009-2019 Camilla Löwy <elmindreda@glfw.org>
// Copyright (c) 2024 M374LX <wilsalx@gmail.com>
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would
//    be appreciated but is not required.
//
// 2. Altered source versions must be plainly marked as such, and must not
//    be misrepresented as being the original software.
//
// 3. This notice may not be removed or altered from any source
//    distribution.
//
//========================================================================

#include "internal.h"

#if defined(_GLFW_COCOA)

#include <sys/param.h> // For MAXPATHLEN

// Needed for _NSGetProgname
#include <crt_externs.h>

// Change to our application bundle's resources directory, if present
//
static void changeToResourcesDirectory(void)
{
    char resourcesPath[MAXPATHLEN];

    CFBundleRef bundle = CFBundleGetMainBundle();
    if (!bundle)
        return;

    CFURLRef resourcesURL = CFBundleCopyResourcesDirectoryURL(bundle);

    CFStringRef last = CFURLCopyLastPathComponent(resourcesURL);
    if (CFStringCompare(CFSTR("Resources"), last, 0) != kCFCompareEqualTo)
    {
        CFRelease(last);
        CFRelease(resourcesURL);
        return;
    }

    CFRelease(last);

    if (!CFURLGetFileSystemRepresentation(resourcesURL,
                                          true,
                                          (UInt8*) resourcesPath,
                                          MAXPATHLEN))
    {
        CFRelease(resourcesURL);
        return;
    }

    CFRelease(resourcesURL);

    chdir(resourcesPath);
}

// Set up the menu bar (manually)
// This is nasty, nasty stuff -- calls to undocumented semi-private APIs that
// could go away at any moment, lots of stuff that really should be
// localize(d|able), etc.  Add a nib to save us this horror.
//
static void createMenuBar(void)
{
    NSString* appName = nil;
    NSDictionary* bundleInfo = [[NSBundle mainBundle] infoDictionary];
    NSString* nameKeys[] =
    {
        @"CFBundleDisplayName",
        @"CFBundleName",
        @"CFBundleExecutable",
    };

    // Try to figure out what the calling application is called

    for (size_t i = 0;  i < sizeof(nameKeys) / sizeof(nameKeys[0]);  i++)
    {
        id name = bundleInfo[nameKeys[i]];
        if (name &&
            [name isKindOfClass:[NSString class]] &&
            ![name isEqualToString:@""])
        {
            appName = name;
            break;
        }
    }

    if (!appName)
    {
        char** progname = _NSGetProgname();
        if (progname && *progname)
            appName = @(*progname);
        else
            appName = @"GLFW Application";
    }

    NSMenu* bar = [[NSMenu alloc] init];
    [NSApp setMainMenu:bar];

    NSMenuItem* appMenuItem =
        [bar addItemWithTitle:@"" action:NULL keyEquivalent:@""];
    NSMenu* appMenu = [[NSMenu alloc] init];
    [appMenuItem setSubmenu:appMenu];

    [appMenu addItemWithTitle:[NSString stringWithFormat:@"About %@", appName]
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenu* servicesMenu = [[NSMenu alloc] init];
    [NSApp setServicesMenu:servicesMenu];
    [[appMenu addItemWithTitle:@"Services"
                       action:NULL
                keyEquivalent:@""] setSubmenu:servicesMenu];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"Hide %@", appName]
                       action:@selector(hide:)
                keyEquivalent:@"h"];
    [[appMenu addItemWithTitle:@"Hide Others"
                       action:@selector(hideOtherApplications:)
                keyEquivalent:@"h"]
        setKeyEquivalentModifierMask:NSEventModifierFlagOption | NSEventModifierFlagCommand];
    [appMenu addItemWithTitle:@"Show All"
                       action:@selector(unhideAllApplications:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"Quit %@", appName]
                       action:@selector(terminate:)
                keyEquivalent:@"q"];

    NSMenuItem* windowMenuItem =
        [bar addItemWithTitle:@"" action:NULL keyEquivalent:@""];
    NSMenu* windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [NSApp setWindowsMenu:windowMenu];
    [windowMenuItem setSubmenu:windowMenu];

    [windowMenu addItemWithTitle:@"Minimize"
                          action:@selector(performMiniaturize:)
                   keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom"
                          action:@selector(performZoom:)
                   keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front"
                          action:@selector(arrangeInFront:)
                   keyEquivalent:@""];

    // TODO: Make this appear at the bottom of the menu (for consistency)
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [[windowMenu addItemWithTitle:@"Enter Full Screen"
                           action:@selector(toggleFullScreen:)
                    keyEquivalent:@"f"]
     setKeyEquivalentModifierMask:NSEventModifierFlagControl | NSEventModifierFlagCommand];

    // Prior to Snow Leopard, we need to use this oddly-named semi-private API
    // to get the application menu working properly.
    [NSApp performSelector:@selector(setAppleMenu:) withObject:appMenu];
}

// Create key code translation tables
//
static void createKeyTablesCocoa(void)
{
    memset(_glfw.ns.keycodes, -1, sizeof(_glfw.ns.keycodes));
    memset(_glfw.ns.scancodes, -1, sizeof(_glfw.ns.scancodes));

    _glfw.ns.keycodes[0x1D] = GLFW_KEY_0;
    _glfw.ns.keycodes[0x12] = GLFW_KEY_1;
    _glfw.ns.keycodes[0x13] = GLFW_KEY_2;
    _glfw.ns.keycodes[0x14] = GLFW_KEY_3;
    _glfw.ns.keycodes[0x15] = GLFW_KEY_4;
    _glfw.ns.keycodes[0x17] = GLFW_KEY_5;
    _glfw.ns.keycodes[0x16] = GLFW_KEY_6;
    _glfw.ns.keycodes[0x1A] = GLFW_KEY_7;
    _glfw.ns.keycodes[0x1C] = GLFW_KEY_8;
    _glfw.ns.keycodes[0x19] = GLFW_KEY_9;
    _glfw.ns.keycodes[0x00] = GLFW_KEY_A;
    _glfw.ns.keycodes[0x0B] = GLFW_KEY_B;
    _glfw.ns.keycodes[0x08] = GLFW_KEY_C;
    _glfw.ns.keycodes[0x02] = GLFW_KEY_D;
    _glfw.ns.keycodes[0x0E] = GLFW_KEY_E;
    _glfw.ns.keycodes[0x03] = GLFW_KEY_F;
    _glfw.ns.keycodes[0x05] = GLFW_KEY_G;
    _glfw.ns.keycodes[0x04] = GLFW_KEY_H;
    _glfw.ns.keycodes[0x22] = GLFW_KEY_I;
    _glfw.ns.keycodes[0x26] = GLFW_KEY_J;
    _glfw.ns.keycodes[0x28] = GLFW_KEY_K;
    _glfw.ns.keycodes[0x25] = GLFW_KEY_L;
    _glfw.ns.keycodes[0x2E] = GLFW_KEY_M;
    _glfw.ns.keycodes[0x2D] = GLFW_KEY_N;
    _glfw.ns.keycodes[0x1F] = GLFW_KEY_O;
    _glfw.ns.keycodes[0x23] = GLFW_KEY_P;
    _glfw.ns.keycodes[0x0C] = GLFW_KEY_Q;
    _glfw.ns.keycodes[0x0F] = GLFW_KEY_R;
    _glfw.ns.keycodes[0x01] = GLFW_KEY_S;
    _glfw.ns.keycodes[0x11] = GLFW_KEY_T;
    _glfw.ns.keycodes[0x20] = GLFW_KEY_U;
    _glfw.ns.keycodes[0x09] = GLFW_KEY_V;
    _glfw.ns.keycodes[0x0D] = GLFW_KEY_W;
    _glfw.ns.keycodes[0x07] = GLFW_KEY_X;
    _glfw.ns.keycodes[0x10] = GLFW_KEY_Y;
    _glfw.ns.keycodes[0x06] = GLFW_KEY_Z;

    _glfw.ns.keycodes[0x27] = GLFW_KEY_APOSTROPHE;
    _glfw.ns.keycodes[0x2A] = GLFW_KEY_BACKSLASH;
    _glfw.ns.keycodes[0x2B] = GLFW_KEY_COMMA;
    _glfw.ns.keycodes[0x18] = GLFW_KEY_EQUAL;
    _glfw.ns.keycodes[0x32] = GLFW_KEY_GRAVE_ACCENT;
    _glfw.ns.keycodes[0x21] = GLFW_KEY_LEFT_BRACKET;
    _glfw.ns.keycodes[0x1B] = GLFW_KEY_MINUS;
    _glfw.ns.keycodes[0x2F] = GLFW_KEY_PERIOD;
    _glfw.ns.keycodes[0x1E] = GLFW_KEY_RIGHT_BRACKET;
    _glfw.ns.keycodes[0x29] = GLFW_KEY_SEMICOLON;
    _glfw.ns.keycodes[0x2C] = GLFW_KEY_SLASH;
    _glfw.ns.keycodes[0x0A] = GLFW_KEY_WORLD_1;

    _glfw.ns.keycodes[0x33] = GLFW_KEY_BACKSPACE;
    _glfw.ns.keycodes[0x39] = GLFW_KEY_CAPS_LOCK;
    _glfw.ns.keycodes[0x75] = GLFW_KEY_DELETE;
    _glfw.ns.keycodes[0x7D] = GLFW_KEY_DOWN;
    _glfw.ns.keycodes[0x77] = GLFW_KEY_END;
    _glfw.ns.keycodes[0x24] = GLFW_KEY_ENTER;
    _glfw.ns.keycodes[0x35] = GLFW_KEY_ESCAPE;
    _glfw.ns.keycodes[0x7A] = GLFW_KEY_F1;
    _glfw.ns.keycodes[0x78] = GLFW_KEY_F2;
    _glfw.ns.keycodes[0x63] = GLFW_KEY_F3;
    _glfw.ns.keycodes[0x76] = GLFW_KEY_F4;
    _glfw.ns.keycodes[0x60] = GLFW_KEY_F5;
    _glfw.ns.keycodes[0x61] = GLFW_KEY_F6;
    _glfw.ns.keycodes[0x62] = GLFW_KEY_F7;
    _glfw.ns.keycodes[0x64] = GLFW_KEY_F8;
    _glfw.ns.keycodes[0x65] = GLFW_KEY_F9;
    _glfw.ns.keycodes[0x6D] = GLFW_KEY_F10;
    _glfw.ns.keycodes[0x67] = GLFW_KEY_F11;
    _glfw.ns.keycodes[0x6F] = GLFW_KEY_F12;
    _glfw.ns.keycodes[0x69] = GLFW_KEY_PRINT_SCREEN;
    _glfw.ns.keycodes[0x6B] = GLFW_KEY_F14;
    _glfw.ns.keycodes[0x71] = GLFW_KEY_F15;
    _glfw.ns.keycodes[0x6A] = GLFW_KEY_F16;
    _glfw.ns.keycodes[0x40] = GLFW_KEY_F17;
    _glfw.ns.keycodes[0x4F] = GLFW_KEY_F18;
    _glfw.ns.keycodes[0x50] = GLFW_KEY_F19;
    _glfw.ns.keycodes[0x5A] = GLFW_KEY_F20;
    _glfw.ns.keycodes[0x73] = GLFW_KEY_HOME;
    _glfw.ns.keycodes[0x72] = GLFW_KEY_INSERT;
    _glfw.ns.keycodes[0x7B] = GLFW_KEY_LEFT;
    _glfw.ns.keycodes[0x3A] = GLFW_KEY_LEFT_ALT;
    _glfw.ns.keycodes[0x3B] = GLFW_KEY_LEFT_CONTROL;
    _glfw.ns.keycodes[0x38] = GLFW_KEY_LEFT_SHIFT;
    _glfw.ns.keycodes[0x37] = GLFW_KEY_LEFT_SUPER;
    _glfw.ns.keycodes[0x6E] = GLFW_KEY_MENU;
    _glfw.ns.keycodes[0x47] = GLFW_KEY_NUM_LOCK;
    _glfw.ns.keycodes[0x79] = GLFW_KEY_PAGE_DOWN;
    _glfw.ns.keycodes[0x74] = GLFW_KEY_PAGE_UP;
    _glfw.ns.keycodes[0x7C] = GLFW_KEY_RIGHT;
    _glfw.ns.keycodes[0x3D] = GLFW_KEY_RIGHT_ALT;
    _glfw.ns.keycodes[0x3E] = GLFW_KEY_RIGHT_CONTROL;
    _glfw.ns.keycodes[0x3C] = GLFW_KEY_RIGHT_SHIFT;
    _glfw.ns.keycodes[0x36] = GLFW_KEY_RIGHT_SUPER;
    _glfw.ns.keycodes[0x31] = GLFW_KEY_SPACE;
    _glfw.ns.keycodes[0x30] = GLFW_KEY_TAB;
    _glfw.ns.keycodes[0x7E] = GLFW_KEY_UP;

    _glfw.ns.keycodes[0x52] = GLFW_KEY_KP_0;
    _glfw.ns.keycodes[0x53] = GLFW_KEY_KP_1;
    _glfw.ns.keycodes[0x54] = GLFW_KEY_KP_2;
    _glfw.ns.keycodes[0x55] = GLFW_KEY_KP_3;
    _glfw.ns.keycodes[0x56] = GLFW_KEY_KP_4;
    _glfw.ns.keycodes[0x57] = GLFW_KEY_KP_5;
    _glfw.ns.keycodes[0x58] = GLFW_KEY_KP_6;
    _glfw.ns.keycodes[0x59] = GLFW_KEY_KP_7;
    _glfw.ns.keycodes[0x5B] = GLFW_KEY_KP_8;
    _glfw.ns.keycodes[0x5C] = GLFW_KEY_KP_9;
    _glfw.ns.keycodes[0x45] = GLFW_KEY_KP_ADD;
    _glfw.ns.keycodes[0x41] = GLFW_KEY_KP_DECIMAL;
    _glfw.ns.keycodes[0x4B] = GLFW_KEY_KP_DIVIDE;
    _glfw.ns.keycodes[0x4C] = GLFW_KEY_KP_ENTER;
    _glfw.ns.keycodes[0x51] = GLFW_KEY_KP_EQUAL;
    _glfw.ns.keycodes[0x43] = GLFW_KEY_KP_MULTIPLY;
    _glfw.ns.keycodes[0x4E] = GLFW_KEY_KP_SUBTRACT;

    for (int scancode = 0;  scancode < 256;  scancode++)
    {
        // Store the reverse translation for faster key name lookup
        if (_glfw.ns.keycodes[scancode] >= 0)
            _glfw.ns.scancodes[_glfw.ns.keycodes[scancode]] = scancode;
    }
}

// Retrieve Unicode data for the current keyboard layout
//
static GLFWbool updateUnicodeData(void)
{
    if (_glfw.ns.inputSource)
    {
        CFRelease(_glfw.ns.inputSource);
        _glfw.ns.inputSource = NULL;
        _glfw.ns.unicodeData = nil;
    }

    _glfw.ns.inputSource = TISCopyCurrentKeyboardLayoutInputSource();
    if (!_glfw.ns.inputSource)
    {
        _glfwInputError(GLFW_PLATFORM_ERROR,
                        "Cocoa: Failed to retrieve keyboard layout input source");
        return GLFW_FALSE;
    }

	void* tmp = TISGetInputSourceProperty(_glfw.ns.inputSource, kTISPropertyUnicodeKeyLayoutData);
	_glfw.ns.unicodeData = (__bridge id)(tmp);
    if (!_glfw.ns.unicodeData)
    {
        _glfwInputError(GLFW_PLATFORM_ERROR,
                        "Cocoa: Failed to retrieve keyboard layout Unicode data");
        return GLFW_FALSE;
    }

    return GLFW_TRUE;
}

// Load HIToolbox.framework and the TIS symbols we need from it
//
static GLFWbool initializeTIS(void)
{
    // This works only because Cocoa has already loaded it properly
    _glfw.ns.tis.bundle =
        CFBundleGetBundleWithIdentifier(CFSTR("com.apple.HIToolbox"));
    if (!_glfw.ns.tis.bundle)
    {
        _glfwInputError(GLFW_PLATFORM_ERROR,
                        "Cocoa: Failed to load HIToolbox.framework");
        return GLFW_FALSE;
    }

    CFStringRef* kPropertyUnicodeKeyLayoutData =
        CFBundleGetDataPointerForName(_glfw.ns.tis.bundle,
                                      CFSTR("kTISPropertyUnicodeKeyLayoutData"));
    _glfw.ns.tis.CopyCurrentKeyboardLayoutInputSource =
        CFBundleGetFunctionPointerForName(_glfw.ns.tis.bundle,
                                          CFSTR("TISCopyCurrentKeyboardLayoutInputSource"));
    _glfw.ns.tis.GetInputSourceProperty =
        CFBundleGetFunctionPointerForName(_glfw.ns.tis.bundle,
                                          CFSTR("TISGetInputSourceProperty"));
    _glfw.ns.tis.GetKbdType =
        CFBundleGetFunctionPointerForName(_glfw.ns.tis.bundle,
                                          CFSTR("LMGetKbdType"));

    if (!kPropertyUnicodeKeyLayoutData ||
        !TISCopyCurrentKeyboardLayoutInputSource ||
        !TISGetInputSourceProperty ||
        !LMGetKbdType)
    {
        _glfwInputError(GLFW_PLATFORM_ERROR,
                        "Cocoa: Failed to load TIS API symbols");
        return GLFW_FALSE;
    }

    _glfw.ns.tis.kPropertyUnicodeKeyLayoutData =
        *kPropertyUnicodeKeyLayoutData;

    return updateUnicodeData();
}

@interface GLFWHelper : NSObject
@end

@implementation GLFWHelper

- (void)selectedKeyboardInputSourceChanged:(NSObject* )object
{
    updateUnicodeData();
}

- (void)doNothing:(id)object
{
}

@end // GLFWHelper

@interface GLFWApplicationDelegate : NSObject <NSApplicationDelegate>
@end

@implementation GLFWApplicationDelegate

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    for (_GLFWwindow* window = _glfw.windowListHead;  window;  window = window->next)
        _glfwInputWindowCloseRequest(window);

    return NSTerminateCancel;
}

- (void)applicationDidChangeScreenParameters:(NSNotification *) notification
{
    for (_GLFWwindow* window = _glfw.windowListHead;  window;  window = window->next)
    {
        if (window->context.client != GLFW_NO_API)
            [window->context.nsgl.object update];
    }

    _glfwPollMonitorsCocoa();
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    if (_glfw.hints.init.ns.menubar)
    {
        // Menu bar setup must go between sharedApplication and finishLaunching
        // in order to properly emulate the behavior of NSApplicationMain

        if ([[NSBundle mainBundle] pathForResource:@"MainMenu" ofType:@"nib"])
        {
			id tmp = _glfw.ns.nibObjects;
            [[NSBundle mainBundle] loadNibNamed:@"MainMenu"
                                          owner:NSApp
                                topLevelObjects:&tmp];
			_glfw.ns.nibObjects = tmp;
        }
        else
            createMenuBar();
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    _glfwPostEmptyEventCocoa();
    [NSApp stop:nil];
}

- (void)applicationDidHide:(NSNotification *)notification
{
    for (int i = 0;  i < _glfw.monitorCount;  i++)
        _glfwRestoreVideoModeCocoa(_glfw.monitors[i]);
}

@end // GLFWApplicationDelegate


//////////////////////////////////////////////////////////////////////////
//////                       GLFW internal API                      //////
//////////////////////////////////////////////////////////////////////////

void* _glfwLoadLocalVulkanLoaderCocoa(void)
{
    CFBundleRef bundle = CFBundleGetMainBundle();
    if (!bundle)
        return NULL;

    CFURLRef frameworksUrl = CFBundleCopyPrivateFrameworksURL(bundle);
    if (!frameworksUrl)
        return NULL;

    CFURLRef loaderUrl = CFURLCreateCopyAppendingPathComponent(
        kCFAllocatorDefault, frameworksUrl, CFSTR("libvulkan.1.dylib"), false);
    if (!loaderUrl)
    {
        CFRelease(frameworksUrl);
        return NULL;
    }

    char path[PATH_MAX];
    void* handle = NULL;

    if (CFURLGetFileSystemRepresentation(loaderUrl, true, (UInt8*) path, sizeof(path) - 1))
        handle = _glfwPlatformLoadModule(path);

    CFRelease(loaderUrl);
    CFRelease(frameworksUrl);
    return handle;
}


//////////////////////////////////////////////////////////////////////////
//////                       GLFW platform API                      //////
//////////////////////////////////////////////////////////////////////////

GLFWbool _glfwConnectCocoa(int platformID, _GLFWplatform* platform)
{
    const _GLFWplatform cocoa =
    {
        .platformID = GLFW_PLATFORM_COCOA,
        .init = _glfwInitCocoa,
        .terminate = _glfwTerminateCocoa,
        .getCursorPos = _glfwGetCursorPosCocoa,
        .setCursorPos = _glfwSetCursorPosCocoa,
        .setCursorMode = _glfwSetCursorModeCocoa,
        .setRawMouseMotion = _glfwSetRawMouseMotionCocoa,
        .rawMouseMotionSupported = _glfwRawMouseMotionSupportedCocoa,
        .createCursor = _glfwCreateCursorCocoa,
        .createStandardCursor = _glfwCreateStandardCursorCocoa,
        .destroyCursor = _glfwDestroyCursorCocoa,
        .setCursor = _glfwSetCursorCocoa,
        .getScancodeName = _glfwGetScancodeNameCocoa,
        .getKeyScancode = _glfwGetKeyScancodeCocoa,
        .setClipboardString = _glfwSetClipboardStringCocoa,
        .getClipboardString = _glfwGetClipboardStringCocoa,
        .initJoysticks = _glfwInitJoysticksCocoa,
        .terminateJoysticks = _glfwTerminateJoysticksCocoa,
        .pollJoystick = _glfwPollJoystickCocoa,
        .getMappingName = _glfwGetMappingNameCocoa,
        .updateGamepadGUID = _glfwUpdateGamepadGUIDCocoa,
        .freeMonitor = _glfwFreeMonitorCocoa,
        .getMonitorPos = _glfwGetMonitorPosCocoa,
        .getMonitorContentScale = _glfwGetMonitorContentScaleCocoa,
        .getMonitorWorkarea = _glfwGetMonitorWorkareaCocoa,
        .getVideoModes = _glfwGetVideoModesCocoa,
        .getVideoMode = _glfwGetVideoModeCocoa,
        .getGammaRamp = _glfwGetGammaRampCocoa,
        .setGammaRamp = _glfwSetGammaRampCocoa,
        .createWindow = _glfwCreateWindowCocoa,
        .destroyWindow = _glfwDestroyWindowCocoa,
        .setWindowTitle = _glfwSetWindowTitleCocoa,
        .setWindowIcon = _glfwSetWindowIconCocoa,
        .getWindowPos = _glfwGetWindowPosCocoa,
        .setWindowPos = _glfwSetWindowPosCocoa,
        .getWindowSize = _glfwGetWindowSizeCocoa,
        .setWindowSize = _glfwSetWindowSizeCocoa,
        .setWindowSizeLimits = _glfwSetWindowSizeLimitsCocoa,
        .setWindowAspectRatio = _glfwSetWindowAspectRatioCocoa,
        .getFramebufferSize = _glfwGetFramebufferSizeCocoa,
        .getWindowFrameSize = _glfwGetWindowFrameSizeCocoa,
        .getWindowContentScale = _glfwGetWindowContentScaleCocoa,
        .iconifyWindow = _glfwIconifyWindowCocoa,
        .restoreWindow = _glfwRestoreWindowCocoa,
        .maximizeWindow = _glfwMaximizeWindowCocoa,
        .showWindow = _glfwShowWindowCocoa,
        .hideWindow = _glfwHideWindowCocoa,
        .requestWindowAttention = _glfwRequestWindowAttentionCocoa,
        .focusWindow = _glfwFocusWindowCocoa,
        .setWindowMonitor = _glfwSetWindowMonitorCocoa,
        .windowFocused = _glfwWindowFocusedCocoa,
        .windowIconified = _glfwWindowIconifiedCocoa,
        .windowVisible = _glfwWindowVisibleCocoa,
        .windowMaximized = _glfwWindowMaximizedCocoa,
        .windowHovered = _glfwWindowHoveredCocoa,
        .framebufferTransparent = _glfwFramebufferTransparentCocoa,
        .getWindowOpacity = _glfwGetWindowOpacityCocoa,
        .setWindowResizable = _glfwSetWindowResizableCocoa,
        .setWindowDecorated = _glfwSetWindowDecoratedCocoa,
        .setWindowFloating = _glfwSetWindowFloatingCocoa,
        .setWindowOpacity = _glfwSetWindowOpacityCocoa,
        .setWindowMousePassthrough = _glfwSetWindowMousePassthroughCocoa,
        .pollEvents = _glfwPollEventsCocoa,
        .waitEvents = _glfwWaitEventsCocoa,
        .waitEventsTimeout = _glfwWaitEventsTimeoutCocoa,
        .postEmptyEvent = _glfwPostEmptyEventCocoa,
        .getEGLPlatform = _glfwGetEGLPlatformCocoa,
        .getEGLNativeDisplay = _glfwGetEGLNativeDisplayCocoa,
        .getEGLNativeWindow = _glfwGetEGLNativeWindowCocoa,
        .getRequiredInstanceExtensions = _glfwGetRequiredInstanceExtensionsCocoa,
        .getPhysicalDevicePresentationSupport = _glfwGetPhysicalDevicePresentationSupportCocoa,
        .createWindowSurface = _glfwCreateWindowSurfaceCocoa
    };

    *platform = cocoa;
    return GLFW_TRUE;
}

int _glfwInitCocoa(void)
{
    @autoreleasepool {

    _glfw.ns.helper = [[GLFWHelper alloc] init];

    [NSThread detachNewThreadSelector:@selector(doNothing:)
                             toTarget:_glfw.ns.helper
                           withObject:nil];

    [NSApplication sharedApplication];

    _glfw.ns.delegate = [[GLFWApplicationDelegate alloc] init];
    if (_glfw.ns.delegate == nil)
    {
        _glfwInputError(GLFW_PLATFORM_ERROR,
                        "Cocoa: Failed to create application delegate");
        return GLFW_FALSE;
    }

    [NSApp setDelegate:_glfw.ns.delegate];

    NSEvent* (^block)(NSEvent*) = ^ NSEvent* (NSEvent* event)
    {
        if ([event modifierFlags] & NSEventModifierFlagCommand)
            [[NSApp keyWindow] sendEvent:event];

        return event;
    };

    _glfw.ns.keyUpMonitor =
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyUp
                                              handler:block];

    if (_glfw.hints.init.ns.chdir)
        changeToResourcesDirectory();

    // Press and Hold prevents some keys from emitting repeated characters
    NSDictionary* defaults = @{@"ApplePressAndHoldEnabled":@NO};
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

    [[NSNotificationCenter defaultCenter]
        addObserver:_glfw.ns.helper
           selector:@selector(selectedKeyboardInputSourceChanged:)
               name:NSTextInputContextKeyboardSelectionDidChangeNotification
             object:nil];

    createKeyTablesCocoa();

    _glfw.ns.eventSource = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (!_glfw.ns.eventSource)
        return GLFW_FALSE;

    CGEventSourceSetLocalEventsSuppressionInterval(_glfw.ns.eventSource, 0.0);

    if (!initializeTIS())
        return GLFW_FALSE;

    _glfwPollMonitorsCocoa();

    if (![[NSRunningApplication currentApplication] isFinishedLaunching])
        [NSApp run];

    // In case we are unbundled, make us a proper UI application
    if (_glfw.hints.init.ns.menubar)
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    return GLFW_TRUE;

    } // autoreleasepool
}

void _glfwTerminateCocoa(void)
{
    @autoreleasepool {

    if (_glfw.ns.inputSource)
    {
        CFRelease(_glfw.ns.inputSource);
        _glfw.ns.inputSource = NULL;
        _glfw.ns.unicodeData = nil;
    }

    if (_glfw.ns.eventSource)
    {
        CFRelease(_glfw.ns.eventSource);
        _glfw.ns.eventSource = NULL;
    }

    if (_glfw.ns.delegate)
    {
        [NSApp setDelegate:nil];
        _glfw.ns.delegate = nil;
    }

    if (_glfw.ns.helper)
    {
        [[NSNotificationCenter defaultCenter]
            removeObserver:_glfw.ns.helper
                      name:NSTextInputContextKeyboardSelectionDidChangeNotification
                    object:nil];
        [[NSNotificationCenter defaultCenter]
            removeObserver:_glfw.ns.helper];
        _glfw.ns.helper = nil;
    }

    if (_glfw.ns.keyUpMonitor)
        [NSEvent removeMonitor:_glfw.ns.keyUpMonitor];

    _glfw_free(_glfw.ns.clipboardString);

    _glfwTerminateNSGL();
    _glfwTerminateEGL();
    _glfwTerminateOSMesa();

    } // autoreleasepool
}

#endif // _GLFW_COCOA

