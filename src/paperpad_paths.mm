#include "paperpad_paths.h"

#import <Foundation/Foundation.h>
#include <cstdio>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

const char* paperpad_apple_application_support_dir(void) {
    NSArray<NSURL*>* urls = [[NSFileManager defaultManager]
        URLsForDirectory:NSApplicationSupportDirectory
        inDomains:NSUserDomainMask];
    NSURL* url = [urls firstObject];
    if (url == nil) {
        return nullptr;
    }
    NSURL* paperpad = [url URLByAppendingPathComponent:@"PaperPad" isDirectory:YES];
    NSError* error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:paperpad
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error]) {
        std::fprintf(stderr, "[paperpad] could not create Application Support directory: %s\n",
                     [[error localizedDescription] UTF8String]);
        return nullptr;
    }
    return strdup([[paperpad path] UTF8String]);
}

const char* paperpad_apple_choose_rom_path(void) {
#if TARGET_OS_IPHONE
    return nullptr;
#else
    @autoreleasepool {
        NSOpenPanel* panel = [NSOpenPanel openPanel];
        panel.title = @"Choose Paper Mario (US) 1.0 ROM";
        panel.message = @"PaperPad accepts .z64, .v64, and .n64 files and validates the exact supported revision.";
        panel.prompt = @"Choose ROM";
        panel.canChooseDirectories = NO;
        panel.allowsMultipleSelection = NO;
        panel.allowedFileTypes = @[@"z64", @"v64", @"n64"];
        if ([panel runModal] != NSModalResponseOK || panel.URL == nil) {
            return nullptr;
        }
        return strdup([[panel.URL path] UTF8String]);
    }
#endif
}

#if TARGET_OS_IPHONE
void paperpad_log_window_diagnostics(void* ui_window, void* metal_layer) {
    UIWindow* window = (__bridge UIWindow*)ui_window;
    UIScreen* screen = window.screen ?: [UIScreen mainScreen];
    CGRect bounds = window.bounds;
    CGRect screenBounds = screen.bounds;
    CGSize screenMode = screen.currentMode.size;
    CGSize screenNative = screen.nativeBounds.size;
    CAMetalLayer* layer = (__bridge CAMetalLayer*)metal_layer;
    CGSize drawable = layer.drawableSize;
    std::fprintf(stderr,
        "[paperpad] diag: ui_window=%p bounds=%.0fx%.0f scale=%.2f nativeScale=%.2f "
        "screen=%.0fx%.0f mode=%.0fx%.0f native=%.0fx%.0f "
        "layer=%p drawable=%.0fx%.0f layerBounds=%.0fx%.0f layerContentsScale=%.2f\n",
        window, bounds.size.width, bounds.size.height, screen.scale, screen.nativeScale,
        screenBounds.size.width, screenBounds.size.height,
        screenMode.width, screenMode.height, screenNative.width, screenNative.height,
        layer, drawable.width, drawable.height, layer.bounds.size.width,
        layer.bounds.size.height, layer.contentsScale);
}

// RT64's iOS CocoaWindow reports the swapchain size in PIXELS (window points
// x nativeScale), but SDL leaves the CAMetalLayer at contentsScale 1.0, so
// the actual drawable is point-sized (half/third of the swapchain's assumed
// size). The present math then sizes the frame for the larger surface and the
// GPU clips it to the smaller drawable — the "zoomed in, right side cut off"
// look. Align the layer with the swapchain: contentsScale = screen native
// scale and drawableSize = bounds x nativeScale.
void paperpad_fix_metal_layer_scale(void* ui_window, void* metal_layer) {
    UIWindow* window = (__bridge UIWindow*)ui_window;
    if (window == nullptr || metal_layer == nullptr) return;
    UIScreen* screen = window.screen ?: [UIScreen mainScreen];
    CGFloat scale = screen.nativeScale > 0.0 ? screen.nativeScale : screen.scale;
    if (scale <= 0.0) return;
    CAMetalLayer* layer = (__bridge CAMetalLayer*)metal_layer;
    layer.contentsScale = scale;
    CGRect bounds = window.bounds;
    layer.drawableSize = CGSizeMake(bounds.size.width * scale,
                                    bounds.size.height * scale);
}
#else
void paperpad_log_window_diagnostics(void*, void*) {}
void paperpad_fix_metal_layer_scale(void*, void*) {}
#endif
