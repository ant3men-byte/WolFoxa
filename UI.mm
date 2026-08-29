#import "WolFox.h"
#import "UI.h"

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

#pragma mark - Root

@interface WFOverlayRootController : UIViewController
@end

@implementation WFOverlayRootController
- (void)loadView {
    UIView *v = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    v.backgroundColor = UIColor.clearColor;
    self.view = v;
}
@end

#pragma mark - UI

@interface WFUIController () <MKMapViewDelegate, UISearchBarDelegate>
@end

@implementation WFUIController {
    UIWindow *_overlayWindow;
    UIButton *_floatingButton;
    UIScrollView *_panel;
    UIView *_content;

    UISearchBar *_searchBar;
    MKMapView *_mapView;
    UILabel *_coordLabel;
    UILabel *_statusLabel;
    UISwitch *_locationSwitch;
    UISwitch *_photoSwitch;

    CLLocationCoordinate2D _selectedCoordinate;
    BOOL _hasCoordinate;
}

+ (instancetype)sharedController {
    static WFUIController *obj;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[WFUIController alloc] init];
    });
    return obj;
}

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[WFUIController sharedController] installWhenReady];
    });
}

- (void)installWhenReady {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self installOverlay];
    });
}

- (UIWindowScene *)activeScene API_AVAILABLE(ios(13.0)) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        if (scene.activationState == UISceneActivationStateForegroundActive ||
            scene.activationState == UISceneActivationStateForegroundInactive) {
            return (UIWindowScene *)scene;
        }
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) return (UIWindowScene *)scene;
    }
    return nil;
}

- (void)installOverlay {
    if (_overlayWindow) {
        _overlayWindow.hidden = NO;
        return;
    }

    UIWindow *w = nil;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = [self activeScene];
        if (!scene) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^{
                [self installOverlay];
            });
            return;
        }
        w = [[UIWindow alloc] initWithWindowScene:scene];
    } else {
        w = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }

    w.frame = UIScreen.mainScreen.bounds;
    w.backgroundColor = UIColor.clearColor;
    w.windowLevel = UIWindowLevelAlert + 1000.0;

    WFOverlayRootController *root = [[WFOverlayRootController alloc] init];
    w.rootViewController = root;
    w.hidden = NO;
    _overlayWindow = w;

    [self buildFloatingButton:root.view];
}

#pragma mark - Helpers

- (UIColor *)panelColor {
    return [UIColor colorWithRed:0.105 green:0.11 blue:0.12 alpha:0.985];
}

- (UIColor *)cardColor {
    return [UIColor colorWithRed:0.19 green:0.20 blue:0.21 alpha:0.98];
}

- (UILabel *)label:(NSString *)text frame:(CGRect)frame size:(CGFloat)size bold:(BOOL)bold {
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.text = text;
    l.textColor = UIColor.whiteColor;
    l.font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    return l;
}

- (UIButton *)button:(NSString *)title frame:(CGRect)frame tint:(UIColor *)tint {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = frame;
    b.layer.cornerRadius = 13.0;
    b.layer.borderWidth = 1.0;
    b.layer.borderColor = [tint colorWithAlphaComponent:0.65].CGColor;
    b.backgroundColor = [tint colorWithAlphaComponent:0.23];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    return b;
}

- (UIView *)card:(CGRect)frame {
    UIView *v = [[UIView alloc] initWithFrame:frame];
    v.backgroundColor = [self cardColor];
    v.layer.cornerRadius = 16.0;
    v.layer.borderWidth = 1.0;
    v.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    return v;
}

#pragma mark - Floating

- (void)buildFloatingButton:(UIView *)root {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = CGRectMake(18, 160, 62, 62);
    b.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.10 alpha:0.98];
    b.layer.cornerRadius = 31;
    b.layer.borderWidth = 2;
    b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    b.layer.shadowOpacity = 0.35;
    b.layer.shadowRadius = 8;
    [b setTitle:@"ð¦" forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:29];
    [b addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragFloating:)];
    [b addGestureRecognizer:pan];

    [root addSubview:b];
    _floatingButton = b;
}

