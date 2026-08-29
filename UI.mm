#import "WolFox.h"
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
    dispatch_once(&onceToken, ^{ instance = [[WFUIController alloc] init]; });
    return instance;
}

#pragma mark Install

- (void)installWhenReady {
    [[NSNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(appWindowDidAppear)
        name:UIWindowDidBecomeVisibleNotification
        object:nil];
}

- (void)appWindowDidAppear {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_floatingButton == nil) {
            [self buildFloatingButton];
        }
    });
}

- (UIWindow *)keyWindow {
    for (UIWindowScene *scene in
         [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *w in scene.windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    return nil;
}

#pragma mark Floating Button

- (void)buildFloatingButton {
    UIWindow *window = [self keyWindow];
    if (window == nil) return;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(20, 200, 56, 56);
    btn.layer.cornerRadius = 28;
    btn.backgroundColor = [UIColor colorWithRed:0.85 green:0.2 blue:0.2 alpha:0.9];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [btn setTitle:@"🦊" forState:UIControlStateNormal];
    btn.layer.shadowOpacity = 0.4;
    btn.layer.shadowRadius = 4;
    [btn addTarget:self action:@selector(togglePanel)
        forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(dragButton:)];
    [btn addGestureRecognizer:pan];

    [window addSubview:btn];
    _floatingButton = btn;

    [[WFLogger sharedLogger] logCategory:WFLogUI
        message:@"Floating button installed"];
}

- (void)dragButton:(UIPanGestureRecognizer *)pan {
    UIView *btn = pan.view;
    CGPoint t = [pan translationInView:btn.superview];
    CGPoint c = btn.center;
    c.x += t.x; c.y += t.y;
    btn.center = c;
    [pan setTranslation:CGPointZero inView:btn.superview];
}

#pragma mark Panel

- (void)togglePanel {
    if (_panel != nil) {
        [self closePanel];
        return;
    }
    [self buildPanel];
}

- (void)buildPanel {
    UIWindow *window = [self keyWindow];
    if (window == nil) return;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 120,
        window.bounds.size.width - 40, 420)];
    panel.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:0.97];
    panel.layer.cornerRadius = 16;
    panel.layer.borderColor = [UIColor colorWithRed:0.85 green:0.2 blue:0.2 alpha:1].CGColor;
    panel.layer.borderWidth = 1.5;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 16,
        panel.bounds.size.width, 30)];
    title.text = @"WolFox Control";
    title.textColor = UIColor.whiteColor;
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:18];
    [panel addSubview:title];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 52,
        panel.bounds.size.width - 32, 40)];
    _statusLabel.textColor = [UIColor lightGrayColor];
    _statusLabel.font = [UIFont systemFontOfSize:12];
    _statusLabel.numberOfLines = 2;
    [panel addSubview:_statusLabel];

    _latField = [self fieldAtY:110 inPanel:panel placeholder:@"Latitude (24.7136)"];
    _lonField = [self fieldAtY:168 inPanel:panel placeholder:@"Longitude (46.6753)"];

    [self buttonAtY:230 inPanel:panel title:@"📍 تفعيل الموقع الثابت"
        action:@selector(applyStatic)];
    [self buttonAtY:288 inPanel:panel title:@"↩️ استعادة الموقع الحقيقي"
        action:@selector(restoreDefault)];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(panel.bounds.size.width - 90, 12, 80, 34);
    [close setTitle:@"✕" forState:UIControlStateNormal];
    close.tintColor = UIColor.whiteColor;
    [close addTarget:self action:@selector(closePanel)
        forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:close];

    [window addSubview:panel];
    _panel = panel;

    [self refreshStatus];
}

- (UITextField *)fieldAtY:(CGFloat)y inPanel:(UIView *)panel {
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(16, y,
        panel.bounds.size.width - 32, 44)];
    f.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    f.textColor = UIColor.whiteColor;
    f.keyboardType = UIKeyboardTypeDecimalPad;
    f.textAlignment = NSTextAlignmentCenter;
    f.layer.cornerRadius = 8;
    f.autocorrectionType = UITextAutocorrectionTypeNo;
    [panel addSubview:f];
    return f;
}

- (void)buttonAtY:(CGFloat)y inPanel:(UIView *)panel
             title:(NSString *)title action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(16, y, panel.bounds.size.width - 32, 46);
    b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
    b.layer.cornerRadius = 10;
    b.tintColor = UIColor.whiteColor;
    b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [b setTitle:title forState:UIControlStateNormal];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:b];
}

- (void)refreshStatus {
    WFRuntimeState *s = [WFRuntimeState sharedState];
    _statusLabel.text = [NSString stringWithFormat:
        @"الحالة: %@\nآخر إجراء: %@",
        s.locationEnabled
            ? [NSString stringWithFormat:@"مفعّل (%.4f, %.4f) — %@",
                s.currentLatitude, s.currentLongitude, s.lastAction]
            : @"غير مفعّل (موقع حقيقي)",
        s.lastAction ?: @""];
}

#pragma mark Actions

- (void)applyStatic {
    double lat = [_latField.text doubleValue];
    double lon = [_lonField.text doubleValue];
    WFError *err = [[WFAppManager sharedManager]
        activateStaticLocationWithLatitude:lat longitude:lon];
    if (!err.isSuccess) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"خطأ"
            message:err.humanReadableMessage
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسناً"
            style:UIAlertActionStyleDefault handler:nil]];
        [[self keyWindow].rootViewController
            presentViewController:alert animated:YES completion:nil];
    }
    [self refreshStatus];
}

- (void)restoreDefault {
    [[WFAppManager sharedManager] restoreDefaultLocation];
    [self refreshStatus];
}

- (void)closePanel {
    [_panel removeFromSuperview];
    _panel = nil;
}

@end
