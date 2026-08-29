#import "WolFox.h"
#import "UI.h"

#import <UIKit/UIKit.h>

#pragma mark - Overlay Root

@interface WFOverlayRootController : UIViewController
@end

@implementation WFOverlayRootController

- (void)loadView {

    UIView *view =
        [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];

    view.backgroundColor =
        UIColor.clearColor;

    self.view = view;
}

@end


#pragma mark - UI Controller

@implementation WFUIController {
    UIWindow *_overlayWindow;
    UIButton *_floatingButton;

    UIView *_panel;
    UILabel *_statusLabel;

    UITextField *_latitudeField;
    UITextField *_longitudeField;
}

+ (instancetype)sharedController {

    static WFUIController *instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance =
            [[WFUIController alloc] init];
    });

    return instance;
}

#pragma mark - Auto Start

+ (void)load {

    NSLog(@"[WolFox] WFUIController +load");

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(1.5 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

        [[WFUIController sharedController]
            installWhenReady];
    });
}

#pragma mark - Install

- (void)installWhenReady {

    NSLog(@"[WolFox] installWhenReady");

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

        [self installOverlay];
    });
}

#pragma mark - Active Scene

- (UIWindowScene *)activeWindowScene
    API_AVAILABLE(ios(13.0)) {

    UIApplication *application =
        UIApplication.sharedApplication;

    for (UIScene *scene in
         application.connectedScenes) {

        if (![scene
                isKindOfClass:
                    UIWindowScene.class]) {

            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState ==
                UISceneActivationStateForegroundActive ||
            windowScene.activationState ==
                UISceneActivationStateForegroundInactive) {

            return windowScene;
        }
    }

    for (UIScene *scene in
         application.connectedScenes) {

        if ([scene
                isKindOfClass:
                    UIWindowScene.class]) {

            return
                (UIWindowScene *)scene;
        }
    }

    return nil;
}

#pragma mark - Overlay

- (void)installOverlay {

    if (_overlayWindow != nil) {

        _overlayWindow.hidden =
            NO;

        return;
    }

    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {

        UIWindowScene *scene =
            [self activeWindowScene];

        if (scene == nil) {

            [self retryInstall];

            return;
        }

        window =
            [[UIWindow alloc]
                initWithWindowScene:scene];

    } else {

        window =
            [[UIWindow alloc]
                initWithFrame:
                    UIScreen.mainScreen.bounds];
    }

    window.frame =
        UIScreen.mainScreen.bounds;

    window.backgroundColor =
        UIColor.clearColor;

    window.windowLevel =
        UIWindowLevelAlert + 1000.0;

    WFOverlayRootController *root =
        [[WFOverlayRootController alloc]
            init];

    window.rootViewController =
        root;

    window.hidden =
        NO;

    _overlayWindow =
        window;

    [self buildFloatingButtonOnView:
        root.view];

    NSLog(@"[WolFox] Overlay installed");
}

- (void)retryInstall {

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(1.0 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

        if (self->_overlayWindow == nil) {

            [self installOverlay];
        }
    });
}

#pragma mark - Floating Button

- (void)buildFloatingButtonOnView:
    (UIView *)view {

    if (_floatingButton != nil) {
        return;
    }

    UIButton *button =
        [UIButton buttonWithType:
            UIButtonTypeCustom];

    button.frame =
        CGRectMake(
            20.0,
            170.0,
            68.0,
            68.0
        );

    button.backgroundColor =
        [UIColor
            colorWithRed:0.08
                   green:0.08
                    blue:0.10
                   alpha:0.96];

    button.layer.cornerRadius =
        34.0;

    button.layer.borderWidth =
        2.0;

    button.layer.borderColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.22].CGColor;

    button.layer.shadowOpacity =
        0.35;

    button.layer.shadowRadius =
        8.0;

    button.layer.shadowOffset =
        CGSizeMake(
            0.0,
            4.0
        );

    [button
        setTitle:@"🦊"
        forState:UIControlStateNormal];

    button.titleLabel.font =
        [UIFont
            systemFontOfSize:32.0];

    [button
        addTarget:self
           action:@selector(floatingButtonPressed)
 forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handleFloatingPan:)];

    [button
        addGestureRecognizer:pan];

    [view addSubview:button];

    [view bringSubviewToFront:button];

    _floatingButton =
        button;
}

