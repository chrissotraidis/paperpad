#include <array>
#include <atomic>
#include <cmath>
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <unordered_map>
#include <unistd.h>

#include <SDL.h>
#include <TargetConditionals.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "rom_setup.h"
#include "diagnostics.h"
#include "touch_tap_latch.h"
#include "paperpad_input.h"

extern "C" int paperpad_recomp_main(int argc, char** argv);

@class PaperPadTouchOverlayView;
@class PaperPadSettingsViewController;

@interface PaperPadSettingsViewController : UIViewController
- (void)refreshFromDefaults;
@end

namespace {

std::atomic<uint16_t> g_touch_buttons{0};
std::atomic_bool g_physical_controller_connected{false};
static PaperPadTouchOverlayView* g_touch_overlay = nullptr;
PaperPadTouchTapLatch g_touch_taps;
std::atomic<int32_t> g_touch_x{0};
std::atomic<int32_t> g_touch_y{0};
std::atomic<int32_t> g_touch_flick_x{0};
std::atomic<int32_t> g_touch_flick_y{0};
std::atomic<uint8_t> g_touch_flick_polls{0};

constexpr uint8_t kTapHoldPolls = 6;
// Preserve a very short released flick for one runtime poll. Replaying it for
// several polls makes grid/name-entry selectors overshoot after the thumb has
// already returned to neutral.
constexpr uint8_t kAnalogFlickHoldPolls = 1;

enum class ControlKind { Stick, Button };

struct TouchControl {
    const char* key;
    const char* label;
    ControlKind kind;
    uint16_t mask;
    CGFloat x;
    CGFloat y;
    CGFloat size;
    CGFloat opacity;
    bool visible;
};

constexpr size_t kControlCount = 15;

std::array<TouchControl, kControlCount> defaultControls() {
    // Adapt HarkinianPad's physically accepted grip-first phone/tablet layouts
    // to PaperPad's direct analog N64 input bridge. The game-specific native HUD
    // artwork and synthetic SDL-key path deliberately remain HarkinianPad-only.
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return {{
            {"stick", "", ControlKind::Stick, 0x0000, 0.164, 0.745, 0.090, 0.42, true},
            {"d_up", "\u2191", ControlKind::Button, 0x0800, 0.080, 0.550, 0.032, 0.42, true},
            {"d_down", "\u2193", ControlKind::Button, 0x0400, 0.080, 0.665, 0.032, 0.42, true},
            {"d_left", "\u2190", ControlKind::Button, 0x0200, 0.040, 0.608, 0.032, 0.42, true},
            {"d_right", "\u2192", ControlKind::Button, 0x0100, 0.120, 0.608, 0.032, 0.42, true},
            {"c_up", "\u2191", ControlKind::Button, 0x0008, 0.9036, 0.8048, 0.033, 0.42, true},
            {"c_down", "\u2193", ControlKind::Button, 0x0004, 0.9036, 0.9098, 0.033, 0.42, true},
            {"c_left", "\u2190", ControlKind::Button, 0x0002, 0.8610, 0.8573, 0.033, 0.42, true},
            {"c_right", "\u2192", ControlKind::Button, 0x0001, 0.9462, 0.8573, 0.033, 0.42, true},
            {"a", "A", ControlKind::Button, 0x8000, 0.893, 0.693, 0.048, 0.48, true},
            {"b", "B", ControlKind::Button, 0x4000, 0.826, 0.635, 0.048, 0.48, true},
            {"z", "Z", ControlKind::Button, 0x2000, 0.897, 0.581, 0.048, 0.44, true},
            {"l", "L", ControlKind::Button, 0x0020, 0.941, 0.460, 0.041, 0.38, true},
            {"r", "R", ControlKind::Button, 0x0010, 0.941, 0.374, 0.041, 0.38, true},
            {"start", "START", ControlKind::Button, 0x1000, 0.942, 0.291, 0.033, 0.40, true},
        }};
    }
    // The phone radii normalize HarkinianPad's accepted 116-point stick,
    // 52-point face, 44-point D/shoulder, and 40-point C-button targets. Its
    // single Z stays in the right face cluster so the left thumb can move.
    // These defaults reproduce the accepted physical iPhone 14 arrangement
    // captured from PaperPad on 2026-08-14.
    return {{
        {"stick", "", ControlKind::Stick, 0x0000, 0.141000, 0.783020, 0.1480, 0.38, true},
        {"d_up", "\u2191", ControlKind::Button, 0x0800, 0.087000, 0.358732, 0.0560, 0.38, true},
        {"d_down", "\u2193", ControlKind::Button, 0x0400, 0.083889, 0.541144, 0.0560, 0.38, true},
        {"d_left", "\u2190", ControlKind::Button, 0x0200, 0.038111, 0.444018, 0.0560, 0.38, true},
        {"d_right", "\u2192", ControlKind::Button, 0x0100, 0.132778, 0.449483, 0.0560, 0.38, true},
        // Keep every right-hand target physically separate. Shoulder buttons
        // are wider than their nominal radius, so their vertical spacing must
        // also leave room for the C cluster below them.
        {"c_up", "\u2191", ControlKind::Button, 0x0008, 0.924667, 0.337299, 0.0510, 0.52, true},
        {"c_down", "\u2193", ControlKind::Button, 0x0004, 0.926444, 0.522319, 0.0510, 0.52, true},
        {"c_left", "\u2190", ControlKind::Button, 0x0002, 0.882667, 0.424800, 0.0510, 0.52, true},
        {"c_right", "\u2192", ControlKind::Button, 0x0001, 0.967111, 0.427532, 0.0510, 0.52, true},
        {"a", "A", ControlKind::Button, 0x8000, 0.929889, 0.843679, 0.0858, 0.58, true},
        {"b", "B", ControlKind::Button, 0x4000, 0.850556, 0.736266, 0.0792, 0.58, true},
        {"z", "Z", ControlKind::Button, 0x2000, 0.924444, 0.671894, 0.0660, 0.40, true},
        {"l", "L", ControlKind::Button, 0x0020, 0.945778, 0.188033, 0.0500, 0.36, true},
        {"r", "R", ControlKind::Button, 0x0010, 0.946222, 0.078515, 0.0500, 0.36, true},
        {"start", "START", ControlKind::Button, 0x1000, 0.873667, 0.068944, 0.0500, 0.54, true},
    }};
}

NSString* layoutDefaultsKey() {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad
        ? @"paperpad.touch.layout.ipad.v4"
        : @"paperpad.touch.layout.iphone.v8";
}

NSString* settingsDefaultsKey() {
    return @"paperpad.settings.v1";
}

NSInteger resolutionModeFromSettings(NSDictionary* settings) {
    NSInteger resolution = settings[@"resolution"] == nil
        ? 0 : [settings[@"resolution"] integerValue];
    // Version 1 exposed only Auto (0) and 2x (1). Preserve that preference
    // after adding explicit 1x-4x choices.
    if ([settings[@"schemaVersion"] integerValue] < 2 && resolution == 1) {
        resolution = 2;
    }
    return MAX(0, MIN(4, resolution));
}

} // namespace

