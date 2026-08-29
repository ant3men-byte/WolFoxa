#import "WolFox.h"
#import "UI.h"
#import <UIKit/UIKit.h>


#import <UIKit/UIKit.h>

#pragma mark - WFUIController

@implementation WFUIController {
    UIView *_floatingButton;
    UIView *_panel;
    UITextField *_latField;
    UITextField *_lonField;
    UILabel *_statusLabel;
}

+ (instancetype)sharedController {

    static WFUIController *instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[WFUIController alloc] init];
    });

    return instance;
}

#pragma mark - Install

- (void)installWhenReady {

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(appWindowDidAppear)
               name:UIWindowDidBecomeVisibleNotification
             object:nil];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self appWindowDidAppear];
    });
}

- (void)appWindowDidAppear {

    dispatch_async(dispatch_get_main_queue(), ^{

        if (self->_floatingButton == nil) {
            [self buildFloatingButton];
        }
    });
}

- (UIWindow *)keyWindow {

    UIApplication *application =
        [UIApplication sharedApplication];

    for (UIScene *scene in application.connectedScenes) {

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState !=
            UISceneActivationStateForegroundActive) {

            continue;
        }

        for (UIWindow *window in windowScene.windows) {

            if (window.isKeyWindow) {
                return window;
            }
        }
    }

    for (UIScene *scene in application.connectedScenes) {

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        for (UIWindow *window in windowScene.windows) {

            if (!window.hidden &&
                window.alpha > 0.0) {

                return window;
            }
        }
    }

    return nil;
}

#pragma mark - Floating Button

- (void)buildFloatingButton {

    UIWindow *window =
        [self keyWindow];

    if (window == nil) {

        [[WFLogger sharedLogger]
            logCategory:WFLogUI
            message:@"No active window yet"];

        return;
    }

    UIButton *button =
        [UIButton buttonWithType:
            UIButtonTypeCustom];

    button.frame =
        CGRectMake(
            20.0,
            200.0,
            56.0,
            56.0
        );

    button.layer.cornerRadius =
        28.0;

    button.backgroundColor =
        [UIColor
            colorWithRed:0.85
                   green:0.20
                    blue:0.20
                   alpha:0.90];

    button.titleLabel.font =
        [UIFont
            boldSystemFontOfSize:22.0];

    [button
        setTitle:@"🦊"
        forState:UIControlStateNormal];

    button.layer.shadowOpacity =
        0.4;

    button.layer.shadowRadius =
        4.0;

    button.layer.shadowOffset =
        CGSizeMake(0.0, 2.0);

    [button
        addTarget:self
           action:@selector(togglePanel)
 forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(dragButton:)];

    [button
        addGestureRecognizer:pan];

    [window
        addSubview:button];

    [window
        bringSubviewToFront:button];

    _floatingButton =
        button;

    [[WFLogger sharedLogger]
        logCategory:WFLogUI
        message:@"Floating button installed"];
}

- (void)dragButton:
    (UIPanGestureRecognizer *)pan {

    UIView *button =
        pan.view;

    UIView *container =
        button.superview;

    if (button == nil ||
        container == nil) {

        return;
    }

    CGPoint translation =
        [pan
            translationInView:container];

    CGPoint center =
        button.center;

    center.x +=
        translation.x;

    center.y +=
        translation.y;

    CGFloat halfWidth =
        CGRectGetWidth(button.bounds) / 2.0;

    CGFloat halfHeight =
        CGRectGetHeight(button.bounds) / 2.0;

    center.x =
        MAX(
            halfWidth,
            MIN(
                CGRectGetWidth(container.bounds) -
                halfWidth,
                center.x
            )
        );

    center.y =
        MAX(
            halfHeight,
            MIN(
                CGRectGetHeight(container.bounds) -
                halfHeight,
                center.y
            )
        );

    button.center =
        center;

    [pan
        setTranslation:CGPointZero
                inView:container];
}

#pragma mark - Panel

- (void)togglePanel {

    if (_panel != nil) {

        [self closePanel];
        return;
    }

    [self buildPanel];
}