- (void)dragFloating:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    UIView *p = v.superview;
    CGPoint t = [g translationInView:p];
    CGPoint c = v.center;
    c.x += t.x;
    c.y += t.y;
    CGFloat hw = CGRectGetWidth(v.bounds)/2.0;
    CGFloat hh = CGRectGetHeight(v.bounds)/2.0;
    c.x = MAX(hw, MIN(CGRectGetWidth(p.bounds)-hw, c.x));
    c.y = MAX(hh, MIN(CGRectGetHeight(p.bounds)-hh, c.y));
    v.center = c;
    [g setTranslation:CGPointZero inView:p];
}

#pragma mark - Panel

- (void)togglePanel {
    if (_panel) [self closePanel];
    else [self buildPanel];
}

- (void)buildPanel {
    UIView *root = _overlayWindow.rootViewController.view;
    if (!root) return;

    CGFloat sw = CGRectGetWidth(root.bounds);
    CGFloat sh = CGRectGetHeight(root.bounds);
    CGFloat pw = MIN(390.0, sw - 28.0);
    CGFloat ph = MIN(790.0, sh - 55.0);
    CGFloat px = (sw-pw)/2.0;
    CGFloat py = MAX(24.0, (sh-ph)/2.0);

    UIScrollView *panel = [[UIScrollView alloc] initWithFrame:CGRectMake(px, py, pw, ph)];
    panel.backgroundColor = [self panelColor];
    panel.layer.cornerRadius = 28;
    panel.layer.masksToBounds = YES;
    panel.showsVerticalScrollIndicator = NO;

    UIView *content = [[UIView alloc] initWithFrame:CGRectMake(0,0,pw,1040)];
    [panel addSubview:content];
    panel.contentSize = content.bounds.size;

    [root addSubview:panel];
    _panel = panel;
    _content = content;
    _floatingButton.hidden = YES;

    CGFloat W = pw;
    CGFloat margin = 15;
    CGFloat inner = W - margin*2;

    // Header
    UILabel *logo = [self label:@"ð¦  WolFox" frame:CGRectMake(18,16,175,38) size:24 bold:YES];
    [content addSubview:logo];

    UILabel *sub = [self label:@"Standalone Runtime" frame:CGRectMake(70,48,170,18) size:11 bold:NO];
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.45];
    [content addSubview:sub];

    UIButton *support = [self button:@"âï¸  Ø§ÙØ¯Ø¹Ù" frame:CGRectMake(W-165,14,92,42)
                                tint:[UIColor colorWithRed:0.0 green:0.68 blue:0.92 alpha:1]];
    [support addTarget:self action:@selector(showSupport) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:support];

    UIButton *info = [UIButton buttonWithType:UIButtonTypeSystem];
    info.frame = CGRectMake(W-68,15,38,38);
    info.backgroundColor = [UIColor colorWithRed:0.16 green:0.76 blue:0.29 alpha:1];
    info.layer.cornerRadius = 19;
    [info setTitle:@"â" forState:UIControlStateNormal];
    [info setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    info.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [info addTarget:self action:@selector(showStatus) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:info];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(W-34,17,28,34);
    [close setTitle:@"Ã" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor colorWithWhite:1 alpha:.65] forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:30];
    [close addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:close];

    // Search
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(margin,72,inner,48)];
    _searchBar.delegate = self;
    _searchBar.placeholder = @"Ø¨Ø­Ø« Ø¹Ù ÙÙÙØ¹";
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.barStyle = UIBarStyleBlack;
    [content addSubview:_searchBar];

    // Save row
    UIColor *orange = [UIColor colorWithRed:.95 green:.55 blue:.0 alpha:1];
    UIColor *green  = [UIColor colorWithRed:.10 green:.72 blue:.30 alpha:1];
    UIColor *red    = [UIColor colorWithRed:.92 green:.23 blue:.20 alpha:1];
    UIColor *cyan   = [UIColor colorWithRed:.0 green:.72 blue:.88 alpha:1];
    UIColor *teal   = [UIColor colorWithRed:.08 green:.72 blue:.62 alpha:1];
    UIColor *purple = [UIColor colorWithRed:.58 green:.31 blue:.92 alpha:1];

    CGFloat gap=8, third=(inner-gap*2)/3.0;
    UIButton *saved=[self button:@"ð Ø§ÙÙØ­ÙÙØ¸Ø§Øª" frame:CGRectMake(margin,130,third,48) tint:orange];
    UIButton *save=[self button:@"â  Ø­ÙØ¸" frame:CGRectMake(margin+third+gap,130,third,48) tint:green];
    UIButton *restore=[self button:@"â¶  Ø§Ø³ØªØ¹Ø§Ø¯Ø©" frame:CGRectMake(margin+(third+gap)*2,130,third,48) tint:red];
    [saved addTarget:self action:@selector(showSaved) forControlEvents:UIControlEventTouchUpInside];
    [save addTarget:self action:@selector(saveCurrent) forControlEvents:UIControlEventTouchUpInside];
    [restore addTarget:self action:@selector(restoreLocation) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:saved]; [content addSubview:save]; [content addSubview:restore];

    // Map
    _mapView = [[MKMapView alloc] initWithFrame:CGRectMake(margin,188,inner,210)];
    _mapView.delegate = self;
    _mapView.layer.cornerRadius = 18;
    _mapView.layer.masksToBounds = YES;
    _mapView.showsUserLocation = YES;
    [content addSubview:_mapView];

    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(mapLongPress:)];
    lp.minimumPressDuration = .3;
    [_mapView addGestureRecognizer:lp];

    UIButton *expand=[self button:@"â¤¢" frame:CGRectMake(W-70,202,42,42)
                             tint:[UIColor colorWithWhite:.7 alpha:1]];
    [expand addTarget:self action:@selector(centerSelected) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:expand];

    CLLocationCoordinate2D start = CLLocationCoordinate2DMake(24.7136,46.6753);
    [self selectCoordinate:start animated:NO];

    // Map mode row
    UISegmentedControl *mapModes =
        [[UISegmentedControl alloc] initWithItems:@[@"Ø¹Ø§Ø¯Ù",@"ÙÙØ± ØµÙØ§Ø¹Ù"]];
    mapModes.frame = CGRectMake(margin,408,inner*0.50-4,42);
    mapModes.selectedSegmentIndex = 0;
    [mapModes addTarget:self action:@selector(mapModeChanged:) forControlEvents:UIControlEventValueChanged];
    [content addSubview:mapModes];

    UIButton *myLocation=[self button:@"â¤  ÙÙÙØ¹Ù"
                                frame:CGRectMake(margin+inner*0.50+4,408,inner*0.50-4,42)
                                 tint:cyan];
    [myLocation addTarget:self action:@selector(goMyLocation) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:myLocation];

    // Location switch
    UIView *locCard=[self card:CGRectMake(margin,460,inner,58)];
    [content addSubview:locCard];
    UILabel *locTitle=[self label:@"â¤  ØªÙØ¹ÙÙ ØªØºÙÙØ± Ø§ÙÙÙÙØ¹"
                            frame:CGRectMake(18,8,inner-95,42) size:17 bold:NO];
    [locCard addSubview:locTitle];
    _locationSwitch=[[UISwitch alloc] initWithFrame:CGRectMake(inner-68,13,55,32)];
    [_locationSwitch addTarget:self action:@selector(locationSwitchChanged:)
              forControlEvents:UIControlEventValueChanged];
    [locCard addSubview:_locationSwitch];

    _coordLabel=[self label:@"" frame:CGRectMake(margin,521,inner,22) size:11 bold:NO];
    _coordLabel.textAlignment=NSTextAlignmentCenter;
    _coordLabel.textColor=[UIColor colorWithWhite:1 alpha:.55];
    [content addSubview:_coordLabel];
    [self refreshCoordinate];

    // Route/random/schedule
    UIButton *route=[self button:@"â  ÙØ³Ø§Ø±" frame:CGRectMake(margin,550,third,50) tint:teal];
    UIButton *random=[self button:@"â¤¨  Ø¹Ø´ÙØ§Ø¦Ù" frame:CGRectMake(margin+third+gap,550,third,50) tint:purple];
    UIButton *schedule=[self button:@"â·  Ø§ÙØ¬Ø¯ÙÙØ©" frame:CGRectMake(margin+(third+gap)*2,550,third,50) tint:cyan];
    [route addTarget:self action:@selector(routeTapped) forControlEvents:UIControlEventTouchUpInside];
    [random addTarget:self action:@selector(randomTapped) forControlEvents:UIControlEventTouchUpInside];
    [schedule addTarget:self action:@selector(scheduleTapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:route]; [content addSubview:random]; [content addSubview:schedule];

    // Alternate photo card
    UIView *photoCard=[self card:CGRectMake(margin,612,inner,112)];
    [content addSubview:photoCard];
    UILabel *photoTitle=[self label:@"ð·  ØµÙØ±Ø© Ø¨Ø¯ÙÙØ©" frame:CGRectMake(16,8,180,38) size:17 bold:NO];
    [photoCard addSubview:photoTitle];
    _photoSwitch=[[UISwitch alloc] initWithFrame:CGRectMake(inner-68,12,55,32)];
    [photoCard addSubview:_photoSwitch];

    CGFloat pGap=8, pW=(inner-32-pGap*2)/3.0;
    UIButton *flip=[self button:@"Ø¹ÙØ³" frame:CGRectMake(16,57,pW,38) tint:teal];
    UIButton *upload=[self button:@"Ø±ÙØ¹" frame:CGRectMake(16+pW+pGap,57,pW,38) tint:orange];
    UIButton *del=[self button:@"Ø­Ø°Ù" frame:CGRectMake(16+(pW+pGap)*2,57,pW,38) tint:red];
    [flip addTarget:self action:@selector(notImplemented) forControlEvents:UIControlEventTouchUpInside];
    [upload addTarget:self action:@selector(notImplemented) forControlEvents:UIControlEventTouchUpInside];
    [del addTarget:self action:@selector(notImplemented) forControlEvents:UIControlEventTouchUpInside];
    [photoCard addSubview:flip]; [photoCard addSubview:upload]; [photoCard addSubview:del];

    // Bluetooth / WiFi
    CGFloat half=(inner-gap)/2.0;
    UIButton *bt=[self button:@"â))) Ø§ÙØ¨ÙÙØªÙØ«" frame:CGRectMake(margin,738,half,50)
                        tint:[UIColor colorWithRed:.1 green:.58 blue:.9 alpha:1]];
    UIButton *wifi=[self button:@"â  Ø§ÙÙØ§Ù ÙØ§Ù" frame:CGRectMake(margin+half+gap,738,half,50) tint:cyan];
    [bt addTarget:self action:@selector(bluetoothTapped) forControlEvents:UIControlEventTouchUpInside];
    [wifi addTarget:self action:@selector(wifiTapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:bt]; [content addSubview:wifi];

    // Device card
    UIView *device=[self card:CGRectMake(margin,800,inner,64)];
    [content addSubview:device];
    UILabel *deviceTitle=[self label:@"ð±  ÙØ¹Ø±Ù Ø§ÙØ¬ÙØ§Ø²" frame:CGRectMake(15,10,145,42) size:16 bold:NO];
    [device addSubview:deviceTitle];

    NSArray *deviceButtons=@[@"ÙØ³Ø®",@"ØªØ¹Ø¨Ø¦Ø©",@"ÙÙÙØ©",@"Ø§Ø³ØªØ¹Ø§Ø¯Ø©"];
    NSArray *deviceColors=@[orange,cyan,purple,green];
    CGFloat dW=(inner-170)/4.0;
    for (NSInteger i=0;i<4;i++) {
        UIButton *b=[self button:deviceButtons[i]
                          frame:CGRectMake(160+i*dW,13,dW-4,38)
                           tint:deviceColors[i]];
        [b addTarget:self action:@selector(deviceAction:) forControlEvents:UIControlEventTouchUpInside];
        b.tag=i;
        [device addSubview:b];
    }

    // Support / shop
    UIButton *shop=[self button:@"ð  Ø´Ø±Ø§Ø¡ ÙÙØ¯" frame:CGRectMake(margin,878,half,52) tint:orange];
    UIButton *chat=[self button:@"â  Ø§ÙØ¯Ø¹Ù Ø§ÙÙÙÙ" frame:CGRectMake(margin+half+gap,878,half,52) tint:cyan];
    [shop addTarget:self action:@selector(showSupport) forControlEvents:UIControlEventTouchUpInside];
    [chat addTarget:self action:@selector(showSupport) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:shop]; [content addSubview:chat];

    // Bottom controls
    UIButton *stop=[self button:@"â¹  Ø¥ÙÙØ§Ù Ø§ÙÙÙ" frame:CGRectMake(margin,944,third,50) tint:red];
    UIButton *hide=[self button:@"âÌ¸  Ø¥Ø®ÙØ§Ø¡ Ø§ÙØ£Ø¯Ø§Ø©" frame:CGRectMake(margin+third+gap,944,third,50)
                           tint:[UIColor colorWithWhite:.65 alpha:1]];
    UIButton *custom=[self button:@"â·  ØªØ®ØµÙØµ" frame:CGRectMake(margin+(third+gap)*2,944,third,50) tint:cyan];
    [stop addTarget:self action:@selector(stopAll) forControlEvents:UIControlEventTouchUpInside];
    [hide addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [custom addTarget:self action:@selector(notImplemented) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:stop]; [content addSubview:hide]; [content addSubview:custom];

    _statusLabel=[self label:@"DEFAULT" frame:CGRectMake(margin,1004,inner,20) size:11 bold:NO];
    _statusLabel.textAlignment=NSTextAlignmentCenter;
    _statusLabel.textColor=[UIColor colorWithWhite:1 alpha:.45];
    [content addSubview:_statusLabel];

    [self refreshStatus];
}

#pragma mark - Map

- (void)mapLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    CGPoint p=[g locationInView:_mapView];
    CLLocationCoordinate2D c=[_mapView convertPoint:p toCoordinateFromView:_mapView];
    [self selectCoordinate:c animated:YES];
}

- (void)selectCoordinate:(CLLocationCoordinate2D)c animated:(BOOL)animated {
    _selectedCoordinate=c;
    _hasCoordinate=YES;

    NSMutableArray *remove=[NSMutableArray array];
    for (id<MKAnnotation> a in _mapView.annotations) {
        if (![a isKindOfClass:MKUserLocation.class]) [remove addObject:a];
    }
    [_mapView removeAnnotations:remove];

    MKPointAnnotation *pin=[[MKPointAnnotation alloc] init];
    pin.coordinate=c;
    pin.title=@"Selected Location";
    [_mapView addAnnotation:pin];

    MKCoordinateRegion r=MKCoordinateRegionMakeWithDistance(c,650000,650000);
    [_mapView setRegion:r animated:animated];
    [self refreshCoordinate];
}

- (void)refreshCoordinate {
    if (!_coordLabel || !_hasCoordinate) return;
    _coordLabel.text=[NSString stringWithFormat:@"%.6f   %.6f",
                      _selectedCoordinate.latitude,_selectedCoordinate.longitude];
}

- (void)mapModeChanged:(UISegmentedControl *)s {
    _mapView.mapType = s.selectedSegmentIndex == 0 ? MKMapTypeStandard : MKMapTypeSatellite;
}

- (void)centerSelected {
    if (!_hasCoordinate) return;
    MKCoordinateRegion r=MKCoordinateRegionMakeWithDistance(_selectedCoordinate,1500,1500);
    [_mapView setRegion:r animated:YES];
}

- (void)goMyLocation {
    CLLocation *loc=_mapView.userLocation.location;
    if (!loc) {
        [self alert:@"Ø§ÙÙÙÙØ¹ Ø§ÙØ­Ø§ÙÙ ØºÙØ± ÙØªØ§Ø­."];
        return;
    }
    [self selectCoordinate:loc.coordinate animated:YES];
}

#pragma mark - Search

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    NSString *q=searchBar.text;
    if (!q.length) return;
    [searchBar resignFirstResponder];

    MKLocalSearchRequest *req=[[MKLocalSearchRequest alloc] init];
    req.naturalLanguageQuery=q;
    MKLocalSearch *search=[[MKLocalSearch alloc] initWithRequest:req];

    __weak WFUIController *weakSelf=self;
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        WFUIController *selfRef=weakSelf;
        if (!selfRef) return;
        if (error || !response.mapItems.count) {
            [selfRef alert:@"ÙÙ ÙØªÙ Ø§ÙØ¹Ø«ÙØ± Ø¹ÙÙ Ø§ÙÙÙÙØ¹."];
            return;
        }
        MKMapItem *item=response.mapItems.firstObject;
        dispatch_async(dispatch_get_main_queue(), ^{
            [selfRef selectCoordinate:item.placemark.coordinate animated:YES];
        });
    }];
}