@interface PaperPadTouchOverlayView : UIView
- (void)beginEditingLayout;
- (void)resetLayout;
- (void)setGameplayControlsEnabled:(BOOL)enabled opacity:(CGFloat)opacity;
- (void)setPhysicalControllerConnected:(BOOL)connected;
- (void)setModalControlsHidden:(BOOL)hidden;
@end

@implementation PaperPadTouchOverlayView {
    std::array<TouchControl, kControlCount> _controls;
    std::array<TouchControl, kControlCount> _undoControls;
    std::unordered_map<UITouch*, int> _touchRoles;
    std::unordered_map<UITouch*, CGPoint> _touchOffsets;
    CGPoint _stickOrigin;
    CGPoint _stickKnob;
    BOOL _editing;
    BOOL _hasUndo;
    BOOL _dPadLinked;
    BOOL _cButtonsLinked;
    BOOL _undoDPadLinked;
    BOOL _undoCButtonsLinked;
    NSInteger _selected;
    BOOL _gameplayControlsEnabled;
    BOOL _physicalControllerConnected;
    BOOL _modalControlsHidden;
    CGFloat _globalOpacity;
    UIButton* _utilityButton;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.multipleTouchEnabled = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _controls = defaultControls();
        _selected = 9;
        _gameplayControlsEnabled = YES;
        _globalOpacity = 0.70;
        _utilityButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_utilityButton setTitle:@"\u2022\u2022\u2022" forState:UIControlStateNormal];
        _utilityButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0];
        _utilityButton.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.64];
        _utilityButton.layer.cornerRadius = 22.0;
        _utilityButton.layer.borderWidth = 1.0;
        _utilityButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.34].CGColor;
        _utilityButton.accessibilityLabel = @"PaperPad Menu";
        _utilityButton.accessibilityHint = @"Opens settings and game setup";
        [_utilityButton addTarget:self action:@selector(presentUtilityMenu)
                 forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_utilityButton];
        [self loadLayout];
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(clearInput)
                   name:UIApplicationWillResignActiveNotification
                 object:nil];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _utilityButton.frame = [self utilityButtonRect];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (UIEdgeInsets)usableInsets {
    UIEdgeInsets insets = self.safeAreaInsets;
    insets.top += 2.0;
    insets.bottom += 2.0;
    return insets;
}

- (CGRect)usableBounds {
    return UIEdgeInsetsInsetRect(self.bounds, [self usableInsets]);
}

- (CGFloat)baseDimension {
    CGRect usable = [self usableBounds];
    return MIN(usable.size.width, usable.size.height);
}

- (BOOL)isShoulderControl:(const TouchControl&)control {
    return std::strcmp(control.key, "l") == 0 || std::strcmp(control.key, "r") == 0;
}

- (BOOL)isDirectionalControl:(const TouchControl&)control {
    return std::strncmp(control.key, "d_", 2) == 0 ||
           std::strncmp(control.key, "c_", 2) == 0;
}

- (BOOL)isControlInSelectedMoveGroup:(NSInteger)index {
    if (_selected < 0 || _selected >= (NSInteger)kControlCount ||
        index < 0 || index >= (NSInteger)kControlCount) return NO;
    const TouchControl& selected = _controls[_selected];
    const TouchControl& candidate = _controls[index];
    if (_dPadLinked && std::strncmp(selected.key, "d_", 2) == 0) {
        return std::strncmp(candidate.key, "d_", 2) == 0;
    }
    if (_cButtonsLinked && std::strncmp(selected.key, "c_", 2) == 0) {
        return std::strncmp(candidate.key, "c_", 2) == 0;
    }
    return index == _selected;
}

- (BOOL)isSelectedDirectionalGroupLinked {
    if (_selected < 0 || _selected >= (NSInteger)kControlCount) return NO;
    const TouchControl& selected = _controls[_selected];
    if (std::strncmp(selected.key, "d_", 2) == 0) return _dPadLinked;
    if (std::strncmp(selected.key, "c_", 2) == 0) return _cButtonsLinked;
    return NO;
}

- (UIColor*)accentColorForControl:(const TouchControl&)control {
    if (std::strcmp(control.key, "a") == 0) {
        return [UIColor colorWithRed:0.10 green:0.34 blue:0.88 alpha:1.0];
    }
    if (std::strcmp(control.key, "b") == 0) {
        return [UIColor colorWithRed:0.05 green:0.58 blue:0.28 alpha:1.0];
    }
    if (std::strncmp(control.key, "c_", 2) == 0) {
        return [UIColor colorWithRed:0.94 green:0.63 blue:0.06 alpha:1.0];
    }
    if (std::strcmp(control.key, "start") == 0) {
        return [UIColor colorWithRed:0.78 green:0.10 blue:0.12 alpha:1.0];
    }
    return nil;
}

- (CGPoint)centerForControl:(const TouchControl&)control {
    CGRect usable = [self usableBounds];
    CGFloat radius = control.size * [self baseDimension];
    CGFloat halfWidth = [self isShoulderControl:control] ? radius * 1.65 : radius;
    CGFloat x = CGRectGetMinX(usable) + control.x * usable.size.width;
    CGFloat y = CGRectGetMinY(usable) + control.y * usable.size.height;
    x = MAX(CGRectGetMinX(usable) + halfWidth, MIN(CGRectGetMaxX(usable) - halfWidth, x));
    y = MAX(CGRectGetMinY(usable) + radius, MIN(CGRectGetMaxY(usable) - radius, y));
    return CGPointMake(x, y);
}

- (CGFloat)radiusForControl:(const TouchControl&)control {
    return control.size * [self baseDimension];
}

- (CGRect)frameForControl:(const TouchControl&)control {
    CGPoint center = [self centerForControl:control];
    CGFloat radius = [self radiusForControl:control];
    CGFloat halfWidth = [self isShoulderControl:control] ? radius * 1.65 : radius;
    return CGRectMake(center.x - halfWidth, center.y - radius,
                      halfWidth * 2.0, radius * 2.0);
}

- (CGFloat)defaultSizeForControl:(const TouchControl&)control {
    std::array<TouchControl, kControlCount> defaults = defaultControls();
    for (const TouchControl& candidate : defaults) {
        if (std::strcmp(candidate.key, control.key) == 0) return candidate.size;
    }
    return control.size;
}

- (void)loadLayout {
    NSDictionary* saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:layoutDefaultsKey()];
    if (![saved isKindOfClass:NSDictionary.class]) return;
    NSDictionary* groups = saved[@"_groups"];
    if ([groups isKindOfClass:NSDictionary.class]) {
        _dPadLinked = [groups[@"dPadLinked"] boolValue];
        _cButtonsLinked = [groups[@"cButtonsLinked"] boolValue];
    }
    for (TouchControl& control : _controls) {
        NSString* key = [NSString stringWithUTF8String:control.key];
        NSDictionary* value = saved[key];
        if (![value isKindOfClass:NSDictionary.class]) continue;
        control.x = [value[@"x"] doubleValue];
        control.y = [value[@"y"] doubleValue];
        control.size = [value[@"size"] doubleValue];
        control.opacity = [value[@"opacity"] doubleValue];
        control.visible = value[@"visible"] == nil || [value[@"visible"] boolValue];
    }
}

