#import "WolFox.h"
#import "UI.h"

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

#pragma mark - Overlay Root

@interface WFOverlayRootController : UIViewController
@end

@implementation WFOverlayRootController

- (void)loadView {

    UIView *view =
        [[UIView alloc]
            initWithFrame:UIScreen.mainScreen.bounds];

    view.backgroundColor =
        UIColor.clearColor;

    self.view = view;
}

@end


#pragma mark - WolFox UI

@interface WFUIController ()
<
    MKMapViewDelegate,
    UISearchBarDelegate,
    UITableViewDelegate,
    UITableViewDataSource
>
@end


@implementation WFUIController {

    UIWindow *_overlayWindow;

    UIButton *_floatingButton;

    UIView *_mainView;
    UIView *_sideMenu;
    UIView *_bottomCard;

    MKMapView *_mapView;

    UISearchBar *_searchBar;

    UILabel *_coordinateLabel;
    UILabel *_statusLabel;
    UILabel *_modeLabel;

    UIButton *_menuButton;
    UIButton *_closeButton;
    UIButton *_centerButton;
    UIButton *_mapTypeButton;
    UIButton *_activateButton;
    UIButton *_restoreButton;

    UITableView *_menuTable;

    CLLocationCoordinate2D _selectedCoordinate;

    BOOL _hasSelectedCoordinate;
    BOOL _menuVisible;
}


#pragma mark - Singleton

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

    NSLog(@"[WolFox] UI +load");

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

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

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
                isKindOfClass:UIWindowScene.class]) {

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
                isKindOfClass:UIWindowScene.class]) {

            return
                (UIWindowScene *)scene;
        }
    }

    return nil;
}


#pragma mark - Overlay

- (void)installOverlay {

    if (_overlayWindow != nil) {

        _overlayWindow.hidden = NO;

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
        [[WFOverlayRootController alloc] init];

    window.rootViewController =
        root;

    window.hidden =
        NO;

    _overlayWindow =
        window;


    [self buildFloatingButton:
        root.view];


    NSLog(@"[WolFox] overlay ready");
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

- (void)buildFloatingButton:
    (UIView *)parent {

    if (_floatingButton != nil) {
        return;
    }

    UIButton *button =
        [UIButton
            buttonWithType:UIButtonTypeCustom];

    button.frame =
        CGRectMake(
            18.0,
            160.0,
            62.0,
            62.0
        );

    button.backgroundColor =
        [UIColor
            colorWithRed:0.08
                   green:0.09
                    blue:0.11
                   alpha:0.98];

    button.layer.cornerRadius =
        31.0;

    button.layer.borderWidth =
        2.0;

    button.layer.borderColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.20].CGColor;

    button.layer.shadowOpacity =
        0.35;

    button.layer.shadowRadius =
        8.0;

    button.layer.shadowOffset =
        CGSizeMake(0, 4);


    [button
        setTitle:@"🦊"
        forState:UIControlStateNormal];

    button.titleLabel.font =
        [UIFont systemFontOfSize:29.0];


    [button
        addTarget:self
           action:@selector(openMainInterface)
 forControlEvents:UIControlEventTouchUpInside];


    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handleFloatingPan:)];

    [button
        addGestureRecognizer:pan];


    [parent addSubview:button];

    _floatingButton =
        button;
}


#pragma mark - Drag Floating Button

- (void)handleFloatingPan:
    (UIPanGestureRecognizer *)gesture {

    UIView *view =
        gesture.view;

    UIView *parent =
        view.superview;

    if (view == nil ||
        parent == nil) {

        return;
    }

    CGPoint translation =
        [gesture
            translationInView:parent];

    CGPoint center =
        view.center;

    center.x += translation.x;
    center.y += translation.y;

    CGFloat halfW =
        CGRectGetWidth(view.bounds) / 2.0;

    CGFloat halfH =
        CGRectGetHeight(view.bounds) / 2.0;

    center.x =
        MAX(
            halfW,
            MIN(
                CGRectGetWidth(parent.bounds)
                    - halfW,
                center.x
            )
        );

    center.y =
        MAX(
            halfH,
            MIN(
                CGRectGetHeight(parent.bounds)
                    - halfH,
                center.y
            )
        );

    view.center =
        center;

    [gesture
        setTranslation:CGPointZero
                inView:parent];
}


