#import "WolFox.h"
#import "Portable.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>


#pragma mark - Constants

static NSString * const kSchemaLocation = @"wolfox.location/1";

NSString * const WFEventLocationChanged =
    @"wolfox.location.changed";

NSString * const WFEventRuntimeStateChanged =
    @"wolfox.runtime.changed";

NSString * const WFEventRouteProgressChanged =
    @"wolfox.route.progress.changed";

NSString * const WFEventErrorOccurred =
    @"wolfox.error.occurred";


#pragma mark - WFLogger

@implementation WFLogger {
    dispatch_queue_t _logQueue;
    NSMutableArray<NSString *> *_buffer;
}

+ (instancetype)sharedLogger {

    static WFLogger *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[WFLogger alloc] init];
    });

    return instance;
}

- (instancetype)init {

    if ((self = [super init])) {

        _logQueue = dispatch_queue_create(
            "com.wolfox.logger",
            DISPATCH_QUEUE_SERIAL
        );

        _buffer = [NSMutableArray array];
    }

    return self;
}

- (void)logCategory:(WFLogCategory)category
            message:(NSString *)message {

    NSString *line =
        [NSString stringWithFormat:@"%@ [%@] %@",
            [NSDate date],
            [self categoryName:category],
            message ?: @""];

    dispatch_async(_logQueue, ^{

        [self->_buffer addObject:line];

        if (self->_buffer.count > 500) {
            [self->_buffer removeObjectAtIndex:0];
        }

        NSLog(@"WolFox %@", line);
    });
}

- (NSString *)categoryName:(WFLogCategory)category {

    switch (category) {

        case WFLogCore:
            return @"CORE";

        case WFLogLocation:
            return @"LOC";

        case WFLogMovement:
            return @"MOVE";

        case WFLogRandom:
            return @"RANDOM";

        case WFLogRoute:
            return @"ROUTE";

        case WFLogWiFi:
            return @"WIFI";

        case WFLogDevice:
            return @"DEVICE";

        case WFLogScheduler:
            return @"SCHED";

        case WFLogStorage:
            return @"STORE";

        case WFLogUI:
            return @"UI";
    }

    return @"UNKNOWN";
}

@end


#pragma mark - WFEventBus

@implementation WFEventBus {
    dispatch_queue_t _busQueue;

    NSMutableDictionary<
        NSString *,
        NSMapTable<id, id> *
    > *_handlers;
}

+ (instancetype)sharedBus {

    static WFEventBus *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[WFEventBus alloc] init];
    });

    return instance;
}

- (instancetype)init {

    if ((self = [super init])) {

        _busQueue = dispatch_queue_create(
            "com.wolfox.eventbus",
            DISPATCH_QUEUE_SERIAL
        );

        _handlers = [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)subscribe:(NSString *)eventName
         observer:(id)observer
            block:(void (^)(NSDictionary *payload))block {

    if (eventName.length == 0 ||
        observer == nil ||
        block == nil) {

        return;
    }

    dispatch_sync(_busQueue, ^{

        NSMapTable *table =
            self->_handlers[eventName];

        if (!table) {

            table =
                [NSMapTable weakToStrongObjectsMapTable];

            self->_handlers[eventName] = table;
        }

        [table setObject:[block copy]
                  forKey:observer];
    });
}

- (void)unsubscribe:(id)observer {

    if (!observer) {
        return;
    }

    dispatch_sync(_busQueue, ^{

        for (NSString *eventName
             in self->_handlers.allKeys) {

            NSMapTable *table =
                self->_handlers[eventName];

            [table removeObjectForKey:observer];
        }
    });
}

- (void)publish:(NSString *)eventName
        payload:(NSDictionary *)payload {

    if (eventName.length == 0) {
        return;
    }

    __block NSArray *blocks = nil;

    dispatch_sync(_busQueue, ^{

        NSMapTable *table =
            self->_handlers[eventName];

        if (!table) {

            blocks = @[];
            return;
        }

        NSMutableArray *snapshot =
            [NSMutableArray array];

        for (id blockObject
             in table.objectEnumerator) {

            if (blockObject) {
                [snapshot addObject:blockObject];
            }
        }

        blocks = [snapshot copy];
    });

    NSDictionary *safePayload =
        payload ?: @{};

    for (id blockObject in blocks) {

        void (^block)(NSDictionary *) =
            blockObject;

        block(safePayload);
    }
}

@end


#pragma mark - WFRuntimeState

@interface WFRuntimeState ()
<WFRuntimeStateMutable>

@property (nonatomic, assign, readwrite)
BOOL locationEnabled;

@property (nonatomic, assign, readwrite)
double currentLatitude;

@property (nonatomic, assign, readwrite)
double currentLongitude;

@property (nonatomic, assign, readwrite)
WFLocationMode locationMode;

@property (nonatomic, assign, readwrite)
BOOL movementActive;

@property (nonatomic, assign, readwrite)
BOOL movementPaused;

@property (nonatomic, assign, readwrite)
double movementSpeed;

@property (nonatomic, assign, readwrite)
double movementCourse;

@property (nonatomic, assign, readwrite)
BOOL randomMovementActive;

@property (nonatomic, assign, readwrite)
double randomRadius;

@property (nonatomic, assign, readwrite)
BOOL routeActive;

@property (nonatomic, assign, readwrite)
BOOL routePaused;

@property (nonatomic, assign, readwrite)
double routeProgress;

@property (nonatomic, assign, readwrite)
double routeDistanceRemaining;

@property (nonatomic, assign, readwrite)
double routeSpeed;

@property (nonatomic, copy, readwrite)
NSString *activeWiFiProfileID;

@property (nonatomic, copy, readwrite)
NSString *activeDeviceProfileID;

@property (nonatomic, assign, readwrite)
BOOL schedulerActive;

@property (nonatomic, copy, readwrite)
NSString *lastAction;

@property (nonatomic, copy, readwrite)
NSString *lastError;

@end


@implementation WFRuntimeState {
    dispatch_queue_t _stateQueue;
}

+ (instancetype)sharedState {

    static WFRuntimeState *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[WFRuntimeState alloc] init];
    });

    return instance;
}