- (void)saveLayout {
    NSMutableDictionary* saved = [NSMutableDictionary dictionaryWithCapacity:kControlCount];
    for (const TouchControl& control : _controls) {
        NSString* key = [NSString stringWithUTF8String:control.key];
        saved[key] = @{
            @"x": @(control.x), @"y": @(control.y),
            @"size": @(control.size), @"opacity": @(control.opacity),
            @"visible": @(control.visible),
        };
    }
    saved[@"_groups"] = @{
        @"dPadLinked": @(_dPadLinked),
        @"cButtonsLinked": @(_cButtonsLinked),
    };
    [NSUserDefaults.standardUserDefaults setObject:saved forKey:layoutDefaultsKey()];
}

- (NSArray<NSString*>*)toolbarLabels {
    BOOL hasSelection = _selected >= 0 && _selected < (NSInteger)kControlCount;
    BOOL selectedVisible = hasSelection ? _controls[_selected].visible : YES;
    BOOL selectedHideable = hasSelection && _controls[_selected].kind != ControlKind::Stick;
    NSString* linkLabel = !hasSelection || ![self isDirectionalControl:_controls[_selected]]
        ? @"SINGLE" : ([self isSelectedDirectionalGroupLinked] ? @"UNLINK" : @"LINK");
    return @[@"DONE", _hasUndo ? @"UNDO" : @"RESET", linkLabel, @"\u2212", @"+", @"FADE",
             !selectedHideable ? @"FIXED" : (selectedVisible ? @"HIDE" : @"SHOW")];
}

- (CGRect)utilityButtonRect {
    CGRect usable = [self usableBounds];
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) {
        // Match the reference compact layout: keep the persistent menu in a
        // dedicated top-center phone slot, away from the right-side cluster.
        return CGRectMake(CGRectGetMidX(usable) - 22.0,
                          CGRectGetMinY(usable) + 4.0, 44.0, 44.0);
    }
    // Tablet layout keeps the standard top-right menu position.
    return CGRectMake(CGRectGetMaxX(usable) - 48.0,
                      CGRectGetMinY(usable) + 4.0, 44.0, 44.0);
}

- (CGRect)toolbarRectAtIndex:(NSInteger)index {
    CGRect usable = [self usableBounds];
    CGFloat width = MIN(64.0, usable.size.width / 8.0);
    CGFloat total = width * 7.0;
    return CGRectMake(CGRectGetMidX(usable) - total / 2.0 + width * index,
                      CGRectGetMinY(usable) + 4.0, width, 44.0);
}

- (void)drawLabel:(NSString*)label inRect:(CGRect)rect color:(UIColor*)color size:(CGFloat)size {
    NSMutableParagraphStyle* style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    NSDictionary* attributes = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:size],
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: style,
    };
    CGSize textSize = [label sizeWithAttributes:attributes];
    CGRect textRect = CGRectMake(rect.origin.x,
                                 CGRectGetMidY(rect) - textSize.height / 2.0,
                                 rect.size.width, textSize.height);
    [label drawInRect:textRect withAttributes:attributes];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == nullptr) return;

    for (NSInteger index = 0; index < (NSInteger)kControlCount; ++index) {
        const TouchControl& control = _controls[index];
        if (!_editing && (!_gameplayControlsEnabled || _physicalControllerConnected ||
                          _modalControlsHidden)) continue;
        if (!control.visible && !_editing) continue;
        CGPoint center = [self centerForControl:control];
        CGFloat radius = [self radiusForControl:control];
        CGRect controlFrame = [self frameForControl:control];
        UIBezierPath* controlPath = [self isShoulderControl:control]
            ? [UIBezierPath bezierPathWithRoundedRect:controlFrame cornerRadius:radius]
            : [UIBezierPath bezierPathWithOvalInRect:controlFrame];
        CGFloat alpha = _editing
            ? (control.visible ? 0.82 : 0.26)
            : MIN(1.0, control.opacity * (_globalOpacity / 0.70));
        BOOL pressed = NO;
        for (const auto& item : _touchRoles) {
            if (item.second == index) {
                pressed = YES;
                break;
            }
        }
        UIColor* accent = [self accentColorForControl:control];
        UIColor* fill = accent != nil
            ? [accent colorWithAlphaComponent:pressed ? MIN(0.92, alpha + 0.24) : alpha]
            : [UIColor colorWithWhite:pressed ? 0.34 : 0.04
                                 alpha:pressed ? MIN(0.88, alpha + 0.30) : alpha];
        const BOOL selectedForEditing = _editing && [self isControlInSelectedMoveGroup:index];
        UIColor* stroke = selectedForEditing
            ? [UIColor colorWithRed:1.0 green:0.82 blue:0.18 alpha:0.95]
            : [UIColor colorWithWhite:1.0 alpha:MIN(0.88, alpha + 0.28)];
        [fill setFill];
        [controlPath fill];
        [stroke setStroke];
        controlPath.lineWidth = selectedForEditing ? 3.0 : 2.0;
        if (!control.visible) CGContextSetLineDash(context, 0, (CGFloat[]){4.0, 3.0}, 2);
        [controlPath stroke];
        CGContextSetLineDash(context, 0, nullptr, 0);

        if (control.kind == ControlKind::Stick) {
            CGPoint knob = pressed ? _stickKnob : center;
            if (CGPointEqualToPoint(knob, CGPointZero)) knob = center;
            CGFloat knobRadius = radius * 0.42;
            UIColor* knobColor = [UIColor colorWithRed:0.30 green:0.59 blue:0.82
                                                  alpha:MIN(0.82, alpha + 0.22)];
            CGContextSetFillColorWithColor(context, knobColor.CGColor);
            CGContextFillEllipseInRect(context,
                CGRectMake(knob.x - knobRadius, knob.y - knobRadius,
                           knobRadius * 2.0, knobRadius * 2.0));
        } else {
            CGFloat labelScale = [self isDirectionalControl:control] ? 0.72 : 0.66;
            if (std::strcmp(control.key, "start") == 0) labelScale = 0.34;
            if ([self isShoulderControl:control]) labelScale = 0.56;
            [self drawLabel:[NSString stringWithUTF8String:control.label] inRect:controlFrame
                      color:[UIColor colorWithWhite:1.0 alpha:0.92]
                       size:MAX(11.0, radius * labelScale)];
        }
    }

    if (_editing) {
        NSArray<NSString*>* labels = [self toolbarLabels];
        CGRect first = [self toolbarRectAtIndex:0];
        CGRect last = [self toolbarRectAtIndex:6];
        CGRect toolbar = CGRectUnion(first, last);
        UIBezierPath* toolbarPath = [UIBezierPath bezierPathWithRoundedRect:toolbar
                                                              cornerRadius:10.0];
        [[UIColor colorWithWhite:0.02 alpha:0.84] setFill];
        [toolbarPath fill];
        [[UIColor colorWithWhite:1.0 alpha:0.28] setStroke];
        toolbarPath.lineWidth = 1.0;
        [toolbarPath stroke];
        for (NSInteger i = 0; i < 7; ++i) {
            CGRect item = [self toolbarRectAtIndex:i];
            if (i > 0) {
                CGFloat x = CGRectGetMinX(item);
                [[UIColor colorWithWhite:1.0 alpha:0.18] setStroke];
                UIBezierPath* divider = [UIBezierPath bezierPath];
                [divider moveToPoint:CGPointMake(x, CGRectGetMinY(item) + 7.0)];
                [divider addLineToPoint:CGPointMake(x, CGRectGetMaxY(item) - 7.0)];
                divider.lineWidth = 1.0;
                [divider stroke];
            }
            [self drawLabel:labels[i] inRect:item color:UIColor.whiteColor size:11.0];
        }
    }
}