- (void)buildPanel {

    UIWindow *window =
        [self keyWindow];

    if (window == nil) {
        return;
    }

    CGFloat width =
        CGRectGetWidth(window.bounds);

    CGFloat panelWidth =
        MAX(280.0, width - 40.0);

    UIView *panel =
        [[UIView alloc]
            initWithFrame:
                CGRectMake(
                    20.0,
                    120.0,
                    panelWidth,
                    420.0
                )];

    panel.backgroundColor =
        [UIColor
            colorWithRed:0.10
                   green:0.10
                    blue:0.12
                   alpha:0.97];

    panel.layer.cornerRadius =
        16.0;

    panel.layer.borderColor =
        [UIColor
            colorWithRed:0.85
                   green:0.20
                    blue:0.20
                   alpha:1.0]
            .CGColor;

    panel.layer.borderWidth =
        1.5;

    UILabel *title =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    0.0,
                    16.0,
                    panel.bounds.size.width,
                    30.0
                )];

    title.text =
        @"WolFox Control";

    title.textColor =
        UIColor.whiteColor;

    title.textAlignment =
        NSTextAlignmentCenter;

    title.font =
        [UIFont
            boldSystemFontOfSize:18.0];

    [panel
        addSubview:title];

    _statusLabel =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    16.0,
                    52.0,
                    panel.bounds.size.width - 32.0,
                    44.0
                )];

    _statusLabel.textColor =
        [UIColor lightGrayColor];

    _statusLabel.font =
        [UIFont
            systemFontOfSize:12.0];

    _statusLabel.numberOfLines =
        2;

    _statusLabel.textAlignment =
        NSTextAlignmentCenter;

    [panel
        addSubview:_statusLabel];

    _latField =
        [self
            fieldAtY:110.0
            inPanel:panel
        placeholder:@"Latitude (24.7136)"];

    _lonField =
        [self
            fieldAtY:168.0
            inPanel:panel
        placeholder:@"Longitude (46.6753)"];

    [self
        buttonAtY:230.0
          inPanel:panel
            title:@"📍 تفعيل الموقع الثابت"
           action:@selector(applyStatic)];

    [self
        buttonAtY:288.0
          inPanel:panel
            title:@"↩️ استعادة الموقع الحقيقي"
           action:@selector(restoreDefault)];

    UIButton *close =
        [UIButton
            buttonWithType:
                UIButtonTypeSystem];

    close.frame =
        CGRectMake(
            panel.bounds.size.width - 90.0,
            12.0,
            80.0,
            34.0
        );

    [close
        setTitle:@"✕"
        forState:UIControlStateNormal];

    close.tintColor =
        UIColor.whiteColor;

    [close
        addTarget:self
           action:@selector(closePanel)
 forControlEvents:UIControlEventTouchUpInside];

    [panel
        addSubview:close];

    [window
        addSubview:panel];

    [window
        bringSubviewToFront:panel];

    if (_floatingButton != nil) {
        [window
            bringSubviewToFront:
                _floatingButton];
    }

    _panel =
        panel;

    [self refreshStatus];
}

- (UITextField *)fieldAtY:
    (CGFloat)y
                    inPanel:
    (UIView *)panel
                placeholder:
    (NSString *)placeholder {

    UITextField *field =
        [[UITextField alloc]
            initWithFrame:
                CGRectMake(
                    16.0,
                    y,
                    panel.bounds.size.width - 32.0,
                    44.0
                )];

    field.backgroundColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.08];

    field.textColor =
        UIColor.whiteColor;

    field.keyboardType =
        UIKeyboardTypeNumbersAndPunctuation;

    field.textAlignment =
        NSTextAlignmentCenter;

    field.layer.cornerRadius =
        8.0;

    field.autocorrectionType =
        UITextAutocorrectionTypeNo;

    field.autocapitalizationType =
        UITextAutocapitalizationTypeNone;

    field.placeholder =
        placeholder;

    field.attributedPlaceholder =
        [[NSAttributedString alloc]
            initWithString:
                placeholder ?: @""
            attributes:@{
                NSForegroundColorAttributeName:
                    [UIColor
                        colorWithWhite:1.0
                                 alpha:0.35]
            }];

    [panel
        addSubview:field];

    return field;
}