- (instancetype)init {

    if ((self = [super init])) {

        _stateQueue =
            dispatch_queue_create(
                "com.wolfox.state",
                DISPATCH_QUEUE_SERIAL
            );

        _locationMode =
            WFLocationModeDefault;

        _lastAction =
            @"Initialized";

        _lastError =
            @"";
    }

    return self;
}

- (void)performUpdate:
    (void (^)(id<WFRuntimeStateMutable>))updateBlock {

    if (!updateBlock) {
        return;
    }

    dispatch_sync(_stateQueue, ^{

        updateBlock(self);
    });

    NSDictionary *snapshot =
        [self snapshotForUI];

    [[WFEventBus sharedBus]
        publish:WFEventRuntimeStateChanged
        payload:snapshot];
}

- (NSDictionary *)snapshotForUI {

    @synchronized (self) {

        return @{

            @"locationEnabled":
                @(self.locationEnabled),

            @"lat":
                @(self.currentLatitude),

            @"lon":
                @(self.currentLongitude),

            @"mode":
                @(self.locationMode),

            @"movementActive":
                @(self.movementActive),

            @"movementPaused":
                @(self.movementPaused),

            @"movementSpeed":
                @(self.movementSpeed),

            @"movementCourse":
                @(self.movementCourse),

            @"randomActive":
                @(self.randomMovementActive),

            @"randomRadius":
                @(self.randomRadius),

            @"routeActive":
                @(self.routeActive),

            @"routePaused":
                @(self.routePaused),

            @"routeProgress":
                @(self.routeProgress),

            @"routeDistanceRemaining":
                @(self.routeDistanceRemaining),

            @"routeSpeed":
                @(self.routeSpeed),

            @"activeWiFiProfileID":
                self.activeWiFiProfileID ?: @"",

            @"activeDeviceProfileID":
                self.activeDeviceProfileID ?: @"",

            @"schedulerActive":
                @(self.schedulerActive),

            @"lastAction":
                self.lastAction ?: @"",

            @"lastError":
                self.lastError ?: @""
        };
    }
}

- (void)resetToDefaultEnvironment {

    [self performUpdate:
        ^(id<WFRuntimeStateMutable> state) {

        state.locationEnabled = NO;

        state.currentLatitude = 0.0;
        state.currentLongitude = 0.0;

        state.locationMode =
            WFLocationModeDefault;

        state.movementActive = NO;
        state.movementPaused = NO;
        state.movementSpeed = 0.0;
        state.movementCourse = 0.0;

        state.randomMovementActive = NO;
        state.randomRadius = 0.0;

        state.routeActive = NO;
        state.routePaused = NO;
        state.routeProgress = 0.0;
        state.routeDistanceRemaining = 0.0;
        state.routeSpeed = 0.0;

        state.activeWiFiProfileID = nil;
        state.activeDeviceProfileID = nil;

        state.schedulerActive = NO;

        state.lastAction =
            @"Environment reset";

        state.lastError =
            @"";
    }];
}