- (NSInteger)controlAtPoint:(CGPoint)point includeHidden:(BOOL)includeHidden {
    if (!_editing && (!_gameplayControlsEnabled || _physicalControllerConnected ||
                      _modalControlsHidden)) return NSNotFound;
    NSInteger nearest = NSNotFound;
    CGFloat nearestDistance = CGFLOAT_MAX;
    for (NSInteger index = 0; index < (NSInteger)kControlCount; ++index) {
        const TouchControl& control = _controls[index];
        if (!control.visible && !includeHidden) continue;
        CGPoint center = [self centerForControl:control];
        CGFloat distance = hypot(point.x - center.x, point.y - center.y);
        CGFloat radius = [self radiusForControl:control];
        BOOL inside = [self isShoulderControl:control]
            ? CGRectContainsPoint(CGRectInset([self frameForControl:control], -radius * 0.12, -radius * 0.12), point)
            : distance <= radius * 1.12;
        if (inside && distance < nearestDistance) {
            nearest = index;
            nearestDistance = distance;
        }
    }
    return nearest;
}

- (void)presentUtilityMenu {
    [self clearInput];
    [self setModalControlsHidden:YES];
    UIViewController* presenter = self.window.rootViewController;
    while (presenter.presentedViewController != nil) {
        presenter = presenter.presentedViewController;
    }
    if (presenter == nil) {
        [self setModalControlsHidden:NO];
        return;
    }

    UIAlertController* menu =
        [UIAlertController alertControllerWithTitle:@"PaperPad"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Settings"
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction* action) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            PaperPadSettingsViewController* settings = [PaperPadSettingsViewController new];
            settings.modalPresentationStyle = UIModalPresentationFormSheet;
            UIViewController* presenter = self.window.rootViewController;
            while (presenter.presentedViewController != nil) {
                presenter = presenter.presentedViewController;
            }
            if (presenter != nil) {
                [presenter presentViewController:settings animated:YES completion:nil];
            } else {
                [self setModalControlsHidden:NO];
            }
        });
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Share Diagnostics & Logs…"
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction* action) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            UIViewController* presenter = self.window.rootViewController;
            while (presenter.presentedViewController != nil) {
                presenter = presenter.presentedViewController;
            }
            if (presenter != nil) {
                paperpad_present_diagnostics_share((__bridge void*)presenter, ^{
                    [self setModalControlsHidden:NO];
                });
            } else {
                [self setModalControlsHidden:NO];
            }
        });
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:^(__unused UIAlertAction* action) {
        [self setModalControlsHidden:NO];
    }]];
    UIPopoverPresentationController* popover = menu.popoverPresentationController;
    if (popover != nil) {
        popover.sourceView = self;
        popover.sourceRect = [self utilityButtonRect];
        popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
    }
    [presenter presentViewController:menu animated:YES completion:nil];
}

- (void)beginEditingLayout {
    _modalControlsHidden = NO;
    _editing = YES;
    _utilityButton.hidden = YES;
    [self clearInput];
    [self setNeedsDisplay];
}

- (void)resetLayout {
    _undoControls = _controls;
    _undoDPadLinked = _dPadLinked;
    _undoCButtonsLinked = _cButtonsLinked;
    _controls = defaultControls();
    _dPadLinked = NO;
    _cButtonsLinked = NO;
    _hasUndo = YES;
    _editing = NO;
    _utilityButton.hidden = NO;
    [self saveLayout];
    [self setNeedsDisplay];
}

- (void)setModalControlsHidden:(BOOL)hidden {
    _modalControlsHidden = hidden;
    _utilityButton.hidden = hidden || _editing;
    if (hidden) [self clearInput];
    [self setNeedsDisplay];
}

- (BOOL)handleToolbarPoint:(CGPoint)point {
    if (!_editing) {
        if (CGRectContainsPoint([self utilityButtonRect], point)) {
            [self presentUtilityMenu];
            return YES;
        }
        return NO;
    }
    for (NSInteger index = 0; index < 7; ++index) {
        if (!CGRectContainsPoint([self toolbarRectAtIndex:index], point)) continue;
        TouchControl& selected = _controls[MAX(0, _selected)];
        switch (index) {
            case 0:
                _editing = NO;
                _utilityButton.hidden = NO;
                _hasUndo = NO;
                [self saveLayout];
                break;
            case 1:
                if (_hasUndo) {
                    std::swap(_controls, _undoControls);
                    std::swap(_dPadLinked, _undoDPadLinked);
                    std::swap(_cButtonsLinked, _undoCButtonsLinked);
                    _hasUndo = NO;
                } else {
                    _undoControls = _controls;
                    _undoDPadLinked = _dPadLinked;
                    _undoCButtonsLinked = _cButtonsLinked;
                    _controls = defaultControls();
                    _dPadLinked = NO;
                    _cButtonsLinked = NO;
                    _hasUndo = YES;
                }
                [self saveLayout];
                break;
            case 2:
                if (std::strncmp(selected.key, "d_", 2) == 0) {
                    _dPadLinked = !_dPadLinked;
                    [self saveLayout];
                } else if (std::strncmp(selected.key, "c_", 2) == 0) {
                    _cButtonsLinked = !_cButtonsLinked;
                    [self saveLayout];
                }
                break;
            case 3:
            {
                CGFloat baseSize = [self defaultSizeForControl:selected];
                selected.size = MAX(baseSize * 0.70, selected.size - baseSize * 0.10);
                _hasUndo = NO;
                [self saveLayout];
                break;
            }
            case 4:
            {
                CGFloat baseSize = [self defaultSizeForControl:selected];
                selected.size = MIN(baseSize * 1.50, selected.size + baseSize * 0.10);
                _hasUndo = NO;
                [self saveLayout];
                break;
            }
            case 5:
                selected.opacity += 0.14;
                if (selected.opacity > 0.78) selected.opacity = 0.24;
                _hasUndo = NO;
                [self saveLayout];
                break;
            case 6:
                if (selected.kind != ControlKind::Stick) {
                    selected.visible = !selected.visible;
                }
                _hasUndo = NO;
                [self saveLayout];
                break;
        }
        [self setNeedsDisplay];
        return YES;
    }
    return NO;
}