#pragma mark - Core actions

- (void)locationSwitchChanged:(UISwitch *)s {
    if (s.isOn) {
        if (!_hasCoordinate) {
            s.on=NO;
            [self alert:@"Ø­Ø¯Ø¯ ÙÙÙØ¹Ø§Ù Ø£ÙÙØ§Ù."];
            return;
        }

        WFError *e=[[WFAppManager sharedManager]
                    activateStaticLocationWithLatitude:_selectedCoordinate.latitude
                    longitude:_selectedCoordinate.longitude];
        if (![e isSuccess]) {
            s.on=NO;
            [self alert:e.humanReadableMessage ?: @"ØªØ¹Ø°Ø± ØªÙØ¹ÙÙ Ø§ÙÙÙÙØ¹."];
        }
    } else {
        [[WFAppManager sharedManager] restoreDefaultLocation];
    }
    [self refreshStatus];
}

- (void)restoreLocation {
    WFError *e=[[WFAppManager sharedManager] restoreDefaultLocation];
    _locationSwitch.on=NO;
    [self refreshStatus];
    [self alert:[e isSuccess] ? @"ØªÙØª Ø§ÙØ§Ø³ØªØ¹Ø§Ø¯Ø© â" :
     (e.humanReadableMessage ?: @"ØªØ¹Ø°Ø±Øª Ø§ÙØ§Ø³ØªØ¹Ø§Ø¯Ø©.")];
}