@end


#pragma mark - WFError

@interface WFError ()

@property (nonatomic, readwrite)
WFErrorCode errorCode;

@property (nonatomic, readwrite, copy)
NSString *humanReadableMessage;

@property (nonatomic, readwrite, copy)
NSString *technicalMessage;

@end


@implementation WFError

+ (instancetype)success {

    WFError *error =
        [[WFError alloc] init];

    error.errorCode =
        WFErrorCodeSuccess;

    error.humanReadableMessage =
        @"";

    error.technicalMessage =
        @"";

    return error;
}

+ (instancetype)errorWithCode:
    (WFErrorCode)code
                    technical:
    (NSString *)technicalMessage {

    WFError *error =
        [[WFError alloc] init];

    error.errorCode =
        code;

    error.humanReadableMessage =
        [self userMessageForCode:code];

    error.technicalMessage =
        technicalMessage ?: @"";

    return error;
}

+ (NSString *)userMessageForCode:
    (WFErrorCode)code {

    switch (code) {

        case WFErrorCodeSuccess:
            return @"";

        case WFErrorCodeInvalidInput:
            return @"Invalid input.";

        case WFErrorCodeNotAvailable:
            return @"Feature not available yet.";

        case WFErrorCodeNetworkError:
            return @"Network error.";

        case WFErrorCodeConflict:
            return @"Another mode is active. Stop it first.";

        case WFErrorCodeStorageError:
            return @"Storage error.";

        case WFErrorCodeUnsupportedVersion:
            return @"Unsupported version.";

        case WFErrorCodeRouteError:
            return @"Route error.";
    }

    return @"Unknown error.";
}

- (BOOL)isSuccess {

    return self.errorCode ==
        WFErrorCodeSuccess;
}

@end


#pragma mark - WFSettingsStore

@implementation WFSettingsStore

+ (instancetype)sharedStore {

    static WFSettingsStore *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance =
            [[WFSettingsStore alloc] init];
    });

    return instance;
}

- (NSUserDefaults *)defaults {

    return
        [NSUserDefaults standardUserDefaults];
}

- (void)setObjectForKey:(NSString *)key
                  value:(id)value {

    if (key.length == 0) {
        return;
    }

    if (value) {

        [self.defaults
            setObject:value
               forKey:key];

    } else {

        [self.defaults
            removeObjectForKey:key];
    }
}

- (id)objectForKey:(NSString *)key {

    if (key.length == 0) {
        return nil;
    }

    return
        [self.defaults objectForKey:key];
}

- (void)setStringForKey:(NSString *)key
                  value:(NSString *)value {

    [self setObjectForKey:key
                    value:value];
}

- (NSString *)stringForKey:(NSString *)key {

    id value =
        [self objectForKey:key];

    return
        [value isKindOfClass:
            [NSString class]]
        ? value
        : nil;
}

- (void)setDoubleForKey:(NSString *)key
                  value:(double)value {

    if (key.length == 0) {
        return;
    }

    [self.defaults
        setDouble:value
           forKey:key];
}

- (double)doubleForKey:(NSString *)key {

    if (key.length == 0) {
        return 0.0;
    }

    return
        [self.defaults doubleForKey:key];
}

- (void)setBoolForKey:(NSString *)key
                 value:(BOOL)value {

    if (key.length == 0) {
        return;
    }

    [self.defaults
        setBool:value
          forKey:key];
}

- (BOOL)boolForKey:(NSString *)key {

    if (key.length == 0) {
        return NO;
    }

    return
        [self.defaults boolForKey:key];
}

- (void)setArrayForKey:(NSString *)key
                 value:(NSArray *)value {

    [self setObjectForKey:key
                    value:value];
}

- (NSArray *)arrayForKey:(NSString *)key {

    id value =
        [self objectForKey:key];

    return
        [value isKindOfClass:
            [NSArray class]]
        ? value
        : nil;
}

- (void)setDictionaryForKey:
    (NSString *)key
                      value:
    (NSDictionary *)value {

    [self setObjectForKey:key
                    value:value];
}

- (NSDictionary *)dictionaryForKey:
    (NSString *)key {

    id value =
        [self objectForKey:key];

    return
        [value isKindOfClass:
            [NSDictionary class]]
        ? value
        : nil;
}

- (void)removeKey:(NSString *)key {

    if (key.length == 0) {
        return;
    }

    [self.defaults
        removeObjectForKey:key];
}

@end


#pragma mark - WFLocationModel