#pragma mark - Drag Button

- (void)handleFloatingPan:
    (UIPanGestureRecognizer *)gesture {

    UIView *button =
        gesture.view;

    UIView *parent =
        button.superview;

    if (button == nil ||
        parent == nil) {

        return;
    }

    CGPoint translation =
        [gesture
            translationInView:parent];

    CGPoint center =
        button.center;

    center.x +=
        translation.x;

    center.y +=
        translation.y;

    CGFloat halfWidth =
        CGRectGetWidth(
            button.bounds
        ) / 2.0;

    CGFloat halfHeight =
        CGRectGetHeight(
            button.bounds
        ) / 2.0;

    CGFloat width =
        CGRectGetWidth(
            parent.bounds
        );

    CGFloat height =
        CGRectGetHeight(
            parent.bounds
        );

    center.x =
        MAX(
            halfWidth,
            MIN(
                width - halfWidth,
                center.x
            )
        );

    center.y =
        MAX(
            halfHeight,
            MIN(
                height - halfHeight,
                center.y
            )
        );

    button.center =
        center;

    [gesture
        setTranslation:
            CGPointZero
              inView:
            parent];
}

#pragma mark - Open Panel

- (void)floatingButtonPressed {

    if (_panel != nil) {

        [self closePanel];

        return;
    }

    [self buildPanel];
}

#pragma mark - Panel

- (void)buildPanel {

    UIView *rootView =
        _overlayWindow
            .rootViewController
            .view;

    if (rootView == nil) {
        return;
    }

    CGFloat screenWidth =
        CGRectGetWidth(
            rootView.bounds
        );

    CGFloat panelWidth =
        MIN(
            360.0,
            screenWidth - 28.0
        );

    CGFloat panelHeight =
        430.0;

    CGFloat x =
        (screenWidth -
         panelWidth) /
        2.0;

    CGFloat y =
        120.0;

    UIView *panel =
        [[UIView alloc]
            initWithFrame:
                CGRectMake(
                    x,
                    y,
                    panelWidth,
                    panelHeight
                )];

    panel.backgroundColor =
        [UIColor
            colorWithRed:0.07
                   green:0.07
                    blue:0.09
                   alpha:0.97];

    panel.layer.cornerRadius =
        24.0;

    panel.layer.borderWidth =
        1.0;

    panel.layer.borderColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.12].CGColor;

    panel.layer.shadowOpacity =
        0.35;

    panel.layer.shadowRadius =
        18.0;

    panel.layer.shadowOffset =
        CGSizeMake(
            0.0,
            8.0
        );

    [rootView addSubview:panel];

    [rootView bringSubviewToFront:panel];

    _panel =
        panel;

    [self buildPanelContents];
}

#pragma mark - Panel Contents

