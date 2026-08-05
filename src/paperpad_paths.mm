#include "paperpad_paths.h"

#import <Foundation/Foundation.h>

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