@implementation WFLocationModel {
    NSString *_locationID;
    NSString *_name;
    double _latitude;
    double _longitude;
    NSDate *_createdAt;
}

@synthesize locationID =
    _locationID;

@synthesize name =
    _name;

@synthesize latitude =
    _latitude;

@synthesize longitude =
    _longitude;

@synthesize createdAt =
    _createdAt;

+ (instancetype)locationWithName:
    (NSString *)name
                        latitude:
    (double)latitude
                       longitude:
    (double)longitude {

    WFLocationModel *location =
        [[WFLocationModel alloc] init];

    location->_locationID =
        [[NSUUID UUID] UUIDString];

    location->_name =
        [name copy] ?: @"Unnamed";

    location->_latitude =
        latitude;

    location->_longitude =
        longitude;

    location->_createdAt =
        [NSDate date];

    return location;
}

- (BOOL)coordinateIsValid {

    return
        _latitude >= -90.0 &&
        _latitude <= 90.0 &&
        _longitude >= -180.0 &&
        _longitude <= 180.0;
}

- (NSDictionary *)toDictionary {

    return @{

        @"schema":
            kSchemaLocation,

        @"id":
            _locationID ?: @"",

        @"name":
            _name ?: @"",

        @"lat":
            @(_latitude),

        @"lon":
            @(_longitude),

        @"createdAt":
            @([_createdAt
                timeIntervalSince1970])
    };
}

+ (instancetype)fromDictionary:
    (NSDictionary *)dict {

    if (![dict isKindOfClass:
          [NSDictionary class]]) {

        return nil;
    }

    if (![dict[@"schema"]
          isEqualToString:
            kSchemaLocation]) {

        return nil;
    }

    NSNumber *lat =
        dict[@"lat"];

    NSNumber *lon =
        dict[@"lon"];

    if (![lat isKindOfClass:
          [NSNumber class]] ||
        ![lon isKindOfClass:
          [NSNumber class]]) {

        return nil;
    }

    double latitude =
        lat.doubleValue;

    double longitude =
        lon.doubleValue;

    if (latitude < -90.0 ||
        latitude > 90.0 ||
        longitude < -180.0 ||
        longitude > 180.0) {

        return nil;
    }

    WFLocationModel *location =
        [[WFLocationModel alloc] init];

    location->_locationID =
        [dict[@"id"]
            isKindOfClass:
                [NSString class]]
        ? [dict[@"id"] copy]
        : [[NSUUID UUID] UUIDString];

    location->_name =
        [dict[@"name"]
            isKindOfClass:
                [NSString class]]
        ? [dict[@"name"] copy]
        : @"Unnamed";

    location->_latitude =
        latitude;

    location->_longitude =
        longitude;

    location->_createdAt =
        [dict[@"createdAt"]
            isKindOfClass:
                [NSNumber class]]
        ? [NSDate
            dateWithTimeIntervalSince1970:
                [dict[@"createdAt"]
                    doubleValue]]
        : [NSDate date];

    return location;
}

@end


#pragma mark - WFLocationService

static NSString * const
kFavoritesKey =
    @"wolfox.favorites.v1";

static NSString * const
kLastLatKey =
    @"wolfox.lastLatitude";

static NSString * const
kLastLonKey =
    @"wolfox.lastLongitude";


@implementation WFLocationService

+ (instancetype)sharedService {

    static WFLocationService *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance =
            [[WFLocationService alloc] init];
    });

    return instance;
}

- (WFError *)setLocationWithLatitude:
    (double)latitude
                           longitude:
    (double)longitude {

    if (latitude < -90.0 ||
        latitude > 90.0 ||
        longitude < -180.0 ||
        longitude > 180.0) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeInvalidInput
                technical:
                    @"Coordinate out of range"];
    }

    [[WFRuntimeState sharedState]
        performUpdate:
            ^(id<WFRuntimeStateMutable> state) {

        state.locationEnabled =
            YES;

        state.currentLatitude =
            latitude;

        state.currentLongitude =
            longitude;

        state.locationMode =
            WFLocationModeStatic;

        state.lastAction =
            @"Static location activated";

        state.lastError =
            @"";
    }];

    [[WFSettingsStore sharedStore]
        setDoubleForKey:kLastLatKey
                  value:latitude];

    [[WFSettingsStore sharedStore]
        setDoubleForKey:kLastLonKey
                  value:longitude];

    [[WFEventBus sharedBus]
        publish:WFEventLocationChanged
        payload:@{
            @"lat": @(latitude),
            @"lon": @(longitude)
        }];

    return [WFError success];
}

