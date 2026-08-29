#pragma mark - Runtime Hooks (CLLocationManager)

static CLLocation *(*orig_location)(id, SEL) = NULL;
static id (*orig_delegate)(id, SEL) = NULL;
static void (*orig_setDelegate)(id, SEL, id) = NULL;
static void (*orig_startUpdatingLocation)(id, SEL) = NULL;
static void (*orig_stopUpdatingLocation)(id, SEL) = NULL;
static void (*orig_requestLocation)(id, SEL) = NULL;


static CLLocation *WolFox_buildFakeLocation(
    WFRuntimeState *state
) {

    CLLocationCoordinate2D coordinate =
        CLLocationCoordinate2DMake(
            state.currentLatitude,
            state.currentLongitude
        );

    CLLocationDirection course =
        -1.0;

    CLLocationSpeed speed =
        0.0;

    if (state.movementActive) {

        course =
            state.movementCourse;

        speed =
            state.movementSpeed;
    }

    return
        [[CLLocation alloc]
            initWithCoordinate:coordinate
            altitude:0.0
            horizontalAccuracy:5.0
            verticalAccuracy:5.0
            course:course
            speed:speed
            timestamp:[NSDate date]];
}


#pragma mark - Delegate Proxy

@interface WolFoxDelegateProxy : NSObject
@property (nonatomic, weak) id originalDelegate;
@end


@implementation WolFoxDelegateProxy


- (BOOL)isKindOfClass:(Class)aClass {

    if (
        self.originalDelegate != nil &&
        [self.originalDelegate
            isKindOfClass:aClass]
    ) {

        return YES;
    }

    return
        [super
            isKindOfClass:aClass];
}


- (BOOL)respondsToSelector:(SEL)selector {

    if (
        self.originalDelegate != nil &&
        [self.originalDelegate
            respondsToSelector:selector]
    ) {

        return YES;
    }

    return
        [super
            respondsToSelector:selector];
}


- (BOOL)conformsToProtocol:(Protocol *)protocol {

    if (
        self.originalDelegate != nil &&
        [self.originalDelegate
            conformsToProtocol:protocol]
    ) {

        return YES;
    }

    return
        [super
            conformsToProtocol:protocol];
}


- (id)forwardingTargetForSelector:(SEL)selector {

    if (self.originalDelegate != nil) {
        return self.originalDelegate;
    }

    return
        [super
            forwardingTargetForSelector:selector];
}


- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {

    if (self.originalDelegate != nil) {

        NSMethodSignature *signature =
            [self.originalDelegate
                methodSignatureForSelector:selector];

        if (signature != nil) {
            return signature;
        }
    }

    return
        [super
            methodSignatureForSelector:selector];
}


- (void)forwardInvocation:(NSInvocation *)invocation {

    if (self.originalDelegate != nil) {

        [invocation
            invokeWithTarget:
                self.originalDelegate];

        return;
    }

    [super
        forwardInvocation:invocation];
}


- (void)locationManager:
    (CLLocationManager *)manager
    didUpdateLocations:
    (NSArray<CLLocation *> *)locations {

    WFRuntimeState *state =
        [WFRuntimeState sharedState];

    if (state.locationEnabled) {

        CLLocation *fake =
            WolFox_buildFakeLocation(state);

        if (self.originalDelegate != nil) {

            [self.originalDelegate
                locationManager:manager
                didUpdateLocations:
                    @[ fake ]];
        }

        return;
    }

    if (self.originalDelegate != nil) {

        [self.originalDelegate
            locationManager:manager
            didUpdateLocations:locations];
    }
}


- (void)locationManager:
    (CLLocationManager *)manager
    didFailWithError:
    (NSError *)error {

    WFRuntimeState *state =
        [WFRuntimeState sharedState];

    if (state.locationEnabled) {
        return;
    }

    if (self.originalDelegate != nil) {

        [self.originalDelegate
            locationManager:manager
            didFailWithError:error];
    }
}

@end


#pragma mark - Proxy Attach / Detach