#pragma mark - Open

- (void)openMainInterface {

    if (_mainView != nil) {

        [self closeMainInterface];

        return;
    }

    [self buildMainInterface];
}


#pragma mark - Main Interface

- (void)buildMainInterface {

    UIView *root =
        _overlayWindow
            .rootViewController
            .view;

    if (root == nil) {
        return;
    }


    UIView *main =
        [[UIView alloc]
            initWithFrame:root.bounds];

    main.backgroundColor =
        [UIColor
            colorWithRed:0.04
                   green:0.05
                    blue:0.06
                   alpha:0.98];

    main.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    [root addSubview:main];

    _mainView =
        main;


    [self buildMap];

    [self buildTopBar];

    [self buildMapControls];

    [self buildBottomCard];

    [self buildSideMenu];


    _floatingButton.hidden =
        YES;


    CLLocationCoordinate2D initial =
        CLLocationCoordinate2DMake(
            24.7136,
            46.6753
        );

    [self selectCoordinate:
        initial
         animated:NO];
}


#pragma mark - Map

- (void)buildMap {

    CGRect frame =
        _mainView.bounds;

    MKMapView *map =
        [[MKMapView alloc]
            initWithFrame:frame];

    map.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    map.delegate =
        self;

    map.mapType =
        MKMapTypeStandard;

    map.showsCompass =
        YES;

    map.showsScale =
        NO;

    map.showsUserLocation =
        YES;


    [_mainView addSubview:map];

    _mapView =
        map;


    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(mapLongPressed:)];

    longPress.minimumPressDuration =
        0.35;

    [_mapView
        addGestureRecognizer:longPress];
}


#pragma mark - Top Bar

