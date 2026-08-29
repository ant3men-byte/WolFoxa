#import "WolFox.h"
#import "UI.h"

#import <UIKit/UIKit.h>

#pragma mark - WFUIController

@implementation WFUIController {
    UIButton *_debugButton;
    dispatch_source_t _retryTimer;
    NSInteger _retryCount;
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

    [[WFLogger sharedLogger]
        logCategory:WFLogUI
        message:@"WFUIController installWhenReady called"];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(applicationDidBecomeActive:)
               name:UIApplicationDidBecomeActiveNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(windowDidBecomeVisible:)
               name:UIWindowDidBecomeVisibleNotification
             object:nil];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self startRetryLoop];
    });
}

#pragma mark - Notifications

- (void)applicationDidBecomeActive:
    (NSNotification *)notification {

    (void)notification;

    [[WFLogger sharedLogger]
        logCategory:WFLogUI
        message:@"UIApplicationDidBecomeActiveNotification received"];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self tryInstallDebugButton];
    });
}

- (void)windowDidBecomeVisible:
    (NSNotification *)notification {

    UIWindow *window =
        [notification.object isKindOfClass:[UIWindow class]]
            ? (UIWindow *)notification.object
            : nil;

    NSString *message =
        [NSString stringWithFormat:
            @"UIWindowDidBecomeVisibleNotification received window=%@",
            window];

    [[WFLogger sharedLogger]
        logCategory:WFLogUI
        message:message];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self tryInstallDebugButton];
    });
}

#pragma mark - Retry

- (void)startRetryLoop {

    if (_retryTimer != nil) {
        return;
    }

    _retryCount = 0;

    dispatch_queue_t queue =
        dispatch_get_main_queue();

    _retryTimer =
        dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER,
            0,
            0,
            queue
        );

    uint64_t interval =
        (uint64_t)(0.5 * NSEC_PER_SEC);

    dispatch_source_set_timer(
        _retryTimer,
        dispatch_time(
            DISPATCH_TIME_NOW,
            0
        ),
        interval,
        (uint64_t)(0.05 * NSEC_PER_SEC)
    );

    __weak WFUIController *weakSelf =
        self;

    dispatch_source_set_event_handler(
        _retryTimer,
        ^{

        WFUIController *strongSelf =
            weakSelf;

        if (strongSelf == nil) {
            return;
        }

        strongSelf->_retryCount += 1;

        [strongSelf tryInstallDebugButton];

        if (strongSelf->_debugButton != nil ||
            strongSelf->_retryCount >= 40) {

            [strongSelf stopRetryLoop];
        }
    });

    dispatch_resume(_retryTimer);

    [[WFLogger sharedLogger]
        logCategory:WFLogUI
        message:@"UI retry loop started"];
}

- (void)stopRetryLoop {

    if (_retryTimer == nil) {
        return;
    }

    dispatch_source_cancel(_retryTimer);

    _retryTimer = nil;

    [[WFLogger sharedLogger]
        logCategory:WFLogUI
        message:@"UI retry loop stopped"];
}

#pragma mark - Window Discovery

