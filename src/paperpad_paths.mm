#include "paperpad_paths.h"

#import <Foundation/Foundation.h>
#include <cstdio>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

const char* paperpad_apple_application_support_dir(void) {
    NSArray<NSURL*>* urls = [[NSFileManager defaultManager]
        URLsForDirectory:NSApplicationSupportDirectory
        inDomains:NSUserDomainMask];
    NSURL* url = [urls firstObject];
    if (url == nil) {
        return nullptr;
    }
    return strdup([[url path] UTF8String]);
}

#if TARGET_OS_IPHONE
void paperpad_log_window_diagnostics(void* ui_window, void* metal_layer) {
    UIWindow* window = (__bridge UIWindow*)ui_window;
    UIScreen* screen = window.screen ?: [UIScreen mainScreen];
    CGRect bounds = window.bounds;
    CAMetalLayer* layer = (__bridge CAMetalLayer*)metal_layer;
    CGSize drawable = layer.drawableSize;
    std::fprintf(stderr,
        "[paperpad] diag: ui_window=%p bounds=%.0fx%.0f scale=%.2f nativeScale=%.2f "
        "layer=%p drawable=%.0fx%.0f layerBounds=%.0fx%.0f layerContentsScale=%.2f\n",
        window, bounds.size.width, bounds.size.height, screen.scale, screen.nativeScale,
        layer, drawable.width, drawable.height, layer.bounds.size.width,
        layer.bounds.size.height, layer.contentsScale);
}
#else
void paperpad_log_window_diagnostics(void*, void*) {}
#endif