- (void)buildTopBar {

    CGFloat width =
        CGRectGetWidth(
            _mainView.bounds
        );


    UIView *top =
        [[UIView alloc]
            initWithFrame:
                CGRectMake(
                    12,
                    52,
                    width - 24,
                    58
                )];

    top.autoresizingMask =
        UIViewAutoresizingFlexibleWidth;

    top.backgroundColor =
        [UIColor
            colorWithRed:0.06
                   green:0.07
                    blue:0.09
                   alpha:0.94];

    top.layer.cornerRadius =
        18.0;

    top.layer.shadowOpacity =
        0.20;

    top.layer.shadowRadius =
        8.0;

    [_mainView addSubview:top];


    UIButton *menu =
        [UIButton
            buttonWithType:UIButtonTypeSystem];

    menu.frame =
        CGRectMake(
            8,
            7,
            44,
            44
        );

    [menu
        setTitle:@"☰"
        forState:UIControlStateNormal];

    menu.titleLabel.font =
        [UIFont
            boldSystemFontOfSize:23];

    [menu
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    [menu
        addTarget:self
           action:@selector(toggleSideMenu)
 forControlEvents:UIControlEventTouchUpInside];

    [top addSubview:menu];

    _menuButton =
        menu;


    UIButton *close =
        [UIButton
            buttonWithType:UIButtonTypeSystem];

    close.frame =
        CGRectMake(
            CGRectGetWidth(top.bounds) - 50,
            7,
            44,
            44
        );

    close.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin;

    [close
        setTitle:@"✕"
        forState:UIControlStateNormal];

    close.titleLabel.font =
        [UIFont
            boldSystemFontOfSize:21];

    [close
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    [close
        addTarget:self
           action:@selector(closeMainInterface)
 forControlEvents:UIControlEventTouchUpInside];

    [top addSubview:close];

    _closeButton =
        close;


    UISearchBar *search =
        [[UISearchBar alloc]
            initWithFrame:
                CGRectMake(
                    54,
                    7,
                    CGRectGetWidth(top.bounds)
                        - 110,
                    44
                )];

    search.autoresizingMask =
        UIViewAutoresizingFlexibleWidth;

    search.placeholder =
        @"Search location";

    search.delegate =
        self;

    search.searchBarStyle =
        UISearchBarStyleMinimal;

    search.tintColor =
        UIColor.whiteColor;

    search.barStyle =
        UIBarStyleBlack;


    [top addSubview:search];

    _searchBar =
        search;
}


#pragma mark - Map Controls

- (UIButton *)smallMapButton:
    (NSString *)title
                     y:
    (CGFloat)y {

    CGFloat width =
        CGRectGetWidth(
            _mainView.bounds
        );

    UIButton *button =
        [UIButton
            buttonWithType:UIButtonTypeSystem];

    button.frame =
        CGRectMake(
            width - 62,
            y,
            48,
            48
        );

    button.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin;

    button.backgroundColor =
        [UIColor
            colorWithRed:0.06
                   green:0.07
                    blue:0.09
                   alpha:0.94];

    button.layer.cornerRadius =
        16.0;

    [button
        setTitle:title
        forState:UIControlStateNormal];

    button.titleLabel.font =
        [UIFont
            systemFontOfSize:20];

    [button
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    [_mainView addSubview:button];

    return button;
}


- (void)buildMapControls {

    UIButton *center =
        [self
            smallMapButton:@"◎"
                         y:132];

    [center
        addTarget:self
           action:@selector(centerSelectedLocation)
 forControlEvents:UIControlEventTouchUpInside];

    _centerButton =
        center;


    UIButton *type =
        [self
            smallMapButton:@"◫"
                         y:190];

    [type
        addTarget:self
           action:@selector(changeMapType)
 forControlEvents:UIControlEventTouchUpInside];

    _mapTypeButton =
        type;
}


#pragma mark - Long Press

- (void)mapLongPressed:
    (UILongPressGestureRecognizer *)gesture {

    if (gesture.state !=
        UIGestureRecognizerStateBegan) {

        return;
    }

    CGPoint point =
        [gesture
            locationInView:_mapView];

    CLLocationCoordinate2D coordinate =
        [_mapView
            convertPoint:point
            toCoordinateFromView:_mapView];

    [self
        selectCoordinate:coordinate
                animated:YES];
}


#pragma mark - Coordinate

- (void)selectCoordinate:
    (CLLocationCoordinate2D)coordinate
              animated:
    (BOOL)animated {

    _selectedCoordinate =
        coordinate;

    _hasSelectedCoordinate =
        YES;


    [_mapView
        removeAnnotations:
            _mapView.annotations];


    MKPointAnnotation *pin =
        [[MKPointAnnotation alloc] init];

    pin.coordinate =
        coordinate;

    pin.title =
        @"Selected Location";

    [_mapView
        addAnnotation:pin];


    MKCoordinateRegion region =
        MKCoordinateRegionMakeWithDistance(
            coordinate,
            1600,
            1600
        );

    [_mapView
        setRegion:region
         animated:animated];


    [self refreshCoordinateLabel];
}


- (void)refreshCoordinateLabel {

    if (_coordinateLabel == nil) {
        return;
    }

    if (!_hasSelectedCoordinate) {

        _coordinateLabel.text =
            @"No location selected";

        return;
    }

    _coordinateLabel.text =
        [NSString
            stringWithFormat:
                @"%.6f   %.6f",
                _selectedCoordinate.latitude,
                _selectedCoordinate.longitude];
}


#pragma mark - Bottom Card

- (void)buildBottomCard {

    CGFloat width =
        CGRectGetWidth(
            _mainView.bounds
        );

    CGFloat height =
        CGRectGetHeight(
            _mainView.bounds
        );


    UIView *card =
        [[UIView alloc]
            initWithFrame:
                CGRectMake(
                    14,
                    height - 218,
                    width - 28,
                    196
                )];

    card.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleTopMargin;

    card.backgroundColor =
        [UIColor
            colorWithRed:0.055
                   green:0.06
                    blue:0.075
                   alpha:0.97];

    card.layer.cornerRadius =
        24.0;

    card.layer.shadowOpacity =
        0.25;

    card.layer.shadowRadius =
        12.0;


    [_mainView addSubview:card];

    _bottomCard =
        card;


    UILabel *mode =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    20,
                    15,
                    140,
                    24
                )];

    mode.text =
        @"LOCATION";

    mode.font =
        [UIFont
            boldSystemFontOfSize:12];

    mode.textColor =
        [UIColor
            colorWithRed:0.35
                   green:0.65
                    blue:1.0
                   alpha:1.0];

    [card addSubview:mode];

    _modeLabel =
        mode;


    UILabel *coordinates =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    20,
                    41,
                    CGRectGetWidth(card.bounds)
                        - 40,
                    28
                )];

    coordinates.autoresizingMask =
        UIViewAutoresizingFlexibleWidth;

    coordinates.font =
        [UIFont
            monospacedDigitSystemFontOfSize:15
                                     weight:UIFontWeightMedium];

    coordinates.textColor =
        UIColor.whiteColor;

    [card addSubview:coordinates];

    _coordinateLabel =
        coordinates;


    UIButton *activate =
        [UIButton
            buttonWithType:UIButtonTypeSystem];

    activate.frame =
        CGRectMake(
            20,
            79,
            CGRectGetWidth(card.bounds)
                - 40,
            48
        );

    activate.autoresizingMask =
        UIViewAutoresizingFlexibleWidth;

    activate.backgroundColor =
        [UIColor
            colorWithRed:0.20
                   green:0.52
                    blue:1.0
                   alpha:1.0];

    activate.layer.cornerRadius =
        14.0;

    [activate
        setTitle:@"Activate Selected Location"
        forState:UIControlStateNormal];

    [activate
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    activate.titleLabel.font =
        [UIFont
            systemFontOfSize:15
                      weight:UIFontWeightSemibold];

    [activate
        addTarget:self
           action:@selector(activateSelectedLocation)
 forControlEvents:UIControlEventTouchUpInside];

    [card addSubview:activate];

    _activateButton =
        activate;


    UIButton *restore =
        [UIButton
            buttonWithType:UIButtonTypeSystem];

    restore.frame =
        CGRectMake(
            20,
            137,
            132,
            40
        );

    restore.backgroundColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.08];

    restore.layer.cornerRadius =
        12.0;

    [restore
        setTitle:@"Restore"
        forState:UIControlStateNormal];

    [restore
        setTitleColor:UIColor.whiteColor
        forState:UIControlStateNormal];

    [restore
        addTarget:self
           action:@selector(restoreLocation)
 forControlEvents:UIControlEventTouchUpInside];

    [card addSubview:restore];

    _restoreButton =
        restore;


    UILabel *status =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    164,
                    137,
                    CGRectGetWidth(card.bounds)
                        - 184,
                    40
                )];

    status.autoresizingMask =
        UIViewAutoresizingFlexibleWidth;

    status.textAlignment =
        NSTextAlignmentRight;

    status.font =
        [UIFont systemFontOfSize:12];

    status.textColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.55];

    [card addSubview:status];

    _statusLabel =
        status;


    [self refreshStatus];
}