- (NSArray<UIWindow *> *)allWindows {

    NSMutableArray<UIWindow *> *result =
        [NSMutableArray array];

    UIApplication *application =
        [UIApplication sharedApplication];

    if (@available(iOS 13.0, *)) {

        for (UIScene *scene in
             application.connectedScenes) {

            if (![scene
                    isKindOfClass:
                        [UIWindowScene class]]) {

                continue;
            }

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            for (UIWindow *window in
                 windowScene.windows) {

                if (window != nil) {
                    [result addObject:window];
                }
            }
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

    for (UIWindow *window in
         application.windows) {

        if (window != nil &&
            ![result containsObject:window]) {

            [result addObject:window];
        }
    }

#pragma clang diagnostic pop

    return result;
}

- (UIWindow *)bestWindow {

    NSArray<UIWindow *> *windows =
        [self allWindows];

    for (UIWindow *window in windows) {

        if (window.isKeyWindow &&
            !window.hidden &&
            window.alpha > 0.0) {

            return window;
        }
    }

    for (UIWindow *window in windows) {

        if (!window.hidden &&
            window.alpha > 0.0 &&
            window.windowLevel ==
                UIWindowLevelNormal) {

            return window;
        }
    }

    for (UIWindow *window in windows) {

        if (!window.hidden &&
            window.alpha > 0.0) {

            return window;
        }
    }

    return nil;
}

#pragma mark - Debug Button

- (void)tryInstallDebugButton {

    if (_debugButton != nil &&
        _debugButton.superview != nil) {

        [_debugButton.superview
            bringSubviewToFront:_debugButton];

        return;
    }

    UIWindow *window =
        [self bestWindow];

    if (window == nil) {

        NSString *message =
            [NSString stringWithFormat:
                @"No usable UIWindow yet, attempt=%ld",
                (long)_retryCount];

        [[WFLogger sharedLogger]
            logCategory:WFLogUI
            message:message];

        return;
    }

    NSString *windowMessage =
        [NSString stringWithFormat:
            @"Installing debug button on window=%@ frame=%@ level=%.1f",
            window,
            NSStringFromCGRect(window.frame),
            window.windowLevel];

    [[WFLogger sharedLogger]
        logCategory:WFLogUI
        message:windowMessage];

    UIButton *button =
        [UIButton buttonWithType:
            UIButtonTypeCustom];

    button.frame =
        CGRectMake(
            20.0,
            180.0,
            80.0,
            80.0
        );

    button.backgroundColor =
        UIColor.redColor;

    button.layer.cornerRadius =
        40.0;

    button.layer.borderWidth =
        3.0;

    button.layer.borderColor =
        UIColor.whiteColor.CGColor;

    button.layer.shadowOpacity =
        0.8;

    button.layer.shadowRadius =
        8.0;

    button.layer.shadowOffset =
        CGSizeMake(0.0, 3.0);

    [button
        setTitle:@"WF"
        forState:UIControlStateNormal];

    [button
        setTitleColor:
            UIColor.whiteColor
        forState:
            UIControlStateNormal];

    button.titleLabel.font =
        [UIFont
            boldSystemFontOfSize:24.0];

    [button
        addTarget:self
           action:@selector(debugButtonPressed)
 forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(dragDebugButton:)];

    [button
        addGestureRecognizer:pan];

    [window addSubview:button];

    [window bringSubviewToFront:button];

    _debugButton =
        button;

    [[WFLogger sharedLogger]
        logCategory:WFLogUI
        message:@"DEBUG BUTTON INSTALLED SUCCESSFULLY"];
}

- (void)debugButtonPressed {

    [[WFLogger sharedLogger]
        logCategory:WFLogUI
        message:@"DEBUG BUTTON PRESSED"];

    UIWindow *window =
        [self bestWindow];

    UIViewController *controller =
        window.rootViewController;

    while (controller.presentedViewController != nil) {

        controller =
            controller.presentedViewController;
    }

    if (controller == nil) {
        return;
    }

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:
                @"WolFox"
                             message:
                @"واجهة WolFox تعمل ✅"
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

#pragma mark - Drag

- (void)dragDebugButton:
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
        CGRectGetWidth(
            button.bounds
        ) / 2.0;

    CGFloat halfHeight =
        CGRectGetHeight(
            button.bounds
        ) / 2.0;

    center.x =
        MAX(
            halfWidth,
            MIN(
                CGRectGetWidth(
                    container.bounds
                ) - halfWidth,
                center.x
            )
        );

    center.y =
        MAX(
            halfHeight,
            MIN(
                CGRectGetHeight(
                    container.bounds
                ) - halfHeight,
                center.y
            )
        );

    button.center =
        center;

    [pan
        setTranslation:
            CGPointZero
              inView:
            container];
}

@end