static void WolFox_attachProxy(
    id manager
) {

    if (manager == nil) {
        return;
    }

    @try {

        id currentDelegate =
            [manager delegate];

        if (currentDelegate == nil) {
            return;
        }

        if (
            [currentDelegate
                isKindOfClass:
                    [WolFoxDelegateProxy class]]
        ) {

            return;
        }

        WolFoxDelegateProxy *proxy =
            [[WolFoxDelegateProxy alloc]
                init];

        proxy.originalDelegate =
            currentDelegate;

        if (orig_setDelegate != NULL) {

            orig_setDelegate(
                manager,
                @selector(setDelegate:),
                proxy
            );
        }

        [[WFLogger sharedLogger]
            logCategory:WFLogLocation
            message:
                @"Delegate proxy attached"];
    }
    @catch (NSException *exception) {

        [[WFLogger sharedLogger]
            logCategory:WFLogLocation
            message:
                [NSString
                    stringWithFormat:
                        @"Proxy attach failed: %@",
                        exception]];
    }
}


static void WolFox_detachProxy(
    id manager
) {

    if (manager == nil) {
        return;
    }

    @try {

        id currentDelegate =
            [manager delegate];

        if (
            currentDelegate != nil &&
            [currentDelegate
                isKindOfClass:
                    [WolFoxDelegateProxy class]]
        ) {

            WolFoxDelegateProxy *proxy =
                (WolFoxDelegateProxy *)
                currentDelegate;

            if (orig_setDelegate != NULL) {

                orig_setDelegate(
                    manager,
                    @selector(setDelegate:),
                    proxy.originalDelegate
                );
            }

            [[WFLogger sharedLogger]
                logCategory:WFLogLocation
                message:
                    @"Delegate proxy detached"];
        }
    }
    @catch (NSException *exception) {

        [[WFLogger sharedLogger]
            logCategory:WFLogLocation
            message:
                [NSString
                    stringWithFormat:
                        @"Proxy detach failed: %@",
                        exception]];
    }
}


#pragma mark - Hooked Methods


static CLLocation *WolFox_hooked_location(
    id self,
    SEL _cmd
) {

    @autoreleasepool {

        WFRuntimeState *state =
            [WFRuntimeState sharedState];

        if (state.locationEnabled) {

            return
                WolFox_buildFakeLocation(state);
        }

        if (orig_location != NULL) {

            return
                orig_location(
                    self,
                    _cmd
                );
        }

        return nil;
    }
}


static id WolFox_hooked_delegate(
    id self,
    SEL _cmd
) {

    id real =
        nil;

    if (orig_delegate != NULL) {

        real =
            orig_delegate(
                self,
                _cmd
            );
    }

    if (
        real != nil &&
        [real
            isKindOfClass:
                [WolFoxDelegateProxy class]]
    ) {

        return
            ((WolFoxDelegateProxy *)
                real).originalDelegate;
    }

    return real;
}


static void WolFox_hooked_setDelegate(
    id self,
    SEL _cmd,
    id delegate
) {

    if (delegate == nil) {

        WolFox_detachProxy(self);

        if (orig_setDelegate != NULL) {

            orig_setDelegate(
                self,
                _cmd,
                nil
            );
        }

        return;
    }

    if (
        [delegate
            isKindOfClass:
                [WolFoxDelegateProxy class]]
    ) {

        if (orig_setDelegate != NULL) {

            orig_setDelegate(
                self,
                _cmd,
                delegate
            );
        }

        return;
    }

    if (orig_setDelegate != NULL) {

        orig_setDelegate(
            self,
            _cmd,
            delegate
        );
    }

    WolFox_attachProxy(self);
}


static void WolFox_hooked_startUpdatingLocation(
    id self,
    SEL _cmd
) {

    @autoreleasepool {

        WFRuntimeState *state =
            [WFRuntimeState sharedState];

        if (state.locationEnabled) {

            [[WFLogger sharedLogger]
                logCategory:WFLogLocation
                message:
                    @"startUpdatingLocation intercepted"];

            WolFox_attachProxy(self);

            id delegate =
                [self delegate];

            if (
                delegate != nil &&
                [delegate
                    respondsToSelector:
                        @selector(
                            locationManager:
                            didUpdateLocations:
                        )]
            ) {

                CLLocation *fake =
                    WolFox_buildFakeLocation(state);

                [delegate
                    locationManager:
                        (CLLocationManager *)
                        self
                    didUpdateLocations:
                        @[ fake ]];
            }

            return;
        }

        if (orig_startUpdatingLocation != NULL) {

            orig_startUpdatingLocation(
                self,
                _cmd
            );
        }
    }
}