- (void)setGameplayControlsEnabled:(BOOL)enabled opacity:(CGFloat)opacity {
    _gameplayControlsEnabled = enabled;
    _globalOpacity = MAX(0.20, MIN(1.0, opacity));
    _utilityButton.alpha = MAX(0.55, _globalOpacity);
    if (!enabled) [self clearInput];
    [self setNeedsDisplay];
}

- (void)setPhysicalControllerConnected:(BOOL)connected {
    _physicalControllerConnected = connected;
    if (connected) [self clearInput];
    [self setNeedsDisplay];
}

- (void)moveSelectedToPoint:(CGPoint)point {
    if (_selected == NSNotFound) return;
    CGRect usable = [self usableBounds];
    TouchControl& control = _controls[_selected];
    const CGFloat desiredX = (point.x - CGRectGetMinX(usable)) / usable.size.width;
    const CGFloat desiredY = (point.y - CGRectGetMinY(usable)) / usable.size.height;
    if ([self isDirectionalControl:control] && [self isSelectedDirectionalGroupLinked]) {
        const char* group = std::strncmp(control.key, "d_", 2) == 0 ? "d_" : "c_";
        CGFloat minimumDeltaX = -CGFLOAT_MAX;
        CGFloat maximumDeltaX = CGFLOAT_MAX;
        CGFloat minimumDeltaY = -CGFLOAT_MAX;
        CGFloat maximumDeltaY = CGFLOAT_MAX;
        for (const TouchControl& candidate : _controls) {
            if (std::strncmp(candidate.key, group, 2) != 0) continue;
            const CGFloat radius = [self radiusForControl:candidate];
            const CGFloat horizontalMargin = radius / usable.size.width;
            const CGFloat verticalMargin = radius / usable.size.height;
            minimumDeltaX = MAX(minimumDeltaX, horizontalMargin - candidate.x);
            maximumDeltaX = MIN(maximumDeltaX, 1.0 - horizontalMargin - candidate.x);
            minimumDeltaY = MAX(minimumDeltaY, verticalMargin - candidate.y);
            maximumDeltaY = MIN(maximumDeltaY, 1.0 - verticalMargin - candidate.y);
        }
        const CGFloat deltaX = MAX(minimumDeltaX,
            MIN(maximumDeltaX, desiredX - control.x));
        const CGFloat deltaY = MAX(minimumDeltaY,
            MIN(maximumDeltaY, desiredY - control.y));
        for (TouchControl& candidate : _controls) {
            if (std::strncmp(candidate.key, group, 2) == 0) {
                candidate.x += deltaX;
                candidate.y += deltaY;
            }
        }
    } else {
        control.x = MAX(0.0, MIN(1.0, desiredX));
        control.y = MAX(0.0, MIN(1.0, desiredY));
    }
    _hasUndo = NO;
    [self setNeedsDisplay];
}

- (void)publishInput {
    uint16_t buttons = 0;
    CGFloat x = 0.0;
    CGFloat y = 0.0;
    for (const auto& item : _touchRoles) {
        UITouch* touch = item.first;
        NSInteger role = item.second;
        if (role < 0 || role >= (NSInteger)kControlCount) continue;
        const TouchControl& control = _controls[role];
        CGPoint point = [touch locationInView:self];
        if (control.kind == ControlKind::Stick) {
            CGFloat radius = [self radiusForControl:control];
            CGFloat dx = point.x - _stickOrigin.x;
            CGFloat dy = point.y - _stickOrigin.y;
            CGFloat length = hypot(dx, dy);
            if (length > radius && length > 0.0) {
                dx *= radius / length;
                dy *= radius / length;
            }
            x = dx / radius;
            y = -dy / radius;
            constexpr CGFloat deadzone = 0.16;
            const CGFloat normalizedLength = hypot(x, y);
            if (normalizedLength <= deadzone) {
                x = 0.0;
                y = 0.0;
            } else {
                const CGFloat remappedLength = (normalizedLength - deadzone) / (1.0 - deadzone);
                // Give the center of the stick a wider precision range without
                // taking away full-speed movement at the edge. This makes
                // name-entry and other grid selectors less eager to repeat.
                const CGFloat responseLength = remappedLength * remappedLength
                    * (0.75 + 0.25 * remappedLength);
                const CGFloat scale = responseLength / normalizedLength;
                x *= scale;
                y *= scale;

                // Bias clearly dominant gestures to a cardinal direction.
                // Deliberate diagonals remain available when the two axes are
                // close, while small thumb drift no longer changes rows/columns.
                constexpr CGFloat cardinalBias = 1.45;
                if (std::abs(x) > std::abs(y) * cardinalBias) {
                    y = 0.0;
                } else if (std::abs(y) > std::abs(x) * cardinalBias) {
                    x = 0.0;
                }
                g_touch_flick_x.store((int32_t)std::lround(x * 10000.0), std::memory_order_relaxed);
                g_touch_flick_y.store((int32_t)std::lround(y * 10000.0), std::memory_order_relaxed);
                g_touch_flick_polls.store(kAnalogFlickHoldPolls, std::memory_order_relaxed);
            }
            _stickKnob = CGPointMake(_stickOrigin.x + dx, _stickOrigin.y + dy);
        } else {
            buttons |= control.mask;
        }
    }
    g_touch_buttons.store(buttons, std::memory_order_relaxed);
    g_touch_x.store((int32_t)std::lround(x * 10000.0), std::memory_order_relaxed);
    g_touch_y.store((int32_t)std::lround(y * 10000.0), std::memory_order_relaxed);
    [self setNeedsDisplay];
}