- (BOOL)isLocationActive {

    return
        [WFRuntimeState sharedState]
            .locationEnabled;
}

- (NSDictionary *)currentLocation {

    WFRuntimeState *state =
        [WFRuntimeState sharedState];

    if (!state.locationEnabled) {
        return nil;
    }

    return @{
        @"lat":
            @(state.currentLatitude),

        @"lon":
            @(state.currentLongitude)
    };
}

- (WFError *)clearLocation {

    return [self restoreDefault];
}

- (WFError *)restoreDefault {

    [[WFRuntimeState sharedState]
        performUpdate:
            ^(id<WFRuntimeStateMutable> state) {

        state.locationEnabled =
            NO;

        state.locationMode =
            WFLocationModeDefault;

        state.lastAction =
            @"Location restored to default";

        state.lastError =
            @"";
    }];

    [[WFEventBus sharedBus]
        publish:WFEventLocationChanged
        payload:@{}];

    return [WFError success];
}

- (NSArray<WFLocationModel *> *)favorites {

    NSArray *raw =
        [[WFSettingsStore sharedStore]
            arrayForKey:kFavoritesKey];

    NSMutableArray *result =
        [NSMutableArray array];

    for (id object in raw ?: @[]) {

        if (![object
              isKindOfClass:
                [NSDictionary class]]) {

            continue;
        }

        WFLocationModel *location =
            [WFLocationModel
                fromDictionary:object];

        if (location) {
            [result addObject:location];
        }
    }

    return result;
}

- (WFError *)addFavoriteWithName:
    (NSString *)name
                        latitude:
    (double)latitude
                       longitude:
    (double)longitude {

    if (name.length == 0) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeInvalidInput
                technical:
                    @"Empty favorite name"];
    }

    WFLocationModel *location =
        [WFLocationModel
            locationWithName:name
                    latitude:latitude
                   longitude:longitude];

    if (![location coordinateIsValid]) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeInvalidInput
                technical:
                    @"Favorite coordinate invalid"];
    }

    NSMutableArray *favorites =
        [[self favorites] mutableCopy];

    [favorites addObject:location];

    [self persistFavorites:favorites];

    return [WFError success];
}

- (WFError *)renameFavoriteWithID:
    (NSString *)locationID
                          newName:
    (NSString *)newName {

    if (locationID.length == 0 ||
        newName.length == 0) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeInvalidInput
                technical:
                    @"Invalid favorite ID or name"];
    }

    NSMutableArray *favorites =
        [[self favorites] mutableCopy];

    NSUInteger index =
        [favorites
            indexOfObjectPassingTest:
                ^BOOL(
                    WFLocationModel *location,
                    NSUInteger idx,
                    BOOL *stop) {

        return
            [location.locationID
                isEqualToString:
                    locationID];
    }];

    if (index == NSNotFound) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeNotAvailable
                technical:
                    @"Favorite not found"];
    }

    WFLocationModel *old =
        favorites[index];

    WFLocationModel *replacement =
        [WFLocationModel
            locationWithName:newName
                    latitude:old.latitude
                   longitude:old.longitude];

    [favorites
        replaceObjectAtIndex:index
                  withObject:replacement];

    [self persistFavorites:favorites];

    return [WFError success];
}

- (WFError *)deleteFavoriteWithID:
    (NSString *)locationID {

    if (locationID.length == 0) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeInvalidInput
                technical:
                    @"Empty favorite ID"];
    }

    NSMutableArray *favorites =
        [[self favorites] mutableCopy];

    NSUInteger before =
        favorites.count;

    NSIndexSet *indexes =
        [favorites
            indexesOfObjectsPassingTest:
                ^BOOL(
                    WFLocationModel *location,
                    NSUInteger idx,
                    BOOL *stop) {

        return
            [location.locationID
                isEqualToString:
                    locationID];
    }];

    [favorites
        removeObjectsAtIndexes:indexes];

    if (favorites.count == before) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeNotAvailable
                technical:
                    @"Favorite not found"];
    }

    [self persistFavorites:favorites];

    return [WFError success];
}

- (WFError *)activateFavoriteWithID:
    (NSString *)locationID {

    for (WFLocationModel *location
         in [self favorites]) {

        if ([location.locationID
             isEqualToString:
                locationID]) {

            return
                [self
                    setLocationWithLatitude:
                        location.latitude
                    longitude:
                        location.longitude];
        }
    }

    return
        [WFError
            errorWithCode:
                WFErrorCodeNotAvailable
            technical:
                @"Favorite not found"];
}