#pragma mark - Activate Location

- (void)activateSelectedLocation {

    if (!_hasSelectedCoordinate) {

        [self
            showAlert:@"Select a location first."];

        return;
    }


    WFError *error =
        [[WFAppManager sharedManager]
            activateStaticLocationWithLatitude:
                _selectedCoordinate.latitude
            longitude:
                _selectedCoordinate.longitude];


    if ([error isSuccess]) {

        [self
            showAlert:
                @"Location saved in WolFox runtime ✅"];

    } else {

        [self
            showAlert:
                error.humanReadableMessage
                    ?: @"Unable to activate"];
    }


    [self refreshStatus];
}


- (void)restoreLocation {

    WFError *error =
        [[WFAppManager sharedManager]
            restoreDefaultLocation];


    if ([error isSuccess]) {

        [self
            showAlert:
                @"Default location restored ✅"];

    } else {

        [self
            showAlert:
                error.humanReadableMessage
                    ?: @"Unable to restore"];
    }


    [self refreshStatus];
}


#pragma mark - Status

- (void)refreshStatus {

    NSDictionary *snapshot =
        [[WFRuntimeState sharedState]
            snapshotForUI];

    BOOL active =
        [snapshot[@"locationEnabled"]
            boolValue];

    if (active) {

        double lat =
            [snapshot[@"currentLatitude"]
                doubleValue];

        double lon =
            [snapshot[@"currentLongitude"]
                doubleValue];

        _statusLabel.text =
            [NSString
                stringWithFormat:
                    @"ACTIVE %.4f, %.4f",
                    lat,
                    lon];

    } else {

        _statusLabel.text =
            @"DEFAULT";
    }
}