- (void)buildPanelContents {

    if (_panel == nil) {
        return;
    }

    CGFloat width =
        CGRectGetWidth(
            _panel.bounds
        );

    UILabel *title =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    24.0,
                    22.0,
                    width - 80.0,
                    32.0
                )];

    title.text =
        @"WolFox";

    title.textColor =
        UIColor.whiteColor;

    title.font =
        [UIFont
            boldSystemFontOfSize:
                24.0];

    [_panel addSubview:title];


    UIButton *closeButton =
        [UIButton
            buttonWithType:
                UIButtonTypeSystem];

    closeButton.frame =
        CGRectMake(
            width - 58.0,
            16.0,
            42.0,
            42.0
        );

    [closeButton
        setTitle:@"✕"
        forState:UIControlStateNormal];

    closeButton.titleLabel.font =
        [UIFont
            boldSystemFontOfSize:
                20.0];

    [closeButton
        setTitleColor:
            UIColor.whiteColor
        forState:
            UIControlStateNormal];

    [closeButton
        addTarget:self
           action:@selector(closePanel)
 forControlEvents:UIControlEventTouchUpInside];

    [_panel addSubview:closeButton];


    UILabel *subtitle =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    24.0,
                    58.0,
                    width - 48.0,
                    24.0
                )];

    subtitle.text =
        @"Standalone Runtime Controller";

    subtitle.textColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.55];

    subtitle.font =
        [UIFont
            systemFontOfSize:
                13.0];

    [_panel addSubview:subtitle];


    UILabel *latLabel =
        [self labelWithText:
            @"Latitude"
        frame:
            CGRectMake(
                24.0,
                103.0,
                width - 48.0,
                20.0
            )];

    [_panel addSubview:latLabel];


    _latitudeField =
        [self textFieldWithFrame:
            CGRectMake(
                24.0,
                129.0,
                width - 48.0,
                46.0
            )];

    _latitudeField.placeholder =
        @"24.7136";

    [_panel
        addSubview:
            _latitudeField];


    UILabel *lonLabel =
        [self labelWithText:
            @"Longitude"
        frame:
            CGRectMake(
                24.0,
                189.0,
                width - 48.0,
                20.0
            )];

    [_panel addSubview:lonLabel];


    _longitudeField =
        [self textFieldWithFrame:
            CGRectMake(
                24.0,
                215.0,
                width - 48.0,
                46.0
            )];

    _longitudeField.placeholder =
        @"46.6753";

    [_panel
        addSubview:
            _longitudeField];


    UIButton *setButton =
        [self actionButtonWithTitle:
            @"Set Static Location"
        frame:
            CGRectMake(
                24.0,
                282.0,
                width - 48.0,
                48.0
            )];

    [setButton
        addTarget:self
           action:@selector(setStaticLocationPressed)
 forControlEvents:UIControlEventTouchUpInside];

    [_panel addSubview:setButton];


    UIButton *restoreButton =
        [UIButton
            buttonWithType:
                UIButtonTypeSystem];

    restoreButton.frame =
        CGRectMake(
            24.0,
            342.0,
            width - 48.0,
            44.0
        );

    restoreButton.layer.cornerRadius =
        12.0;

    restoreButton.backgroundColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.07];

    [restoreButton
        setTitle:@"Restore Default"
        forState:UIControlStateNormal];

    [restoreButton
        setTitleColor:
            UIColor.whiteColor
        forState:
            UIControlStateNormal];

    restoreButton.titleLabel.font =
        [UIFont
            systemFontOfSize:
                15.0
                      weight:
                UIFontWeightSemibold];

    [restoreButton
        addTarget:self
           action:@selector(restoreDefaultPressed)
 forControlEvents:UIControlEventTouchUpInside];

    [_panel
        addSubview:
            restoreButton];


    _statusLabel =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    24.0,
                    396.0,
                    width - 48.0,
                    24.0
                )];

    _statusLabel.textColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.65];

    _statusLabel.font =
        [UIFont
            systemFontOfSize:
                12.0];

    _statusLabel.numberOfLines =
        1;

    [_panel
        addSubview:
            _statusLabel];

    [self refreshStatus];
}

#pragma mark - Components

- (UILabel *)labelWithText:
    (NSString *)text
                    frame:
    (CGRect)frame {

    UILabel *label =
        [[UILabel alloc]
            initWithFrame:frame];

    label.text =
        text;

    label.textColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.82];

    label.font =
        [UIFont
            systemFontOfSize:
                13.0
                      weight:
                UIFontWeightMedium];

    return label;
}

- (UITextField *)textFieldWithFrame:
    (CGRect)frame {

    UITextField *field =
        [[UITextField alloc]
            initWithFrame:frame];

    field.backgroundColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.08];

    field.textColor =
        UIColor.whiteColor;

    field.keyboardType =
        UIKeyboardTypeNumbersAndPunctuation;

    field.layer.cornerRadius =
        12.0;

    field.layer.borderWidth =
        1.0;

    field.layer.borderColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.10].CGColor;

    field.font =
        [UIFont
            systemFontOfSize:
                15.0];

    UIView *padding =
        [[UIView alloc]
            initWithFrame:
                CGRectMake(
                    0.0,
                    0.0,
                    12.0,
                    1.0
                )];

    field.leftView =
        padding;

    field.leftViewMode =
        UITextFieldViewModeAlways;

    return field;
}