- (void)persistFavorites:
    (NSArray *)favorites {

    NSMutableArray *serialized =
        [NSMutableArray array];

    for (WFLocationModel *location
         in favorites) {

        [serialized
            addObject:
                [location toDictionary]];
    }

    [[WFSettingsStore sharedStore]
        setArrayForKey:kFavoritesKey
                 value:serialized];
}

@end


#pragma mark - WFMovementEngine

@interface WFMovementEngine ()

@property (nonatomic, assign, readwrite)
WFMovementEngineState state;

@property (nonatomic, assign, readwrite)
double currentLatitude;

@property (nonatomic, assign, readwrite)
double currentLongitude;

@property (nonatomic, assign, readwrite)
double courseDegrees;

@property (nonatomic, assign, readwrite)
double distanceRemainingMeters;

@property (nonatomic, assign, readwrite)
double progress;

@end


@implementation WFMovementEngine {
    dispatch_queue_t _engineQueue;
    dispatch_source_t _timer;

    wolfox::Coordinate _start;
    wolfox::Coordinate _destination;

    double _speedMps;
    double _totalDistanceMeters;

    NSTimeInterval _updateIntervalSeconds;

    NSDate *_anchorDate;
    double _progressAtAnchor;

    void (^_onTick)(
        double,
        double,
        double,
        double,
        double
    );

    void (^_onComplete)(void);
}

- (instancetype)init {

    if ((self = [super init])) {

        _engineQueue =
            dispatch_queue_create(
                "com.wolfox.movement",
                DISPATCH_QUEUE_SERIAL
            );

        _state =
            WFMovementEngineStateStopped;

        _progress =
            0.0;
    }

    return self;
}

- (WFError *)startFromLatitude:
    (double)fromLat
                     longitude:
    (double)fromLon
                    toLatitude:
    (double)toLat
                    longitude2:
    (double)toLon
                         speed:
    (double)metersPerSecond
                updateInterval:
    (NSTimeInterval)intervalSeconds
                        onTick:
    (void (^)(double,
              double,
              double,
              double,
              double))onTick
                    onComplete:
    (void (^)(void))onComplete {

    if (fromLat < -90.0 ||
        fromLat > 90.0 ||
        toLat < -90.0 ||
        toLat > 90.0 ||
        fromLon < -180.0 ||
        fromLon > 180.0 ||
        toLon < -180.0 ||
        toLon > 180.0) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeInvalidInput
                technical:
                    @"Invalid movement coordinate"];
    }

    if (metersPerSecond <= 0.0 ||
        metersPerSecond > 300.0) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeInvalidInput
                technical:
                    @"Movement speed out of range"];
    }

    if (intervalSeconds <= 0.0 ||
        intervalSeconds > 10.0) {

        intervalSeconds =
            1.0;
    }

    [self stop];

    _start =
        { fromLat, fromLon };

    _destination =
        { toLat, toLon };

    _speedMps =
        metersPerSecond;

    _updateIntervalSeconds =
        intervalSeconds;

    _totalDistanceMeters =
        wolfox::haversineDistanceMeters(
            _start,
            _destination
        );

    _onTick =
        [onTick copy];

    _onComplete =
        [onComplete copy];

    self.currentLatitude =
        fromLat;

    self.currentLongitude =
        fromLon;

    self.progress =
        0.0;

    _progressAtAnchor =
        0.0;

    _anchorDate =
        [NSDate date];

    if (_totalDistanceMeters < 1.0) {

        self.currentLatitude =
            toLat;

        self.currentLongitude =
            toLon;

        self.progress =
            1.0;

        self.distanceRemainingMeters =
            0.0;

        self.state =
            WFMovementEngineStateFinished;

        if (_onComplete) {
            _onComplete();
        }

        return [WFError success];
    }

    self.courseDegrees =
        wolfox::initialBearingDegrees(
            _start,
            _destination
        );

    self.distanceRemainingMeters =
        _totalDistanceMeters;

    self.state =
        WFMovementEngineStateRunning;

    [self startTimer];

    return [WFError success];
}

- (void)startTimer {

    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }

    _timer =
        dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER,
            0,
            0,
            _engineQueue
        );

    uint64_t interval =
        (uint64_t)(
            _updateIntervalSeconds *
            NSEC_PER_SEC
        );

    dispatch_source_set_timer(
        _timer,
        dispatch_time(
            DISPATCH_TIME_NOW,
            interval
        ),
        interval,
        interval / 10
    );

    __weak typeof(self) weakSelf =
        self;

    dispatch_source_set_event_handler(
        _timer,
        ^{

        __strong typeof(weakSelf) self =
            weakSelf;

        if (!self) {
            return;
        }

        if (self.state !=
            WFMovementEngineStateRunning) {

            return;
        }

        [self tickLocked];
    });

    dispatch_resume(_timer);
}

