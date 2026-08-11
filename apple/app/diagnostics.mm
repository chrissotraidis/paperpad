#import "diagnostics.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "paperpad_input.h"

#include <cerrno>
#include <cstdio>
#include <fcntl.h>
#include <thread>
#include <unistd.h>

namespace {

constexpr NSUInteger kMaximumSharedLogBytes = 512u * 1024u;
constexpr size_t kMaximumStoredLogBytes = 4u * 1024u * 1024u;

NSURL* diagnosticsDirectory(NSURL* root) {
    return [root URLByAppendingPathComponent:@"Logs" isDirectory:YES];
}

NSURL* runtimeLogURL(NSURL* root) {
    return [diagnosticsDirectory(root) URLByAppendingPathComponent:@"paperpad-latest.log"];
}

NSURL* previousRuntimeLogURL(NSURL* root) {
    return [diagnosticsDirectory(root) URLByAppendingPathComponent:@"paperpad-previous.log"];
}

NSURL* activeSessionMarkerURL(NSURL* root) {
    return [diagnosticsDirectory(root) URLByAppendingPathComponent:@"paperpad-session-active"];
}

NSURL* previousSessionUncleanMarkerURL(NSURL* root) {
    return [diagnosticsDirectory(root) URLByAppendingPathComponent:@"paperpad-previous-unclean"];
}

NSURL* applicationSupportRoot() {
    NSURL* support = [[NSFileManager.defaultManager
        URLsForDirectory:NSApplicationSupportDirectory
               inDomains:NSUserDomainMask] firstObject];
    return [support URLByAppendingPathComponent:@"PaperPad" isDirectory:YES];
}

void writeAll(int descriptor, const char* bytes, size_t length) {
    while (length > 0) {
        const ssize_t written = write(descriptor, bytes, length);
        if (written > 0) {
            bytes += written;
            length -= static_cast<size_t>(written);
        } else if (written < 0 && errno == EINTR) {
            continue;
        } else {
            break;
        }
    }
}

NSString* yesNo(BOOL value) {
    return value ? @"yes" : @"no";
}

NSString* resolutionName(NSInteger mode) {
    switch (mode) {
        case 1: return @"1x";
        case 2: return @"2x";
        case 3: return @"3x";
        case 4: return @"4x";
        default: return @"Automatic";
    }
}

NSString* decodedUTF8String(NSData* data) {
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
#if !__has_feature(objc_arc)
    return [string autorelease];
#else
    return string;
#endif
}

NSString* sanitizedLogTail(NSURL* root, NSURL* logURL, NSString* unavailableMessage) {
    NSError* error = nil;
    NSFileHandle* handle = [NSFileHandle fileHandleForReadingFromURL:logURL
                                                               error:&error];
    if (handle == nil) return unavailableMessage;
    const unsigned long long length = [handle seekToEndOfFile];
    const unsigned long long offset = length > kMaximumSharedLogBytes
        ? length - kMaximumSharedLogBytes : 0;
    [handle seekToFileOffset:offset];
    NSData* data = [handle readDataOfLength:kMaximumSharedLogBytes];
    [handle closeFile];
    if (data.length == 0) return unavailableMessage;
    NSString* log = decodedUTF8String(data);
    // A tail read can start inside a multi-byte character. Runtime output is
    // normally ASCII, but skip at most three leading bytes if needed.
    for (NSUInteger skip = 1; log == nil && skip < 4 && skip < data.length; ++skip) {
        NSData* trimmed = [data subdataWithRange:NSMakeRange(skip, data.length - skip)];
        log = decodedUTF8String(trimmed);
    }
    if (log == nil) return @"The runtime log could not be decoded as UTF-8.";

    NSMutableString* sanitized = [log mutableCopy];
#if !__has_feature(objc_arc)
    [sanitized autorelease];
#endif
    NSArray<NSArray<NSString*>*>* replacements = @[
        @[root.path ?: @"", @"<APP_SUPPORT>"],
        @[NSHomeDirectory() ?: @"", @"<HOME>"],
        @[NSTemporaryDirectory() ?: @"", @"<TEMP>/"],
    ];
    for (NSArray<NSString*>* replacement in replacements) {
        if (replacement[0].length > 0) {
            [sanitized replaceOccurrencesOfString:replacement[0]
                                       withString:replacement[1]
                                          options:0
                                            range:NSMakeRange(0, sanitized.length)];
        }
    }
    return sanitized;
}

NSString* diagnosticReport(NSURL* root) {
    NSBundle* bundle = NSBundle.mainBundle;
    NSDictionary* settings = [NSUserDefaults.standardUserDefaults
        dictionaryForKey:@"paperpad.settings.v1"] ?: @{};
    NSDictionary* attributes = [NSFileManager.defaultManager
        attributesOfItemAtPath:[root URLByAppendingPathComponent:@"baserom.z64"].path
                         error:nil];
    BOOL supportedROMInstalled = [attributes[NSFileSize] unsignedLongLongValue] ==
        40ull * 1024ull * 1024ull;
    UIScreen* screen = UIScreen.mainScreen;
    CGRect bounds = screen.bounds;
    NSInteger resolution = [settings[@"resolution"] integerValue];
    if ([settings[@"schemaVersion"] integerValue] < 2 && resolution == 1) resolution = 2;

    NSMutableString* report = [NSMutableString string];
    [report appendString:@"PaperPad diagnostics\n"];
    [report appendString:@"====================\n"];
    [report appendFormat:@"Generated: %@\n", NSDate.date];
    [report appendFormat:@"App version: %@ (%@)\n",
        [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown",
        [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"unknown"];
    [report appendFormat:@"Build profile: %@\n",
        [bundle objectForInfoDictionaryKey:@"PaperPadBuildProfile"] ?: @"unknown"];
    [report appendFormat:@"Bundle: %@\n", bundle.bundleIdentifier ?: @"unknown"];
    [report appendFormat:@"System: %@ %@\n", UIDevice.currentDevice.systemName,
        UIDevice.currentDevice.systemVersion];
    [report appendFormat:@"Device: %@ (%@)\n", UIDevice.currentDevice.model,
        UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"tablet" : @"phone"];
    [report appendFormat:@"Screen: %.0fx%.0f points @ %.2fx\n",
        bounds.size.width, bounds.size.height, screen.nativeScale];
    [report appendFormat:@"ROM installed: %@\n", yesNo(supportedROMInstalled)];
    [report appendFormat:@"Resolution: %@\n", resolutionName(resolution)];
    uint32_t effectiveScaleMilli = 0;
    uint32_t internalWidth = 0;
    uint32_t internalHeight = 0;
    if (PaperPad_GetEffectiveRenderState(
            &effectiveScaleMilli, &internalWidth, &internalHeight)) {
        [report appendFormat:@"Renderer-confirmed: %.2fx, %ux%u internal\n",
            effectiveScaleMilli / 1000.0, internalWidth, internalHeight];
    } else {
        [report appendString:@"Renderer-confirmed: not available yet\n"];
    }
    [report appendFormat:@"Aspect ratio: %@\n",
        [settings[@"aspect"] integerValue] == 1 ? @"Fill Screen" : @"Original (4:3)"];
    [report appendString:@"Image filter: Smooth (fixed)\n"];
    [report appendFormat:@"Touch controls: %@\n",
        yesNo(settings[@"touchControls"] == nil || [settings[@"touchControls"] boolValue])];
    const double opacity = settings[@"touchOpacity"] == nil
        ? 0.70 : [settings[@"touchOpacity"] doubleValue];
    [report appendFormat:@"Touch opacity: %.0f%%\n", opacity * 100.0];
    [report appendString:@"\nPrivacy note: this report excludes ROM and save contents. "];
    [report appendString:@"Review runtime text before choosing a share destination.\n\n"];
    const BOOL previousMayBeUnclean = [NSFileManager.defaultManager
        fileExistsAtPath:previousSessionUncleanMarkerURL(root).path];
    if (previousMayBeUnclean) {
        [report appendString:@"Previous-session runtime log (possible crash; last 512 KiB)\n"];
        [report appendString:@"--------------------------------------------------------------\n"];
        [report appendString:sanitizedLogTail(
            root, previousRuntimeLogURL(root), @"No previous-session runtime log was available.")];
        [report appendString:@"\n\n"];
    }
    [report appendString:@"Current-session runtime log (last 512 KiB)\n"];
    [report appendString:@"----------------------------------------------\n"];
    [report appendString:sanitizedLogTail(
        root, runtimeLogURL(root), @"No current-session runtime log was available.")];
    if (!previousMayBeUnclean) {
        [report appendString:@"\n\nPrevious-session runtime log (last 512 KiB)\n"];
        [report appendString:@"-----------------------------------------------\n"];
        [report appendString:sanitizedLogTail(
            root, previousRuntimeLogURL(root), @"No previous-session runtime log was available.")];
    }
    return report;
}

void createPrivateMarker(NSURL* marker) {
    const int descriptor = open(marker.fileSystemRepresentation,
                                O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (descriptor >= 0) close(descriptor);
}

} // namespace

void paperpad_start_diagnostics_log(void* application_support_root) {
    NSURL* root = (__bridge NSURL*)application_support_root;
    if (root == nil) return;

    NSError* error = nil;
    NSURL* directory = diagnosticsDirectory(root);
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory
                                withIntermediateDirectories:YES
                                                 attributes:@{
        NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication,
    } error:&error]) {
        std::fprintf(stderr, "[PaperPad] diagnostics log directory unavailable: %s\n",
                     error.localizedDescription.UTF8String);
        return;
    }
    [directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];

    NSFileManager* files = NSFileManager.defaultManager;
    NSURL* latest = runtimeLogURL(root);
    NSURL* previous = previousRuntimeLogURL(root);
    NSURL* activeMarker = activeSessionMarkerURL(root);
    NSURL* uncleanMarker = previousSessionUncleanMarkerURL(root);
    const BOOL hadLatest = [files fileExistsAtPath:latest.path];
    const BOOL previousSessionMayBeUnclean = hadLatest &&
        [files fileExistsAtPath:activeMarker.path];

    [files removeItemAtURL:previous error:nil];
    if (hadLatest && ![files moveItemAtURL:latest toURL:previous error:&error]) {
        std::fprintf(stderr, "[PaperPad] previous diagnostics log could not be rotated: %s\n",
                     error.localizedDescription.UTF8String);
    }
    [files removeItemAtURL:uncleanMarker error:nil];
    if (previousSessionMayBeUnclean) createPrivateMarker(uncleanMarker);
    [files removeItemAtURL:activeMarker error:nil];
    createPrivateMarker(activeMarker);

    const int logDescriptor = open(latest.fileSystemRepresentation,
                                   O_WRONLY | O_CREAT | O_TRUNC, 0600);
    int pipeDescriptors[2] = {-1, -1};
    const int originalStderr = dup(STDERR_FILENO);
    if (logDescriptor < 0 || originalStderr < 0 || pipe(pipeDescriptors) != 0 ||
        dup2(pipeDescriptors[1], STDERR_FILENO) < 0) {
        if (logDescriptor >= 0) close(logDescriptor);
        if (originalStderr >= 0) close(originalStderr);
        if (pipeDescriptors[0] >= 0) close(pipeDescriptors[0]);
        if (pipeDescriptors[1] >= 0) close(pipeDescriptors[1]);
        std::fprintf(stderr, "[PaperPad] diagnostics log capture could not start\n");
        return;
    }
    close(pipeDescriptors[1]);
    setvbuf(stderr, nullptr, _IONBF, 0);

    std::thread([readDescriptor = pipeDescriptors[0], originalStderr, logDescriptor] {
        size_t storedBytes = 0;
        char buffer[4096];
        for (;;) {
            const ssize_t count = read(readDescriptor, buffer, sizeof(buffer));
            if (count > 0) {
                writeAll(originalStderr, buffer, static_cast<size_t>(count));
                if (storedBytes + static_cast<size_t>(count) > kMaximumStoredLogBytes) {
                    static constexpr char rotation[] =
                        "[PaperPad] earlier current-session log text was rotated\n";
                    ftruncate(logDescriptor, 0);
                    lseek(logDescriptor, 0, SEEK_SET);
                    writeAll(logDescriptor, rotation, sizeof(rotation) - 1);
                    storedBytes = sizeof(rotation) - 1;
                }
                writeAll(logDescriptor, buffer, static_cast<size_t>(count));
                storedBytes += static_cast<size_t>(count);
            } else if (count < 0 && errno == EINTR) {
                continue;
            } else {
                break;
            }
        }
        close(readDescriptor);
        close(originalStderr);
        close(logDescriptor);
    }).detach();

    std::fprintf(stderr, "[PaperPad] private current-session diagnostics log started\n");
}

void paperpad_finish_diagnostics_log(void* application_support_root) {
    NSURL* root = (__bridge NSURL*)application_support_root;
    if (root == nil) return;
    std::fprintf(stderr, "[PaperPad] clean process exit reached\n");
    [NSFileManager.defaultManager removeItemAtURL:activeSessionMarkerURL(root) error:nil];
}

void paperpad_present_diagnostics_share(void* presenter_pointer,
                                        void (^completion)(void)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController* presenter = (__bridge UIViewController*)presenter_pointer;
        if (presenter == nil) return;
        while (presenter.presentedViewController != nil) {
            presenter = presenter.presentedViewController;
        }

        NSURL* root = applicationSupportRoot();
        NSURL* reportURL = [NSURL fileURLWithPath:[NSTemporaryDirectory()
            stringByAppendingPathComponent:@"PaperPad-Diagnostics.txt"]];
        NSError* error = nil;
        if (![diagnosticReport(root) writeToURL:reportURL
                                     atomically:YES
                                       encoding:NSUTF8StringEncoding
                                          error:&error]) {
            UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:@"Diagnostics Unavailable"
                                 message:error.localizedDescription
                          preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(__unused UIAlertAction* action) {
                if (completion != nil) completion();
            }]];
            [presenter presentViewController:alert animated:YES completion:nil];
            return;
        }

        UIActivityViewController* share = [[UIActivityViewController alloc]
            initWithActivityItems:@[reportURL] applicationActivities:nil];
        share.completionWithItemsHandler = ^(__unused UIActivityType activityType,
                                             __unused BOOL completed,
                                             __unused NSArray* returnedItems,
                                             __unused NSError* activityError) {
            if (completion != nil) completion();
        };
        share.modalPresentationStyle = UIModalPresentationPopover;
        UIPopoverPresentationController* popover = share.popoverPresentationController;
        if (popover != nil) {
            popover.sourceView = presenter.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                            CGRectGetMidY(presenter.view.bounds), 1.0, 1.0);
            popover.permittedArrowDirections = 0;
        }
        [presenter presentViewController:share animated:YES completion:nil];
#if !__has_feature(objc_arc)
        [share release];
#endif
    });
}