- (void)saveCurrent {
    if (!_hasCoordinate) {
        [self alert:@"Ø­Ø¯Ø¯ ÙÙÙØ¹Ø§Ù Ø£ÙÙØ§Ù."];
        return;
    }
    WFError *e=[[WFLocationService sharedService]
                addFavoriteWithName:@"WolFox Location"
                latitude:_selectedCoordinate.latitude
                longitude:_selectedCoordinate.longitude];
    [self alert:[e isSuccess] ? @"ØªÙ Ø­ÙØ¸ Ø§ÙÙÙÙØ¹ â" :
     (e.humanReadableMessage ?: @"ØªØ¹Ø°Ø± Ø§ÙØ­ÙØ¸.")];
}

- (void)showSaved {
    NSArray *items=[[WFLocationService sharedService] favorites];
    [self alert:[NSString stringWithFormat:@"Ø¹Ø¯Ø¯ Ø§ÙÙÙØ§ÙØ¹ Ø§ÙÙØ­ÙÙØ¸Ø©: %lu",
                 (unsigned long)items.count]];
}

- (void)routeTapped {
    [self alert:@"ÙØ§Ø¬ÙØ© Ø§ÙÙØ³Ø§Ø± Ø¬Ø§ÙØ²Ø© ÙÙØªÙØµÙÙ Ø¨ÙØ­Ø±Ù Route ÙÙ WolFox."];
}