- (void)clearInput {
    _touchRoles.clear();
    _touchOffsets.clear();
    _stickOrigin = CGPointZero;
    _stickKnob = CGPointZero;
    g_touch_buttons.store(0, std::memory_order_relaxed);
    g_touch_taps.clearAll();
    g_touch_x.store(0, std::memory_order_relaxed);
    g_touch_y.store(0, std::memory_order_relaxed);
    g_touch_flick_x.store(0, std::memory_order_relaxed);
    g_touch_flick_y.store(0, std::memory_order_relaxed);
    g_touch_flick_polls.store(0, std::memory_order_relaxed);
    [self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    for (UITouch* touch in touches) {
        CGPoint point = [touch locationInView:self];
        if ([self handleToolbarPoint:point]) continue;
        NSInteger control = [self controlAtPoint:point includeHidden:_editing];
        if (!_editing && _gameplayControlsEnabled && !_physicalControllerConnected &&
            !_modalControlsHidden &&
            control == NSNotFound &&
            point.x <= CGRectGetMinX([self usableBounds]) + [self usableBounds].size.width * 0.47) {
            control = 0;
        }
        if (control == NSNotFound) continue;
        _selected = control;
        _touchRoles[touch] = (int)control;
        if (_editing) {
            CGPoint center = [self centerForControl:_controls[control]];
            _touchOffsets[touch] = CGPointMake(center.x - point.x, center.y - point.y);
            [self setNeedsDisplay];
        } else if (_controls[control].kind == ControlKind::Stick) {
            // The broad left-side pickup region targets the same fixed visible
            // stick. Keeping one origin guarantees that both the rendered knob
            // and the N64 value use the identical clamped vector.
            _stickOrigin = [self centerForControl:_controls[control]];
            _stickKnob = _stickOrigin;
        } else {
            // Preserve quick taps across several runtime polls without turning
            // a single shoulder tap into a long press.
            g_touch_taps.extend(_controls[control].mask, kTapHoldPolls);
        }
    }
    if (!_editing) [self publishInput];
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    if (_editing) {
        for (UITouch* touch in touches) {
            auto found = _touchRoles.find(touch);
            if (found != _touchRoles.end()) {
                _selected = found->second;
                CGPoint point = [touch locationInView:self];
                auto offset = _touchOffsets.find(touch);
                if (offset != _touchOffsets.end()) {
                    point.x += offset->second.x;
                    point.y += offset->second.y;
                }
                [self moveSelectedToPoint:point];
            }
        }
    } else {
        for (UITouch* touch in touches) {
            auto found = _touchRoles.find(touch);
            if (found == _touchRoles.end()) continue;
            NSInteger role = found->second;
            if (role <= 0 || role >= (NSInteger)kControlCount) continue;
            CGPoint point = [touch locationInView:self];
            if (!CGRectContainsPoint(CGRectInset([self frameForControl:_controls[role]], -8.0, -8.0), point)) {
                _touchRoles.erase(found);
            }
        }
        [self publishInput];
    }
}

- (void)finishTouches:(NSSet<UITouch*>*)touches {
    for (UITouch* touch in touches) {
        auto found = _touchRoles.find(touch);
        if (found != _touchRoles.end()) {
            _touchRoles.erase(found);
        }
        _touchOffsets.erase(touch);
    }
    if (_editing) {
        [self saveLayout];
    } else {
        [self publishInput];
    }
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self finishTouches:touches];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self finishTouches:touches];
}

@end

extern "C" void paperpad_touch_attach(void* window_pointer) {
    if (window_pointer == nullptr) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow* window = (UIWindow*)window_pointer;
        UIView* host = window.rootViewController.view ?: window;
        for (UIView* view in host.subviews) {
            if ([view isKindOfClass:PaperPadTouchOverlayView.class]) return;
        }
        PaperPadTouchOverlayView* overlay =
            [[PaperPadTouchOverlayView alloc] initWithFrame:host.bounds];
        NSDictionary* settings =
            [NSUserDefaults.standardUserDefaults dictionaryForKey:settingsDefaultsKey()];
        BOOL controlsEnabled = settings[@"touchControls"] == nil ||
            [settings[@"touchControls"] boolValue];
        CGFloat controlsOpacity = settings[@"touchOpacity"] == nil
            ? 0.70 : [settings[@"touchOpacity"] doubleValue];
        [overlay setGameplayControlsEnabled:controlsEnabled opacity:controlsOpacity];
        [overlay setPhysicalControllerConnected:
            g_physical_controller_connected.load(std::memory_order_relaxed)];
        g_touch_overlay = overlay;
        overlay.translatesAutoresizingMaskIntoConstraints = NO;
        [host addSubview:overlay];
        [NSLayoutConstraint activateConstraints:@[
            [overlay.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
            [overlay.trailingAnchor constraintEqualToAnchor:host.trailingAnchor],
            [overlay.topAnchor constraintEqualToAnchor:host.topAnchor],
            [overlay.bottomAnchor constraintEqualToAnchor:host.bottomAnchor],
        ]];
    });
}

extern "C" void PaperPad_SetPhysicalControllerConnected(int connected) {
#if TARGET_OS_SIMULATOR
    // CoreSimulator exposes its synthetic MFi "Gamepad" even when no external
    // controller is paired. Keep touch controls available in Simulator tests.
    connected = 0;
#endif
    const bool isConnected = connected != 0;
    g_physical_controller_connected.store(isConnected, std::memory_order_relaxed);
    dispatch_async(dispatch_get_main_queue(), ^{
        [g_touch_overlay setPhysicalControllerConnected:isConnected];
    });
}

extern "C" void paperpad_touch_snapshot(uint16_t* buttons, float* x, float* y) {
    if (buttons != nullptr) {
        *buttons = g_touch_buttons.load(std::memory_order_relaxed) |
                   g_touch_taps.consume();
    }
    float touchX = g_touch_x.load(std::memory_order_relaxed) / 10000.0F;
    float touchY = g_touch_y.load(std::memory_order_relaxed) / 10000.0F;
    uint8_t flickPolls = g_touch_flick_polls.load(std::memory_order_relaxed);
    if (touchX == 0.0F && touchY == 0.0F && flickPolls > 0) {
        touchX = g_touch_flick_x.load(std::memory_order_relaxed) / 10000.0F;
        touchY = g_touch_flick_y.load(std::memory_order_relaxed) / 10000.0F;
        g_touch_flick_polls.compare_exchange_strong(
            flickPolls, static_cast<uint8_t>(flickPolls - 1), std::memory_order_relaxed);
    }
    if (x != nullptr) *x = touchX;
    if (y != nullptr) *y = touchY;
}

// ---------------------------------------------------------------------------
// Settings sheet. Native, compact, persisted to NSUserDefaults and applied
// through the PaperPad C bridge (volume + graphics config) or the touch
// overlay (layout editing/reset).
// ---------------------------------------------------------------------------