static void WolFox_hooked_stopUpdatingLocation(
    id self,
    SEL _cmd
) {

    if (orig_stopUpdatingLocation != NULL) {

        orig_stopUpdatingLocation(
            self,
            _cmd
        );
    }
}


static void WolFox_hooked_requestLocation(
    id self,
    SEL _cmd
) {

    @autoreleasepool {

        WFRuntimeState *state =
            [WFRuntimeState sharedState];

        if (state.locationEnabled) {

            [[WFLogger sharedLogger]
                logCategory:WFLogLocation
                message:
                    @"requestLocation intercepted"];

            WolFox_attachProxy(self);

            dispatch_async(
                dispatch_get_main_queue(),
                ^{

                id delegate =
                    [(id)self delegate];

                if (
                    delegate != nil &&
                    [delegate
                        respondsToSelector:
                            @selector(
                                locationManager:
                                didUpdateLocations:
                            )]
                ) {

                    CLLocation *fake =
                        WolFox_buildFakeLocation(
                            [WFRuntimeState
                                sharedState]
                        );

                    [delegate
                        locationManager:
                            (CLLocationManager *)
                            self
                        didUpdateLocations:
                            @[ fake ]];
                }
            });

            return;
        }

        if (orig_requestLocation != NULL) {

            orig_requestLocation(
                self,
                _cmd
            );
        }
    }
}


#pragma mark - Hook Installer


static void WolFox_installHook(
    Class cls,
    SEL selector,
    IMP newImplementation,
    IMP *originalStorage,
    NSString *name
) {

    Method method =
        class_getInstanceMethod(
            cls,
            selector
        );

    if (method == NULL) {

        [[WFLogger sharedLogger]
            logCategory:WFLogLocation
            message:
                [NSString
                    stringWithFormat:
                       :@"%@ not found — skipped",
                        name]];

        return;
    }

    IMP previous =
        method_setImplementation(
            method,
            newImplementation
        );

    if (originalStorage != NULL) {
        *originalStorage = previous;
    }

    [[WFLogger sharedLogger]
        logCategory:WFLogLocation
        message:
            [NSString
                stringWithFormat:
                    @"%@ hook installed",
                    name]];
}


static void WolFoxInstallRuntimeHooks(void) {

    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{

        Class managerClass =
            objc_getClass(
                "CLLocationManager"
            );

        if (managerClass == Nil) {

            [[WFLogger sharedLogger]
                logCategory:WFLogLocation
                message:
                    @"CLLocationManager class not found"];

            return;
        }

        WolFox_installHook(
            managerClass,
            @selector(location),
            (IMP)WolFox_hooked_location,
            (IMP *)&orig_location,
            @"location"
        );

        WolFox_installHook(
            managerClass,
            @selector(delegate),
            (IMP)WolFox_hooked_delegate,
            (IMP *)&orig_delegate,
            @"delegate"
        );

        WolFox_installHook(
            managerClass,
            @selector(setDelegate:),
            (IMP)WolFox_hooked_setDelegate,
            (IMP *)&orig_setDelegate,
            @"setDelegate:"
        );

        WolFox_installHook(
            managerClass,
            @selector(startUpdatingLocation),
            (IMP)WolFox_hooked_startUpdatingLocation,
            (IMP *)&orig_startUpdatingLocation,
            @"startUpdatingLocation"
        );

        WolFox_installHook(
            managerClass,
            @selector(stopUpdatingLocation),
            (IMP)WolFox_hooked_stopUpdatingLocation,
            (IMP *)&orig_stopUpdatingLocation,
            @"stopUpdatingLocation"
        );

        WolFox_installHook(
            managerClass,
            @selector(requestLocation),
            (IMP)WolFox_hooked_requestLocation,
            (IMP *)&orig_requestLocation,
            @"requestLocation"
        );

        [[WFLogger sharedLogger]
            logCategory:WFLogLocation
            message:
                @"All runtime hooks installed"];
    });
}