- (UIButton *)actionButtonWithTitle:
    (NSString *)title
                           frame:
    (CGRect)frame {

    UIButton *button =
        [UIButton
            buttonWithType:
                UIButtonTypeSystem];

    button.frame =
        frame;

    button.backgroundColor =
        [UIColor
            colorWithRed:0.25
                   green:0.55
                    blue:1.0
                   alpha:1.0];

    button.layer.cornerRadius =
        14.0;

    [button
        setTitle:title
        forState:UIControlStateNormal];

    [button
        setTitleColor:
            UIColor.whiteColor
        forState:
            UIControlStateNormal];

    button.titleLabel.font =
        [UIFont
            systemFontOfSize:
                16.0
                      weight:
                UIFontWeightSemibold];

    return button;
}

#pragma mark - Actions

- (void)setStaticLocationPressed {

    double latitude =
        [_latitudeField.text
            doubleValue];

    double longitude =
        [_longitudeField.text
            doubleValue];

    WFError *error =
        [[WFAppManager sharedManager]
            activateStaticLocationWithLatitude:
                latitude
            longitude:
                longitude];

    if ([error isSuccess]) {

        [self showMessage:
            @"Static location activated ✅"];

    } else {

        [self showMessage:
            error.humanReadableMessage.length > 0
                ? error.humanReadableMessage
                : @"Unable to activate location"];
    }

    [self refreshStatus];
}

- (void)restoreDefaultPressed {

    WFError *error =
        [[WFAppManager sharedManager]
            restoreDefaultLocation];

    if ([error isSuccess]) {

        [self showMessage:
            @"Default location restored ✅"];

    } else {

        [self showMessage:
            error.humanReadableMessage.length > 0
                ? error.humanReadableMessage
                : @"Unable to restore location"];
    }

    [self refreshStatus];
}

#pragma mark - Status

- (void)refreshStatus {

    NSDictionary *snapshot =
        [[WFRuntimeState sharedState]
            snapshotForUI];

    BOOL enabled =
        [snapshot[@"locationEnabled"]
            boolValue];

    double latitude =
        [snapshot[@"currentLatitude"]
            doubleValue];

    double longitude =
        [snapshot[@"currentLongitude"]
            doubleValue];

    NSString *lastAction =
        snapshot[@"lastAction"];

    if (enabled) {

        _statusLabel.text =
            [NSString
                stringWithFormat:
                    @"Active: %.6f, %.6f",
                    latitude,
                    longitude];

    } else {

        _statusLabel.text =
            lastAction.length > 0
                ? lastAction
                : @"Default environment";
    }
}

#pragma mark - Alert

- (void)showMessage:
    (NSString *)message {

    UIViewController *controller =
        _overlayWindow
            .rootViewController;

    if (controller == nil) {
        return;
    }

    while (controller
               .presentedViewController != nil) {

        controller =
            controller
                .presentedViewController;
    }

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:
                @"WolFox"
                             message:
                message ?: @""
                      preferredStyle:
                UIAlertControllerStyleAlert];

    [alert
        addAction:
            [UIAlertAction
                actionWithTitle:@"OK"
                          style:
                    UIAlertActionStyleDefault
                        handler:nil]];

    [controller
        presentViewController:alert
                     animated:YES
                   completion:nil];
}

#pragma mark - Close

- (void)closePanel {

    [_latitudeField
        resignFirstResponder];

    [_longitudeField
        resignFirstResponder];

    [_panel
        removeFromSuperview];

    _panel =
        nil;

    _statusLabel =
        nil;

    _latitudeField =
        nil;

    _longitudeField =
        nil;
}

@end