- (void)tickLocked {

    NSTimeInterval elapsed =
        -[_anchorDate timeIntervalSinceNow];

    double addedProgress =

        (_totalDistanceMeters > 0.0)

        ? ((_speedMps * elapsed) /
            _totalDistanceMeters)

        : 1.0;

    double fraction =
        wolfox::clampFraction(
            _progressAtAnchor +
            addedProgress
        );

    wolfox::Coordinate current =
        wolfox::interpolateGreatCircle(
            _start,
            _destination,
            fraction
        );

    self.currentLatitude =
        current.latitude;

    self.currentLongitude =
        current.longitude;

    self.courseDegrees =
        wolfox::initialBearingDegrees(
            current,
            _destination
        );

    self.distanceRemainingMeters =
        _totalDistanceMeters *
        (1.0 - fraction);

    self.progress =
        fraction;

    if (_onTick) {

        _onTick(
            current.latitude,
            current.longitude,
            self.courseDegrees,
            self.distanceRemainingMeters,
            fraction
        );
    }

    [[WFEventBus sharedBus]
        publish:WFEventLocationChanged
        payload:@{

            @"lat":
                @(current.latitude),

            @"lon":
                @(current.longitude),

            @"course":
                @(self.courseDegrees),

            @"progress":
                @(fraction)
        }];

    if (fraction >= 1.0) {

        self.state =
            WFMovementEngineStateFinished;

        if (_timer) {
            dispatch_source_cancel(_timer);
            _timer = nil;
        }

        void (^completion)(void) =
            _onComplete;

        _onTick = nil;
        _onComplete = nil;

        if (completion) {
            completion();
        }
    }
}

- (void)pause {

    dispatch_sync(_engineQueue, ^{

        if (self.state !=
            WFMovementEngineStateRunning) {

            return;
        }

        self->_progressAtAnchor =
            self.progress;

        self.state =
            WFMovementEngineStatePaused;

        if (self->_timer) {

            dispatch_source_cancel(
                self->_timer
            );

            self->_timer = nil;
        }
    });
}

- (void)resume {

    dispatch_sync(_engineQueue, ^{

        if (self.state !=
            WFMovementEngineStatePaused) {

            return;
        }

        self->_anchorDate =
            [NSDate date];

        self.state =
            WFMovementEngineStateRunning;
    });

    [self startTimer];
}

- (void)stop {

    dispatch_sync(_engineQueue, ^{

        if (self->_timer) {

            dispatch_source_cancel(
                self->_timer
            );

            self->_timer = nil;
        }

        self->_onTick = nil;
        self->_onComplete = nil;

        if (self.state !=
            WFMovementEngineStateFinished) {

            self.state =
                WFMovementEngineStateStopped;
        }
    });
}

@end


#pragma mark - WFAppManager

@interface WFAppManager ()

@property (nonatomic, strong)
WFMovementEngine *movementEngine;

@end


@implementation WFAppManager

+ (instancetype)sharedManager {

    static WFAppManager *instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance =
            [[WFAppManager alloc] init];
    });

    return instance;
}

- (void)initialize {

    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{

        [[WFLogger sharedLogger]
            logCategory:WFLogCore
            message:
                @"WolFox standalone dylib initialized"];

        [[WFRuntimeState sharedState]
            resetToDefaultEnvironment];
    });
}

- (WFError *)activateStaticLocationWithLatitude:
    (double)latitude
                                      longitude:
    (double)longitude {

    return
        [[WFLocationService sharedService]
            setLocationWithLatitude:latitude
                          longitude:longitude];
}

- (WFError *)restoreDefaultLocation {

    return
        [[WFLocationService sharedService]
            restoreDefault];
}