- (void)randomTapped {
    WFError *e=[[WFAppManager sharedManager] startRandomMovementWithRadius:100.0];
    [self alert:[e isSuccess] ? @"ØªÙ ØªØ´ØºÙÙ Ø§ÙÙØ¶Ø¹ Ø§ÙØ¹Ø´ÙØ§Ø¦Ù ÙÙ WolFox Runtime â" :
     (e.humanReadableMessage ?: @"ØªØ¹Ø°Ø± Ø§ÙØªØ´ØºÙÙ.")];
    [self refreshStatus];
}

- (void)scheduleTapped {
    WFError *e=[[WFAppManager sharedManager] startScheduler];
    [self alert:[e isSuccess] ? @"ØªÙ ØªØ´ØºÙÙ Scheduler ÙÙ WolFox Runtime â" :
     (e.humanReadableMessage ?: @"ØªØ¹Ø°Ø± Ø§ÙØªØ´ØºÙÙ.")];
    [self refreshStatus];
}

- (void)wifiTapped {
    [self alert:@"ÙØ§Ø¬ÙØ© Wi-Fi Ø¬Ø§ÙØ²Ø©. ÙÙØ²Ù Ø§Ø®ØªÙØ§Ø± Profile ID ÙØ±Ø¨Ø·ÙØ§ Ø¨Ø§ÙÙ Core."];
}