#pragma mark - Search

- (void)searchBarSearchButtonClicked:
    (UISearchBar *)searchBar {

    NSString *query =
        searchBar.text;

    if (query.length == 0) {
        return;
    }


    [searchBar
        resignFirstResponder];


    MKLocalSearchRequest *request =
        [[MKLocalSearchRequest alloc]
            init];

    request.naturalLanguageQuery =
        query;


    MKLocalSearch *search =
        [[MKLocalSearch alloc]
            initWithRequest:request];


    __weak WFUIController *weakSelf =
        self;


    [search
        startWithCompletionHandler:
            ^(
                MKLocalSearchResponse *response,
                NSError *error
            ) {

        WFUIController *strongSelf =
            weakSelf;

        if (strongSelf == nil) {
            return;
        }


        if (error != nil ||
            response.mapItems.count == 0) {

            [strongSelf
                showAlert:
                    @"Location not found"];

            return;
        }


        MKMapItem *item =
            response.mapItems.firstObject;

        CLLocationCoordinate2D coordinate =
            item.placemark.coordinate;


        dispatch_async(
            dispatch_get_main_queue(),
            ^{

            [strongSelf
                selectCoordinate:coordinate
                        animated:YES];
        });
    }];
}


#pragma mark - Map Controls

- (void)centerSelectedLocation {

    if (!_hasSelectedCoordinate) {
        return;
    }

    MKCoordinateRegion region =
        MKCoordinateRegionMakeWithDistance(
            _selectedCoordinate,
            1200,
            1200
        );

    [_mapView
        setRegion:region
         animated:YES];
}


- (void)changeMapType {

    switch (_mapView.mapType) {

        case MKMapTypeStandard:

            _mapView.mapType =
                MKMapTypeSatellite;

            break;


        case MKMapTypeSatellite:

            _mapView.mapType =
                MKMapTypeHybrid;

            break;


        default:

            _mapView.mapType =
                MKMapTypeStandard;

            break;
    }
}


#pragma mark - Side Menu

- (void)buildSideMenu {

    CGFloat height =
        CGRectGetHeight(
            _mainView.bounds
        );

    UIView *menu =
        [[UIView alloc]
            initWithFrame:
                CGRectMake(
                    -260,
                    0,
                    250,
                    height
                )];

    menu.autoresizingMask =
        UIViewAutoresizingFlexibleHeight;

    menu.backgroundColor =
        [UIColor
            colorWithRed:0.045
                   green:0.05
                    blue:0.065
                   alpha:0.99];

    menu.layer.shadowOpacity =
        0.35;

    menu.layer.shadowRadius =
        16.0;


    [_mainView addSubview:menu];

    _sideMenu =
        menu;


    UILabel *logo =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    24,
                    64,
                    190,
                    50
                )];

    logo.text =
        @"🦊  WolFox";

    logo.font =
        [UIFont
            boldSystemFontOfSize:24];

    logo.textColor =
        UIColor.whiteColor;

    [menu addSubview:logo];


    UILabel *version =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(
                    26,
                    110,
                    180,
                    22
                )];

    version.text =
        @"Standalone Runtime";

    version.font =
        [UIFont systemFontOfSize:12];

    version.textColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.45];

    [menu addSubview:version];


    UITableView *table =
        [[UITableView alloc]
            initWithFrame:
                CGRectMake(
                    0,
                    155,
                    250,
                    height - 155
                )
                   style:
                UITableViewStylePlain];

    table.autoresizingMask =
        UIViewAutoresizingFlexibleHeight;

    table.backgroundColor =
        UIColor.clearColor;

    table.separatorStyle =
        UITableViewCellSeparatorStyleNone;

    table.delegate =
        self;

    table.dataSource =
        self;

    [menu addSubview:table];

    _menuTable =
        table;
}