@implementation PaperPadSettingsViewController {
    UISlider* _volumeSlider;
    UILabel* _volumeLabel;
    UISegmentedControl* _resolutionControl;
    UILabel* _resolutionStatusLabel;
    NSTimer* _resolutionTimer;
    UISegmentedControl* _aspectControl;
    UISwitch* _touchControlsSwitch;
    UISlider* _touchOpacitySlider;
    UILabel* _touchOpacityLabel;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.96];
    self.preferredContentSize = CGSizeMake(560, 520);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    UIScrollView* scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:scroll];

    UIView* content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    UIStackView* stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 14.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:stack];

    UILabel* title = [self label:@"PaperPad Settings"];
    title.text = @"PaperPad Settings";
    title.font = [UIFont boldSystemFontOfSize:24.0];
    title.accessibilityTraits |= UIAccessibilityTraitHeader;
    [stack addArrangedSubview:title];

    // Master volume.
    UIStackView* volumeRow = [[UIStackView alloc] init];
    volumeRow.axis = UILayoutConstraintAxisHorizontal;
    [volumeRow addArrangedSubview:[self label:@"Master Volume"]];
    _volumeLabel = [self label:@"100%"];
    _volumeLabel.textAlignment = NSTextAlignmentRight;
    [volumeRow addArrangedSubview:_volumeLabel];
    [stack addArrangedSubview:volumeRow];
    _volumeSlider = [[UISlider alloc] init];
    _volumeSlider.minimumValue = 0.0;
    _volumeSlider.maximumValue = 100.0;
    _volumeSlider.continuous = YES;
    _volumeSlider.accessibilityLabel = @"Master Volume";
    [_volumeSlider addTarget:self action:@selector(volumeChanged:) forControlEvents:UIControlEventValueChanged];
    [_volumeSlider.heightAnchor constraintGreaterThanOrEqualToConstant:44.0].active = YES;
    [stack addArrangedSubview:_volumeSlider];

    // Resolution.
    [stack addArrangedSubview:[self label:@"Resolution"]];
    _resolutionControl = [[UISegmentedControl alloc]
        initWithItems:@[@"Auto", @"1x", @"2x", @"3x", @"4x"]];
    _resolutionControl.accessibilityLabel = @"Rendering Resolution";
    [_resolutionControl addTarget:self action:@selector(graphicsChanged:) forControlEvents:UIControlEventValueChanged];
    [_resolutionControl.heightAnchor constraintGreaterThanOrEqualToConstant:40.0].active = YES;
    [stack addArrangedSubview:_resolutionControl];
    _resolutionStatusLabel = [self label:@"Auto chooses the largest whole-number scale that fits this screen."];
    _resolutionStatusLabel.font = [UIFont systemFontOfSize:14.0];
    _resolutionStatusLabel.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
    _resolutionStatusLabel.numberOfLines = 3;
    [stack addArrangedSubview:_resolutionStatusLabel];

    // Aspect ratio.
    [stack addArrangedSubview:[self label:@"Aspect Ratio"]];
    _aspectControl = [[UISegmentedControl alloc] initWithItems:@[@"Original (4:3)", @"Fill Screen"]];
    _aspectControl.accessibilityLabel = @"Aspect Ratio";
    [_aspectControl addTarget:self action:@selector(graphicsChanged:) forControlEvents:UIControlEventValueChanged];
    [_aspectControl.heightAnchor constraintGreaterThanOrEqualToConstant:40.0].active = YES;
    [stack addArrangedSubview:_aspectControl];

    // Touch controls.
    UIStackView* touchControlsRow = [[UIStackView alloc] init];
    touchControlsRow.axis = UILayoutConstraintAxisHorizontal;
    touchControlsRow.alignment = UIStackViewAlignmentCenter;
    UILabel* touchControlsLabel = [self label:@"Touch Controls"];
    [touchControlsRow addArrangedSubview:touchControlsLabel];
    _touchControlsSwitch = [[UISwitch alloc] init];
    _touchControlsSwitch.accessibilityLabel = @"Touch Controls";
    [_touchControlsSwitch addTarget:self action:@selector(touchControlsChanged:)
                   forControlEvents:UIControlEventValueChanged];
    [touchControlsRow addArrangedSubview:_touchControlsSwitch];
    [stack addArrangedSubview:touchControlsRow];

    UIStackView* touchOpacityRow = [[UIStackView alloc] init];
    touchOpacityRow.axis = UILayoutConstraintAxisHorizontal;
    [touchOpacityRow addArrangedSubview:[self label:@"Touch Opacity"]];
    _touchOpacityLabel = [self label:@"70%"];
    _touchOpacityLabel.textAlignment = NSTextAlignmentRight;
    [touchOpacityRow addArrangedSubview:_touchOpacityLabel];
    [stack addArrangedSubview:touchOpacityRow];
    _touchOpacitySlider = [[UISlider alloc] init];
    _touchOpacitySlider.minimumValue = 20.0;
    _touchOpacitySlider.maximumValue = 100.0;
    _touchOpacitySlider.continuous = YES;
    _touchOpacitySlider.accessibilityLabel = @"Touch Opacity";
    [_touchOpacitySlider addTarget:self action:@selector(touchOpacityChanged:)
                  forControlEvents:UIControlEventValueChanged];
    [_touchOpacitySlider.heightAnchor constraintGreaterThanOrEqualToConstant:44.0].active = YES;
    [stack addArrangedSubview:_touchOpacitySlider];

    // Actions.
    [stack addArrangedSubview:[self actionButton:@"Edit Touch Layout"
                                      systemImage:@"hand.draw"
                                             action:@selector(editLayoutPressed)]];
    [stack addArrangedSubview:[self actionButton:@"Reset Touch Layout"
                                      systemImage:@"arrow.counterclockwise"
                                             action:@selector(resetLayoutPressed)]];
    [stack addArrangedSubview:[self actionButton:@"Share Diagnostics…"
                                      systemImage:@"square.and.arrow.up"
                                             action:@selector(diagnosticsPressed)]];
    [stack addArrangedSubview:[self actionButton:@"Manage Game ROM"
                                      systemImage:@"externaldrive"
                                             action:@selector(romPressed)]];

    UIButton* done = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration* doneConfiguration = [UIButtonConfiguration filledButtonConfiguration];
    doneConfiguration.title = @"Done";
    doneConfiguration.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    doneConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(13.0, 18.0, 13.0, 18.0);
    done.configuration = doneConfiguration;
    done.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
    done.accessibilityLabel = @"Done";
    [done addTarget:self action:@selector(donePressed) forControlEvents:UIControlEventTouchUpInside];
    [done.heightAnchor constraintGreaterThanOrEqualToConstant:50.0].active = YES;
    [stack addArrangedSubview:done];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:24.0],
        [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24.0],
        [stack.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:content.leadingAnchor constant:28.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor constant:-28.0],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:560.0],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshFromDefaults];
    [self refreshResolutionStatus];
    [_resolutionTimer invalidate];
    _resolutionTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                       target:self
                                                     selector:@selector(refreshResolutionStatus)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_resolutionTimer invalidate];
    _resolutionTimer = nil;
    [g_touch_overlay setModalControlsHidden:NO];
}

- (void)refreshResolutionStatus {
    uint32_t scaleMilli = 0;
    uint32_t width = 0;
    uint32_t height = 0;
    const BOOL available = PaperPad_GetEffectiveRenderState(&scaleMilli, &width, &height) != 0;
    const BOOL automatic = _resolutionControl.selectedSegmentIndex == 0;
    if (available) {
        _resolutionStatusLabel.text = [NSString stringWithFormat:
            automatic ? @"Auto is currently %.2fx (%ux%u internal). Auto may exceed 4x to fit the screen; original textures keep their source detail."
                      : @"Renderer confirms %.2fx (%ux%u internal).",
            scaleMilli / 1000.0, width, height];
    } else {
        _resolutionStatusLabel.text = automatic
            ? @"Auto chooses the largest whole-number scale that fits this screen and may exceed 4x. Waiting for the renderer…"
            : @"Waiting for renderer confirmation…";
    }
    _resolutionStatusLabel.accessibilityLabel = _resolutionStatusLabel.text;
}

- (UILabel*)label:(NSString*)text {
    UILabel* label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:17.0];
    label.textColor = UIColor.whiteColor;
    return label;
}