- (void)bluetoothTapped {
    [self alert:@"Bluetooth UI ÙÙØ· ÙÙ ÙØ°Ù Ø§ÙÙØ³Ø®Ø©."];
}

- (void)deviceAction:(UIButton *)sender {
    if (sender.tag==3) {
        WFError *e=[[WFAppManager sharedManager] setActiveDeviceProfileWithID:@""];
        (void)e;
    }
    [self alert:@"Device Profile UI Ø¬Ø§ÙØ²Ø© ÙÙØªÙØµÙÙ Ø¨Ø§ÙØ¨ÙØ§ÙØ§Øª Ø§ÙÙØ¹ÙÙØ©."];
}

- (void)stopAll {
    [[WFAppManager sharedManager] stopMovement];
    [[WFAppManager sharedManager] restoreDefaultLocation];
    _locationSwitch.on=NO;
    [self refreshStatus];
    [self alert:@"ØªÙ Ø¥ÙÙØ§Ù Ø­Ø§ÙØ© WolFox Runtime Ø§ÙØ­Ø§ÙÙØ©."];
}

- (void)refreshStatus {
    NSDictionary *s=[[WFRuntimeState sharedState] snapshotForUI];
    BOOL active=[s[@"locationEnabled"] boolValue];
    if (_statusLabel) _statusLabel.text=active ? @"LOCATION ACTIVE" : @"DEFAULT";
    if (_locationSwitch) _locationSwitch.on=active;
}