- (void)toggleSideMenu {

    _menuVisible =
        !_menuVisible;

    CGFloat targetX =
        _menuVisible
            ? 0
            : -260;


    [UIView
        animateWithDuration:0.22
                 animations:^{

        CGRect frame =
            self->_sideMenu.frame;

        frame.origin.x =
            targetX;

        self->_sideMenu.frame =
            frame;
    }];
}


#pragma mark - Menu Table

- (NSInteger)tableView:
    (UITableView *)tableView
 numberOfRowsInSection:
    (NSInteger)section {

    (void)tableView;
    (void)section;

    return 6;
}


- (UITableViewCell *)tableView:
    (UITableView *)tableView
 cellForRowAtIndexPath:
    (NSIndexPath *)indexPath {

    static NSString *identifier =
        @"WFMenuCell";


    UITableViewCell *cell =
        [tableView
            dequeueReusableCellWithIdentifier:
                identifier];


    if (cell == nil) {

        cell =
            [[UITableViewCell alloc]
                initWithStyle:
                    UITableViewCellStyleDefault
              reuseIdentifier:
                    identifier];

        cell.backgroundColor =
            UIColor.clearColor;

        cell.textLabel.textColor =
            UIColor.whiteColor;

        cell.textLabel.font =
            [UIFont
                systemFontOfSize:16
                          weight:UIFontWeightMedium];

        cell.selectionStyle =
            UITableViewCellSelectionStyleNone;
    }


    NSArray *titles =
        @[
            @"📍  Location",
            @"🛣  Route",
            @"📶  Wi-Fi",
            @"📱  Device",
            @"⏰  Scheduler",
            @"ℹ️  Status"
        ];


    cell.textLabel.text =
        titles[indexPath.row];


    return cell;
}


- (void)tableView:
    (UITableView *)tableView
 didSelectRowAtIndexPath:
    (NSIndexPath *)indexPath {

    (void)tableView;


    [self toggleSideMenu];


    switch (indexPath.row) {

        case 0:

            [self showLocationMode];

            break;


        case 1:

            [self
                showUnavailable:
                    @"Route"];

            break;


        case 2:

            [self
                showUnavailable:
                    @"Wi-Fi Profiles"];

            break;


        case 3:

            [self
                showUnavailable:
                    @"Device Profiles"];

            break;


        case 4:

            [self
                showUnavailable:
                    @"Scheduler"];

            break;


        case 5:

            [self showRuntimeStatus];

            break;
    }
}


#pragma mark - Modes

- (void)showLocationMode {

    _modeLabel.text =
        @"LOCATION";

    _bottomCard.hidden =
        NO;
}


- (void)showUnavailable:
    (NSString *)feature {

    NSString *message =
        [NSString
            stringWithFormat:
                @"%@ is not implemented in the current WolFox Core yet.",
                feature];

    [self showAlert:message];
}


- (void)showRuntimeStatus {

    NSDictionary *snapshot =
        [[WFRuntimeState sharedState]
            snapshotForUI];

    NSString *message =
        [NSString
            stringWithFormat:
                @"Location: %@\nMode: %@\nLast action: %@",
                [snapshot[@"locationEnabled"]
                    boolValue]
                    ? @"Active"
                    : @"Default",
                snapshot[@"locationMode"]
                    ?: @"",
                snapshot[@"lastAction"]
                    ?: @""];

    [self showAlert:message];
}


#pragma mark - Alert

- (void)showAlert:
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

- (void)closeMainInterface {

    [_searchBar
        resignFirstResponder];


    [_mainView
        removeFromSuperview];


    _mainView =
        nil;

    _sideMenu =
        nil;

    _bottomCard =
        nil;

    _mapView =
        nil;

    _searchBar =
        nil;

    _coordinateLabel =
        nil;

    _statusLabel =
        nil;

    _modeLabel =
        nil;

    _menuTable =
        nil;

    _menuVisible =
        NO;


    _floatingButton.hidden =
        NO;
}

@end