- (UIButton*)actionButton:(NSString*)title systemImage:(NSString*)systemImage action:(SEL)action {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration* configuration = [UIButtonConfiguration tintedButtonConfiguration];
    configuration.title = title;
    configuration.image = [UIImage systemImageNamed:systemImage];
    configuration.imagePadding = 12.0;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    configuration.baseForegroundColor = UIColor.systemBlueColor;
    configuration.baseBackgroundColor = [UIColor colorWithWhite:0.24 alpha:1.0];
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(13.0, 16.0, 13.0, 16.0);
    button.configuration = configuration;
    button.titleLabel.font = [UIFont systemFontOfSize:17.0];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.accessibilityLabel = title;
    button.accessibilityTraits |= UIAccessibilityTraitButton;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:50.0].active = YES;
    return button;
}

- (void)refreshFromDefaults {
    NSDictionary* saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:settingsDefaultsKey()];
    float volume = saved[@"volume"] ? [saved[@"volume"] floatValue] : 1.0f;
    NSInteger resolution = resolutionModeFromSettings(saved);
    int aspect = saved[@"aspect"] ? [saved[@"aspect"] intValue] : 0;
    BOOL touchControls = saved[@"touchControls"] == nil || [saved[@"touchControls"] boolValue];
    float touchOpacity = saved[@"touchOpacity"] ? [saved[@"touchOpacity"] floatValue] : 0.70f;
    _volumeSlider.value = volume * 100.0;
    _volumeLabel.text = [NSString stringWithFormat:@"%d%%", (int)lround(volume * 100.0)];
    _resolutionControl.selectedSegmentIndex = resolution;
    _aspectControl.selectedSegmentIndex = aspect;
    _touchControlsSwitch.on = touchControls;
    _touchOpacitySlider.value = touchOpacity * 100.0f;
    _touchOpacityLabel.text = [NSString stringWithFormat:@"%d%%", (int)lround(touchOpacity * 100.0f)];
    _touchOpacitySlider.accessibilityValue = _touchOpacityLabel.text;
}

- (void)persist {
    NSDictionary* saved = @{
        @"schemaVersion": @4,
        @"volume": @(_volumeSlider.value / 100.0),
        @"resolution": @(_resolutionControl.selectedSegmentIndex),
        @"aspect": @(_aspectControl.selectedSegmentIndex),
        @"touchControls": @(_touchControlsSwitch.isOn),
        @"touchOpacity": @(_touchOpacitySlider.value / 100.0),
    };
    [NSUserDefaults.standardUserDefaults setObject:saved forKey:settingsDefaultsKey()];
}

- (void)volumeChanged:(UISlider*)slider {
    float volume = slider.value / 100.0;
    _volumeLabel.text = [NSString stringWithFormat:@"%d%%", (int)lround(volume * 100.0)];
    PaperPad_SetAudioVolume(volume);
    [self persist];
}

- (void)graphicsChanged:(UISegmentedControl*)control {
    PaperPad_SetGraphicsConfig((int)_resolutionControl.selectedSegmentIndex,
                               (int)_aspectControl.selectedSegmentIndex,
                               0);
    [self persist];
    [self refreshResolutionStatus];
}

- (void)touchControlsChanged:(UISwitch*)control {
    [g_touch_overlay setGameplayControlsEnabled:control.isOn
                                         opacity:_touchOpacitySlider.value / 100.0];
    [self persist];
}

- (void)touchOpacityChanged:(UISlider*)slider {
    CGFloat opacity = slider.value / 100.0;
    _touchOpacityLabel.text = [NSString stringWithFormat:@"%d%%", (int)lround(slider.value)];
    slider.accessibilityValue = _touchOpacityLabel.text;
    [g_touch_overlay setGameplayControlsEnabled:_touchControlsSwitch.isOn opacity:opacity];
    [self persist];
}

- (void)editLayoutPressed {
    [self dismissViewControllerAnimated:YES completion:^{
        [g_touch_overlay beginEditingLayout];
    }];
}

- (void)resetLayoutPressed {
    [self dismissViewControllerAnimated:YES completion:^{
        [g_touch_overlay resetLayout];
    }];
}

- (void)diagnosticsPressed {
    UIViewController* presenter = self.presentingViewController;
    [self dismissViewControllerAnimated:YES completion:^{
        if (presenter != nil) {
            [g_touch_overlay setModalControlsHidden:YES];
            paperpad_present_diagnostics_share((__bridge void*)presenter, ^{
                [g_touch_overlay setModalControlsHidden:NO];
            });
        }
    }];
}

- (void)romPressed {
    UIViewController* presenter = self.presentingViewController;
    [self dismissViewControllerAnimated:YES completion:^{
        if (presenter != nil) {
            paperpad_present_rom_manager((__bridge void*)presenter);
        }
    }];
}

- (void)donePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

extern "C" int SDL_main(int argc, char** argv) {
    @autoreleasepool {
        SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");
        SDL_SetHint(SDL_HINT_ACCELEROMETER_AS_JOYSTICK, "0");
#if !defined(PAPERPAD_RELEASE_BUILD)
        setenv("PSR_AUTOBOOT", "1", 1);
#endif

        // Apply persisted settings before the game starts.
        NSDictionary* settings = [NSUserDefaults.standardUserDefaults dictionaryForKey:settingsDefaultsKey()];
        if (settings != nil) {
            float volume = settings[@"volume"] ? [settings[@"volume"] floatValue] : 1.0f;
            NSInteger resolution = resolutionModeFromSettings(settings);
            int aspect = settings[@"aspect"] ? [settings[@"aspect"] intValue] : 0;
            PaperPad_SetAudioVolume(volume);
            PaperPad_SetGraphicsConfig(static_cast<int>(resolution), aspect, 0);
        }

        NSFileManager* files = [NSFileManager defaultManager];
        NSURL* support = [[files URLsForDirectory:NSApplicationSupportDirectory
                                        inDomains:NSUserDomainMask] firstObject];
        NSURL* root = [support URLByAppendingPathComponent:@"PaperPad" isDirectory:YES];
        NSError* error = nil;
        if (![files createDirectoryAtURL:root
             withIntermediateDirectories:YES
                              attributes:nil
                                   error:&error]) {
            std::fprintf(stderr, "PaperPad could not create Application Support: %s\n",
                         error.localizedDescription.UTF8String);
            return EXIT_FAILURE;
        }
        paperpad_start_diagnostics_log((__bridge void*)root);
        if (!paperpad_prepare_rom_setup()) {
            paperpad_finish_diagnostics_log((__bridge void*)root);
            return EXIT_FAILURE;
        }
        if (chdir(root.fileSystemRepresentation) != 0) {
            std::perror("PaperPad could not enter Application Support");
            paperpad_finish_diagnostics_log((__bridge void*)root);
            return EXIT_FAILURE;
        }

        const int result = paperpad_recomp_main(argc, argv);
        paperpad_finish_diagnostics_log((__bridge void*)root);
        return result;
    }
}