#pragma mark - Informational

- (void)showStatus {
    NSDictionary *s=[[WFRuntimeState sharedState] snapshotForUI];
    NSString *m=[NSString stringWithFormat:
                 @"Location: %@\nLat: %.6f\nLon: %.6f\nLast: %@",
                 [s[@"locationEnabled"] boolValue] ? @"Active" : @"Default",
                 [s[@"currentLatitude"] doubleValue],
                 [s[@"currentLongitude"] doubleValue],
                 s[@"lastAction"] ?: @""];
    [self alert:m];
}

- (void)showSupport {
    [self alert:@"WolFox"];
}

- (void)notImplemented {
    [self alert:@"ÙØ°Ù Ø§ÙÙØ§Ø¬ÙØ© ÙÙØ¬ÙØ¯Ø©Ø ÙÙÙ Ø§ÙÙØ¸ÙÙØ© ØºÙØ± ÙÙØµÙÙØ© Ø¨Ø§ÙÙ Core Ø§ÙØ­Ø§ÙÙ Ø¨Ø¹Ø¯."];
}

- (void)alert:(NSString *)message {
    UIViewController *vc=_overlayWindow.rootViewController;
    while (vc.presentedViewController) vc=vc.presentedViewController;

    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"WolFox"
                                                             message:message ?: @""
                                                      preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK"
                                         style:UIAlertActionStyleDefault
                                       handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

#pragma mark - Close

- (void)closePanel {
    [_searchBar resignFirstResponder];
    [_panel removeFromSuperview];

    _panel=nil;
    _content=nil;
    _searchBar=nil;
    _mapView=nil;
    _coordLabel=nil;
    _statusLabel=nil;
    _locationSwitch=nil;
    _photoSwitch=nil;

    _floatingButton.hidden=NO;
}

@end