- (void)buttonAtY:
    (CGFloat)y
          inPanel:
    (UIView *)panel
            title:
    (NSString *)title
           action:
    (SEL)action {

    UIButton *button =
        [UIButton
            buttonWithType:
                UIButtonTypeSystem];

    button.frame =
        CGRectMake(
            16.0,
            y,
            panel.bounds.size.width - 32.0,
            46.0
        );

    button.backgroundColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.10];

    button.layer.cornerRadius =
        10.0;

    button.tintColor =
        UIColor.whiteColor;

    button.titleLabel.font =
        [UIFont
            boldSystemFontOfSize:14.0];

    [button
        setTitle:title
        forState:UIControlStateNormal];

    [button
        addTarget:self
           action:action
 forControlEvents:UIControlEventTouchUpInside];

    [panel
        addSubview:button];
}

- (void)refreshStatus {

    if (_statusLabel == nil) {
        return;
    }

    WFRuntimeState *state =
        [WFRuntimeState sharedState];

    if (state.locationEnabled) {

        _statusLabel.text =
            [NSString
                stringWithFormat:
                    @"الحالة: مفعّل (%.4f, %.4f)\nآخر إجراء: %@",
                    state.currentLatitude,
                    state.currentLongitude,
                    state.lastAction ?: @""];

    } else {

        _statusLabel.text =
            [NSString
                stringWithFormat:
                    @"الحالة: غير مفعّل (موقع حقيقي)\nآخر إجراء: %@",
                    state.lastAction ?: @""];
    }
}

#pragma mark - Actions

- (void)applyStatic {

    NSString *latText =
        [_latField.text
            stringByTrimmingCharactersInSet:
                [NSCharacterSet
                    whitespaceAndNewlineCharacterSet]];

    NSString *lonText =
        [_lonField.text
            stringByTrimmingCharactersInSet:
                [NSCharacterSet
                    whitespaceAndNewlineCharacterSet]];

    if (latText.length == 0 ||
        lonText.length == 0) {

        [self
            showAlertWithTitle:@"خطأ"
                        message:@"أدخل خط العرض وخط الطول."];

        return;
    }

    double latitude =
        [latText doubleValue];

    double longitude =
        [lonText doubleValue];

    WFError *error =
        [[WFAppManager sharedManager]
            activateStaticLocationWithLatitude:
                latitude
            longitude:
                longitude];

    if (![error isSuccess]) {

        [self
            showAlertWithTitle:@"خطأ"
                        message:
                            error.humanReadableMessage
                            ?: @"Unknown error"];
    }

    [self refreshStatus];
}

- (void)restoreDefault {

    [[WFAppManager sharedManager]
        restoreDefaultLocation];

    [self refreshStatus];
}

- (UIViewController *)topViewController {

    UIWindow *window =
        [self keyWindow];

    UIViewController *controller =
        window.rootViewController;

    while (controller != nil) {

        if (controller.presentedViewController != nil) {

            controller =
                controller.presentedViewController;

            continue;
        }

        if ([controller
                isKindOfClass:
                    [UINavigationController class]]) {

            controller =
                ((UINavigationController *)controller)
                    .visibleViewController;

            continue;
        }

        if ([controller
                isKindOfClass:
                    [UITabBarController class]]) {

            controller =
                ((UITabBarController *)controller)
                    .selectedViewController;

            continue;
        }

        break;
    }

    return controller;
}

- (void)showAlertWithTitle:
    (NSString *)title
                  message:
    (NSString *)message {

    UIViewController *controller =
        [self topViewController];

    if (controller == nil) {
        return;
    }

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:title
                             message:message
                      preferredStyle:
                          UIAlertControllerStyleAlert];

    [alert
        addAction:
            [UIAlertAction
                actionWithTitle:@"حسناً"
                          style:
                              UIAlertActionStyleDefault
                        handler:nil]];

    [controller
        presentViewController:alert
                     animated:YES
                   completion:nil];
}

- (void)closePanel {

    [_latField
        resignFirstResponder];

    [_lonField
        resignFirstResponder];

    [_panel
        removeFromSuperview];

    _panel =
        nil;

    _latField =
        nil;

    _lonField =
        nil;

    _statusLabel =
        nil;
}

@end