- (WFError *)startMovementFromLatitude:
    (double)fromLat
                             longitude:
    (double)fromLon
                            toLatitude:
    (double)toLat
                            longitude2:
    (double)toLon
                                 speed:
    (double)metersPerSecond {

    WFRuntimeState *runtime =
        [WFRuntimeState sharedState];

    if (runtime.randomMovementActive ||
        runtime.routeActive) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeConflict
                technical:
                    @"Random or route mode already active"];
    }

    [self stopMovement];

    self.movementEngine =
        [[WFMovementEngine alloc] init];

    __weak typeof(self) weakSelf =
        self;

    WFError *error =
        [self.movementEngine

            startFromLatitude:fromLat

            longitude:fromLon

            toLatitude:toLat

            longitude2:toLon

            speed:metersPerSecond

            updateInterval:1.0

            onTick:
                ^(double lat,
                  double lon,
                  double course,
                  double remaining,
                  double progress) {

        [[WFRuntimeState sharedState]
            performUpdate:
                ^(id<WFRuntimeStateMutable> state) {

            state.locationEnabled =
                YES;

            state.currentLatitude =
                lat;

            state.currentLongitude =
                lon;

            state.movementCourse =
                course;

            state.lastError =
                @"";
        }];

    }

            onComplete:^{

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

            [weakSelf
                resetMovementState:
                    @"Movement finished"];
        });
    }];

    if (error.isSuccess) {

        [[WFRuntimeState sharedState]
            performUpdate:
                ^(id<WFRuntimeStateMutable> state) {

            state.locationEnabled =
                YES;

            state.locationMode =
                WFLocationModeMovement;

            state.movementActive =
                YES;

            state.movementPaused =
                NO;

            state.movementSpeed =
                metersPerSecond;

            state.lastAction =
                @"Movement started";

            state.lastError =
                @"";
        }];
    }

    return error;
}

- (WFError *)pauseMovement {

    if (!self.movementEngine ||
        self.movementEngine.state !=
            WFMovementEngineStateRunning) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeNotAvailable
                technical:
                    @"No running movement"];
    }

    [self.movementEngine pause];

    [[WFRuntimeState sharedState]
        performUpdate:
            ^(id<WFRuntimeStateMutable> state) {

        state.movementPaused =
            YES;

        state.lastAction =
            @"Movement paused";
    }];

    return [WFError success];
}

- (WFError *)resumeMovement {

    if (!self.movementEngine ||
        self.movementEngine.state !=
            WFMovementEngineStatePaused) {

        return
            [WFError
                errorWithCode:
                    WFErrorCodeNotAvailable
                technical:
                    @"No paused movement"];
    }

    [self.movementEngine resume];

    [[WFRuntimeState sharedState]
        performUpdate:
            ^(id<WFRuntimeStateMutable> state) {

        state.movementPaused =
            NO;

        state.lastAction =
            @"Movement resumed";
    }];

    return [WFError success];
}

- (WFError *)stopMovement {

    if (self.movementEngine) {

        [self.movementEngine stop];
    }

    [self resetMovementState:
        @"Movement stopped"];

    return [WFError success];
}

- (void)resetMovementState:
    (NSString *)action {

    self.movementEngine =
        nil;

    [[WFRuntimeState sharedState]
        performUpdate:
            ^(id<WFRuntimeStateMutable> state) {

        if (state.locationMode ==
            WFLocationModeMovement) {

            state.locationMode =
                WFLocationModeDefault;
        }

        state.movementActive =
            NO;

        state.movementPaused =
            NO;

        state.movementSpeed =
            0.0;

        state.movementCourse =
            0.0;

        state.lastAction =
            action ?: @"Movement stopped";
    }];
}


#pragma mark Future Phases

- (WFError *)startRandomMovementWithRadius:
    (double)radiusMeters {

    return
        [WFError
            errorWithCode:
                WFErrorCodeNotAvailable
            technical:
                @"Random movement not implemented yet"];
}

- (WFError *)startRouteWithWaypoints:
    (NSArray *)waypoints
                               speed:
    (double)metersPerSecond {

    return
        [WFError
            errorWithCode:
                WFErrorCodeNotAvailable
            technical:
                @"Route engine not implemented yet"];
}

- (WFError *)setActiveWiFiProfileWithID:
    (NSString *)profileID {

    return
        [WFError
            errorWithCode:
                WFErrorCodeNotAvailable
            technical:
                @"WiFi profiles not implemented yet"];
}

- (WFError *)setActiveDeviceProfileWithID:
    (NSString *)profileID {

    return
        [WFError
            errorWithCode:
                WFErrorCodeNotAvailable
            technical:
                @"Device profiles not implemented yet"];
}

- (WFError *)startScheduler {

    return
        [WFError
            errorWithCode:
                WFErrorCodeNotAvailable
            technical:
                @"Scheduler not implemented yet"];
}

@end


#pragma mark - Standalone Entry Point

__attribute__((constructor))
static void WolFoxStandaloneInit(void) {

    @autoreleasepool {

        [[WFAppManager sharedManager]
            initialize];
    }
}