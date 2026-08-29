#import "WolFox.h"
#import "UI.h"

#import <UIKit/UIKit.h>

@interface WFOverlayViewController : UIViewController
@end

@implementation WFOverlayViewController

- (void)loadView {

    UIView *view =
        [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];

    view.backgroundColor =
        UIColor.clearColor;

    self.view = view;
}

@end


@implementation WFUIController {
    UIWindow *_overlayWindow;
    UIButton *_button;
}

+ (instancetype)sharedController {

    static WFUIController *instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[WFUIController alloc] init];
    });

    return instance;
}

#pragma mark - FORCE AUTO START

+ (void)load {

    NSLog(@"[WolFox] WFUIController +load FIRED");

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(2.0 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

        NSLog(@"[WolFox] Starting FORCE UI");

        [[WFUIController sharedController]
            installWhenReady];
    });
}

#pragma mark - Install

- (void)installWhenReady {

    NSLog(@"[WolFox] installWhenReady");

    dispatch_async(dispatch_get_main_queue(), ^{

        [self installOverlay];
    });
}

#pragma mark - Scene

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

            return (UIWindowScene *)scene;
        }
    }

    return nil;
}

#pragma mark - Overlay

- (void)installOverlay {

    if (_overlayWindow != nil) {

        _overlayWindow.hidden = NO;

        NSLog(@"[WolFox] Overlay already exists");

        return;
    }

    NSLog(@"[WolFox] Creating overlay");

    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {

        UIWindowScene *scene =
            [self activeWindowScene];

        if (scene == nil) {

            NSLog(@"[WolFox] NO WINDOW SCENE");

            [self retryInstallation];

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

    WFOverlayViewController *controller =
        [[WFOverlayViewController alloc] init];

    window.rootViewController =
        controller;

    window.hidden = NO;

    _overlayWindow =
        window;

    NSLog(@"[WolFox] Overlay window created");

    [self createButtonOnView:
        controller.view];
}

#pragma mark - Retry

- (void)retryInstallation {

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(1.0 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

        if (self->_overlayWindow == nil) {

            NSLog(@"[WolFox] Retrying overlay installation");

            [self installOverlay];
        }
    });
}

#pragma mark - Button

- (void)createButtonOnView:
    (UIView *)view {

    if (_button != nil) {
        return;
    }

    UIButton *button =
        [UIButton buttonWithType:
            UIButtonTypeCustom];

    button.frame =
        CGRectMake(
            20.0,
            180.0,
            90.0,
            90.0
        );

    button.backgroundColor =
        UIColor.redColor;

    button.layer.cornerRadius =
        45.0;

    button.layer.borderWidth =
        4.0;

    button.layer.borderColor =
        UIColor.whiteColor.CGColor;

    button.layer.shadowOpacity =
        0.9;

    button.layer.shadowRadius =
        10.0;

    button.layer.shadowOffset =
        CGSizeMake(
            0.0,
            4.0
        );

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
            boldSystemFontOfSize:
                26.0];

    [button
        addTarget:self
           action:@selector(buttonPressed)
 forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handlePan:)];

    [button
        addGestureRecognizer:pan];

    [view addSubview:button];

    [view bringSubviewToFront:button];

    _button =
        button;

    NSLog(@"[WolFox] ***** WF BUTTON CREATED *****");
}

#pragma mark - Button Action

- (void)buttonPressed {

    NSLog(@"[WolFox] WF BUTTON PRESSED");

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:
                @"WolFox"
                             message:
                @"WolFox.dylib loaded successfully ✅"
                      preferredStyle:
                UIAlertControllerStyleAlert];

    [alert
        addAction:
            [UIAlertAction
                actionWithTitle:@"OK"
                          style:
                    UIAlertActionStyleDefault
                        handler:nil]];

    [_overlayWindow.rootViewController
        presentViewController:alert
                     animated:YES
                   completion:nil];
}

#pragma mark - Drag

- (void)handlePan:
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

@end