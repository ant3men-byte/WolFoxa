#import "WolFox.h"
#import "Portable.h"

#pragma mark - WFLogger

static NSString * const WFCategoryNames[] = {
    @"CORE", @"LOCATION", @"MOVEMENT", @"RANDOM", @"ROUTE",
    @"WIFI", @"DEVICE", @"SCHEDULER", @"STORAGE", @"UI"
};

@implementation WFLogger {
    dispatch_queue_t _logQueue;
}
+ (instancetype)sharedLogger {
    static WFLogger *instance; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[WFLogger alloc] init]; });
    return instance;
}
- (instancetype)init {
    if ((self = [super init]))
        _logQueue = dispatch_queue_create("com.wolfox.logger", DISPATCH_QUEUE_SERIAL);
    return self;
}
- (void)logCategory:(WFLogCategory)category message:(NSString *)message {
#if DEBUG
    const BOOL shouldEmit = YES;
#else
    const BOOL shouldEmit = (category == WFLogCore || category == WFLogScheduler);
#endif
    if (!shouldEmit || message.length == 0) return;
    NSString *line = [NSString stringWithFormat:@"[WolFox][%@] %@",
                      WFCategoryNames[category], message];
    dispatch_async(_logQueue, ^{ NSLog(@"%@", line); });
}
@end

#pragma mark - WFError

@interface WFError ()
- (instancetype)initPrivateWithCode:(WFErrorCode)code humanText:(NSString *)human
                          technical:(NSString *)technical;
@end

@implementation WFError
+ (instancetype)errorWithCode:(WFErrorCode)code technical:(NSString *)technicalMessage {
    return [[self alloc] initPrivateWithCode:code
                                   humanText:[WFError humanTextForCode:code]
                                   technical:technicalMessage ?: @""];
}
+ (instancetype)success {
    return [[self alloc] initPrivateWithCode:WFErrorCodeSuccess
                                   humanText:@"OK" technical:@""];
}
- (instancetype)initPrivateWithCode:(WFErrorCode)code humanText:(NSString *)human
                          technical:(NSString *)technical {
    if ((self = [super init])) {
        _errorCode = code;
        _humanReadableMessage = [human copy];
        _technicalMessage = [technical copy];
    }
    return self;
}
- (BOOL)isSuccess { return _errorCode == WFErrorCodeSuccess; }
+ (NSString *)humanTextForCode:(WFErrorCode)code {
    switch (code) {
        case WFErrorCodeSuccess:            return @"Success.";
        case WFErrorCodeInvalidInput:       return @"The provided value is invalid.";
        case WFErrorCodeNotAvailable:       return @"This feature is not available right now.";
        case WFErrorCodeNetworkError:       return @"A network request failed. Check connectivity.";
        case WFErrorCodeConflict:           return @"Another simulation mode is already active.";
        case WFErrorCodeStorageError:       return @"Saving data failed.";
        case WFErrorCodeUnsupportedVersion: return @"This data file uses an unsupported format version.";
        case WFErrorCodeRouteError:         return @"The route could not be created or followed.";
    }
    return @"Unknown error.";
}
@end

#pragma mark - WFEventBus

NSString * const WFEventLocationChanged      = @"WFEventLocationChanged";
NSString * const WFEventRuntimeStateChanged  = @"WFEventRuntimeStateChanged";
NSString * const WFEventRouteProgressChanged = @"WFEventRouteProgressChanged";
NSString * const WFEventErrorOccurred        = @"WFEventErrorOccurred";

@implementation WFEventBus {
    NSMutableDictionary<NSString *, NSMapTable<id, void (^)(NSDictionary *)> *> *_observers;
    dispatch_queue_t _busQueue;
}
+ (instancetype)sharedBus {
    static WFEventBus *instance; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[WFEventBus alloc] init]; });
    return instance;
}
- (instancetype)init {
    if ((self = [super init])) {
        _observers = [NSMutableDictionary dictionary];
        _busQueue = dispatch_queue_create("com.wolfox.eventbus", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
- (void)subscribe:(NSString *)eventName observer:(id)observer
             block:(void (^)(NSDictionary *))block {
    NSParameterAssert(eventName && observer && block);
    dispatch_sync(_busQueue, ^{
        NSMapTable *table = _observers[eventName];
        if (!table) {
            table = [NSMapTable weakToStrongObjectsMapTable]; // weak observer: no cycles
            _observers[eventName] = table;
        }
        [table setObject:block forKey:observer];
    });
}
- (void)unsubscribe:(id)observer {
    dispatch_sync(_busQueue, ^{
        for (NSMapTable *table in _observers.allValues) [table removeObjectForKey:observer];
    });
}
- (void)publish:(NSString *)eventName payload:(NSDictionary *)payload {
    NSDictionary *safePayload = [payload copy] ?: @{};
    dispatch_async(_busQueue, ^{
        NSMapTable *table = _observers[eventName];
        NSMutableArray<void (^)(NSDictionary *)> *blocks = [NSMutableArray array];
        for (id key in table) {
            void (^block)(NSDictionary *) = [table objectForKey:key];
            if (block) [blocks addObject:block];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            for (void (^block)(NSDictionary *) in blocks) block(safePayload);
        });
    });
}
@end

#pragma mark - WFRuntimeState

@interface WFRuntimeState () <WFRuntimeStateMutable>
@end

@implementation WFRuntimeState {
    dispatch_queue_t _stateQueue;
}
+ (instancetype)sharedState {
    static WFRuntimeState *instance; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[WFRuntimeState alloc] init]; });
    return instance;
}
- (instancetype)init {
    if ((self = [super init])) {
        _stateQueue = dispatch_queue_create("com.wolfox.runtimestate", DISPATCH_QUEUE_SERIAL);
        [self resetToDefaultEnvironment];
    }
    return self;
}
- (void)resetToDefaultEnvironment {
    [self performUpdate:^(id<WFRuntimeStateMutable> s) {
        s.locationEnabled = NO;
        s.currentLatitude = 0.0;
        s.currentLongitude = 0.0;
        s.locationMode = WFLocationModeDefault;
        s.movementActive = NO;
        s.movementPaused = NO;
        s.movementSpeed = 0.0;
        s.movementCourse = 0.0;
        s.randomMovementActive = NO;
        s.randomRadius = 0.0;
        s.routeActive = NO;
        s.routePaused = NO;
        s.routeProgress = 0.0;
        s.routeDistanceRemaining = 0.0;
        s.routeSpeed = 0.0;
        s.activeWiFiProfileID = @"";
        s.activeDeviceProfileID = @"";
        s.schedulerActive = NO;
        s.lastAction = @"Environment restored to default";
        s.lastError = @"";
    }];
}
- (void)performUpdate:(void (^)(id<WFRuntimeStateMutable>))updateBlock {
    NSParameterAssert(updateBlock);
    dispatch_sync(_stateQueue, ^{ updateBlock((id<WFRuntimeStateMutable>)self); });
    [[WFEventBus sharedBus] publish:WFEventRuntimeStateChanged
        payload:[self snapshotForUI]];
}
- (NSDictionary *)snapshotForUI {
    __block NSDictionary *snapshot;
    dispatch_sync(_stateQueue, ^{
        snapshot = @{
            @"locationEnabled": @(_locationEnabled),
            @"latitude":        @(_currentLatitude),
            @"longitude":       @(_currentLongitude),
            @"locationMode":    @(_locationMode),
            @"movementActive":  @(_movementActive),
            @"movementPaused":  @(_movementPaused),
            @"movementSpeed":   @(_movementSpeed),
            @"movementCourse":  @(_movementCourse),
            @"randomActive":    @(_randomMovementActive),
            @"randomRadius":    @(_randomRadius),
            @"routeActive":     @(_routeActive),
            @"routePaused":     @(_routePaused),
            @"routeProgress":   @(_routeProgress),
            @"routeRemaining":  @(_routeDistanceRemaining),
            @"routeSpeed":      @(_routeSpeed),
            @"wifiProfile":     _activeWiFiProfileID ?: @"",
            @"deviceProfile":   _activeDeviceProfileID ?: @"",
            @"schedulerActive": @(_schedulerActive),
            @"lastAction":      _lastAction ?: @"",
            @"lastError":       _lastError ?: @"",
        };
    });
    return snapshot;
}
@end

#pragma mark - WFSettingsStore

static NSString * const kStorePrefix = @"wolfox.";

@implementation WFSettingsStore
+ (instancetype)sharedStore {
    static WFSettingsStore *instance; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[WFSettingsStore alloc] init]; });
    return instance;
}
- (NSString *)prefixedKey:(NSString *)key {
    if (key.length == 0) {
        [[WFLogger sharedLogger] logCategory:WFLogStorage
            message:@"Rejected empty settings key"];
        return nil;
    }
    return [kStorePrefix stringByAppendingString:key];
}
- (void)setObjectForKey:(NSString *)key value:(id)value {
    NSString *k = [self prefixedKey:key];
    if (!k) return;
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:k];
}
- (id)objectForKey:(NSString *)key {
    NSString *k = [self prefixedKey:key];
    if (!k) return nil;
    return [[NSUserDefaults standardUserDefaults] objectForKey:k];
}
- (void)setStringForKey:(NSString *)key value:(NSString *)value { [self setObjectForKey:key value:value]; }
- (NSString *)stringForKey:(NSString *)key {
    id v = [self objectForKey:key];
    return [v isKindOfClass:[NSString class]] ? v : nil;
}
- (void)setDoubleForKey:(NSString *)key value:(double)value { [self setObjectForKey:key value:@(value)]; }
- (double)doubleForKey:(NSString *)key {
    id v = [self objectForKey:key];
    return [v isKindOfClass:[NSNumber class]] ? [v doubleValue] : 0.0;
}
- (void)setBoolForKey:(NSString *)key value:(BOOL)value { [self setObjectForKey:key value:@(value)]; }
- (BOOL)boolForKey:(NSString *)key {
    id v = [self objectForKey:key];
    return [v isKindOfClass:[NSNumber class]] ? [v boolValue] : NO;
}
- (void)setArrayForKey:(NSString *)key value:(NSArray *)value { [self setObjectForKey:key value:value]; }
- (NSArray *)arrayForKey:(NSString *)key {
    id v = [self objectForKey:key];
    return [v isKindOfClass:[NSArray class]] ? v : @[];
}
- (void)setDictionaryForKey:(NSString *)key value:(NSDictionary *)value { [self setObjectForKey:key value:value]; }
- (NSDictionary *)dictionaryForKey:(NSString *)key {
    id v = [self objectForKey:key];
    return [v isKindOfClass:[NSDictionary class]] ? v : @{};
}
- (void)removeKey:(NSString *)key {
    NSString *k = [self prefixedKey:key];
    if (!k) return;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:k];
}
@end

#pragma mark - WFLocationModel

static NSString *const kSchemaLocation = @"wolfox.location/1";

@interface WFLocationModel ()
@property (nonatomic, copy, readwrite) NSString *locationID;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, readwrite) double latitude;
@property (nonatomic, readwrite) double longitude;

@property (nonatomic, copy, readwrite) NSDate *createdAt;
@end

@implementation WFLocationModel

+ (instancetype)locationWithName:(NSString *)name latitude:(double)latitude
                       longitude:(double)longitude {
    WFLocationModel *loc = [[WFLocationModel alloc] init];
    loc->_locationID = [[NSUUID UUID] UUIDString];
    loc->_name       = [name copy] ?: @"Unnamed";
    loc->_latitude   = latitude;
    loc->_longitude  = longitude;
    loc->_createdAt  = [NSDate date];
    return loc;
}

- (BOOL)coordinateIsValid {
    return _latitude >= -90.0 && _latitude <= 90.0
        && _longitude >= -180.0 && _longitude <= 180.0;
}

- (NSDictionary *)toDictionary {
    return @{
        @"schema":    kSchemaLocation,
        @"id":        _locationID ?: @"",
        @"name":      _name ?: @"",
        @"lat":       @(_latitude),
        @"lon":       @(_longitude),
        @"createdAt": @([_createdAt timeIntervalSince1970]),
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    if (![dict[@"schema"] isEqualToString:kSchemaLocation]) return nil;
    NSNumber *lat = dict[@"lat"], *lon = dict[@"lon"];
    if (![lat isKindOfClass:[NSNumber class]] ||
        ![lon isKindOfClass:[NSNumber class]]) return nil;
    double la = lat.doubleValue, lo = lon.doubleValue;
    if (la < -90.0 || la > 90.0 || lo < -180.0 || lo > 180.0) return nil;

    WFLocationModel *loc = [[WFLocationModel alloc] init];
    loc->_locationID = [dict[@"id"] isKindOfClass:[NSString class]]
        ? dict[@"id"] : [[NSUUID UUID] UUIDString];
    loc->_name = [dict[@"name"] isKindOfClass:[NSString class]]
        ? dict[@"name"] : @"Unnamed";
    loc->_latitude = la;
    loc->_longitude = lo;
    loc->_createdAt = [dict[@"createdAt"] isKindOfClass:[NSNumber class]]
        ? [NSDate dateWithTimeIntervalSince1970:[dict[@"createdAt"] doubleValue]]
        : [NSDate date];
    return loc;
}

@end

#pragma mark - WFLocationService

static NSString *const kFavoritesKey = @"wolfox.favorites.v1";
static NSString *const kLastLatKey   = @"wolfox.lastLatitude";
static NSString *const kLastLonKey   = @"wolfox.lastLongitude";

@interface WFLocationModel ()
@property (nonatomic, copy, readwrite) NSString *name;
@end

@implementation WFLocationService

+ (instancetype)sharedService {
    static WFLocationService *instance; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[WFLocationService alloc] init]; });
    return instance;
}

#pragma mark Active location

- (WFError *)setLocationWithLatitude:(double)latitude longitude:(double)longitude {
    if (latitude < -90.0 || latitude > 90.0 ||
        longitude < -180.0 || longitude > 180.0) {
        [[WFLogger sharedLogger] logCategory:WFLogLocation
            message:[NSString stringWithFormat:@"Rejected invalid coordinate lat=%f lon=%f",
                     latitude, longitude]];
        return [WFError errorWithCode:WFErrorCodeInvalidInput
                            technical:[NSString stringWithFormat:@"lat=%f lon=%f",
                                       latitude, longitude]];
    }
    [[WFRuntimeState sharedState] performUpdate:^(id<WFRuntimeStateMutable> s) {
        s.locationEnabled  = YES;
        s.currentLatitude  = latitude;
        s.currentLongitude = longitude;
        s.locationMode     = WFLocationModeStatic;
        s.lastAction       = @"Static location activated";
        s.lastError        = @"";
    }];
    [[WFSettingsStore sharedStore] setDoubleForKey:kLastLatKey value:latitude];
    [[WFSettingsStore sharedStore] setDoubleForKey:kLastLonKey value:longitude];
    [[WFEventBus sharedBus] publish:WFEventLocationChanged
        payload:@{@"lat": @(latitude), @"lon": @(longitude)}];
    [[WFLogger sharedLogger] logCategory:WFLogLocation
        message:[NSString stringWithFormat:@"Coordinate changed: %.6f, %.6f",
                 latitude, longitude]];
    return [WFError success];
}

- (BOOL)isLocationActive {
    return [WFRuntimeState sharedState].locationEnabled;
}

- (NSDictionary *)currentLocation {
    WFRuntimeState *state = [WFRuntimeState sharedState];
    if (!state.locationEnabled) return nil;
    return @{@"lat": @(state.currentLatitude), @"lon": @(state.currentLongitude)};
}

- (WFError *)clearLocation { return [self restoreDefault]; }

- (WFError *)restoreDefault {
    [[WFRuntimeState sharedState] performUpdate:^(id<WFRuntimeStateMutable> s) {
        s.locationEnabled = NO;
        s.locationMode    = WFLocationModeDefault;
        s.lastAction      = @"Location restored to default";
    }];
    [[WFEventBus sharedBus] publish:WFEventLocationChanged payload:@{}];
    [[WFLogger sharedLogger] logCategory:WFLogLocation
        message:@"Default location state restored"];
    return [WFError success];
}

#pragma mark Favorites

- (NSArray<WFLocationModel *> *)favorites {
    NSArray *raw = [[WFSettingsStore sharedStore] arrayForKey:kFavoritesKey];
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *d in raw) {
        WFLocationModel *loc = [WFLocationModel fromDictionary:d];
        if (loc) {
            [result addObject:loc];
        } else {
            [[WFLogger sharedLogger] logCategory:WFLogStorage
                message:@"Dropped malformed favorite entry (recovery)"];
        }
    }
    return result;
}

- (WFError *)addFavoriteWithName:(NSString *)name latitude:(double)latitude
                       longitude:(double)longitude {
    if (name.length == 0) {
        return [WFError errorWithCode:WFErrorCodeInvalidInput technical:@"empty favorite name"];
    }
    if (latitude < -90.0 || latitude > 90.0 ||
        longitude < -180.0 || longitude > 180.0) {
        return [WFError errorWithCode:WFErrorCodeInvalidInput
                            technical:@"favorite coordinate out of range"];
    }
    NSMutableArray *updated = [[self favorites] mutableCopy];
    [updated addObject:[WFLocationModel locationWithName:name
                                                latitude:latitude
                                               longitude:longitude]];
    [self persistFavorites:updated];
    [[WFLogger sharedLogger] logCategory:WFLogStorage message:@"Favorite saved"];
    return [WFError success];
}

- (WFError *)renameFavoriteWithID:(NSString *)locationID newName:(NSString *)newName {
    if (newName.length == 0) {
        return [WFError errorWithCode:WFErrorCodeInvalidInput technical:@"empty name"];
    }
    NSMutableArray *updated = [[self favorites] mutableCopy];
    NSUInteger index = [updated indexOfObjectPassingTest:
        ^BOOL(WFLocationModel *loc, NSUInteger idx, BOOL *stop) {
            return [loc.locationID isEqualToString:locationID];
        }];
    if (index == NSNotFound) {
        return [WFError errorWithCode:WFErrorCodeNotAvailable technical:@"favorite ID not found"];
    }
    WFLocationModel *loc = updated[index];
    [updated replaceObjectAtIndex:index
        withObject:[WFLocationModel locationWithName:newName
                                            latitude:loc.latitude
                                           longitude:loc.longitude]];
    [self persistFavorites:updated];
    return [WFError success];
}

- (WFError *)deleteFavoriteWithID:(NSString *)locationID {
    NSMutableArray *updated = [[self favorites] mutableCopy];
    NSUInteger before = updated.count;
    [updated filterUsingPredicate:
        [NSPredicate predicateWithFormat:@"locationID != %@", locationID]];
    if (updated.count == before) {
        return [WFError errorWithCode:WFErrorCodeNotAvailable technical:@"favorite ID not found"];
    }
    [self persistFavorites:updated];
    [[WFLogger sharedLogger] logCategory:WFLogStorage message:@"Favorite deleted"];
    return [WFError success];
}

- (WFError *)activateFavoriteWithID:(NSString *)locationID {
    for (WFLocationModel *loc in [self favorites]) {
        if ([loc.locationID isEqualToString:locationID]) {
            return [self setLocationWithLatitude:loc.latitude longitude:loc.longitude];
        }
    }
    return [WFError errorWithCode:WFErrorCodeNotAvailable technical:@"favorite ID not found"];
}

- (void)persistFavorites:(NSArray *)favorites {
    NSMutableArray *dicts = [NSMutableArray array];
    for (WFLocationModel *loc in favorites) [dicts addObject:[loc toDictionary]];
    [[WFSettingsStore sharedStore] setArrayForKey:kFavoritesKey value:dicts];
}

@end

#pragma mark - WFMovementEngine

@implementation WFMovementEngine {
    NSTimer          *_tickTimer;
    dispatch_queue_t  _engineQueue;
    wolfox::Coordinate _start, _destination;
    double            _speedMps;
    double            _totalDistanceMeters;
    double            _progressAtPause;
    NSDate           *_tickAnchorDate;
    double            _progressAtAnchor;
    NSTimeInterval    _updateIntervalSeconds;
    void (^_onTick)(double, double, double, double, double);
    void (^_onComplete)(void);
}

- (instancetype)init {
    if ((self = [super init])) {
        _state = WFMovementEngineStateStopped;
        _engineQueue = dispatch_queue_create("com.wolfox.movement", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc { [_tickTimer invalidate]; }

- (WFError *)startFromLatitude:(double)fromLat longitude:(double)fromLon
                    toLatitude:(double)toLat longitude2:(double)toLon
                         speed:(double)metersPerSecond
                updateInterval:(NSTimeInterval)intervalSeconds
                        onTick:(void (^)(double, double, double, double, double))onTick
                    onComplete:(void (^)(void))onComplete {
    dispatch_sync(_engineQueue, ^{ [self stopLocked]; });

    if (fromLat < -90 || fromLat > 90 || toLat < -90 || toLat > 90 ||
        fromLon < -180 || fromLon > 180 || toLon < -180 || toLon > 180) {
        return [WFError errorWithCode:WFErrorCodeInvalidInput
                            technical:@"invalid start/destination coordinate"];
    }
    if (metersPerSecond <= 0.0 || metersPerSecond > 300.0) {
        return [WFError errorWithCode:WFErrorCodeInvalidInput
                            technical:[NSString stringWithFormat:@"speed=%f m/s out of range",
                                       metersPerSecond]];
    }
    if (intervalSeconds <= 0.0 || intervalSeconds > 10.0) intervalSeconds = 1.0;

    _start       = {fromLat, fromLon};
    _destination = {toLat, toLon};
    _speedMps    = metersPerSecond;
    _updateIntervalSeconds = intervalSeconds;
    _totalDistanceMeters = wolfox::haversineDistanceMeters(_start, _destination);
    _progressAtPause     = 0.0;
    _progressAtAnchor    = 0.0;
    _tickAnchorDate      = [NSDate date];
    _onTick              = [onTick copy];
    _onComplete          = [onComplete copy];

    if (_totalDistanceMeters < 1.0) {
        self.state = WFMovementEngineStateFinished;
        self.currentLatitude  = _destination.latitude;
        self.currentLongitude = _destination.longitude;
        self.progress = 1.0;
        if (_onComplete) _onComplete();
        return [WFError success];
    }

    self.courseDegrees = wolfox::initialBearingDegrees(_start, _destination);
    self.state = WFMovementEngineStateRunning;
    [self startTickTimer];

    [[WFLogger sharedLogger] logCategory:WFLogMovement
        message:[NSString stringWithFormat:@"Movement started: total=%.1fm speed=%.1fm/s",
                 _totalDistanceMeters, _speedMps]];
    return [WFError success];
}

- (void)startTickTimer {
    __weak typeof(self) weakSelf = self;
    dispatch_async(_engineQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.state != WFMovementEngineStateRunning) return;
        NSTimer *timer = [NSTimer timerWithTimeInterval:strongSelf->_updateIntervalSeconds
            repeats:YES block:^(NSTimer *t) { [weakSelf movementTick]; }];
        [strongSelf setTickTimer:timer];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:86400.0 * 365]];
    });
}

- (void)setTickTimer:(NSTimer *)timer {
    [_tickTimer invalidate];
    _tickTimer = timer;
}

- (void)movementTick {
    dispatch_async(_engineQueue, ^{
        if (self.state != WFMovementEngineStateRunning) return;
        [self tickLocked];
    });
}

- (void)tickLocked {
    double elapsed  = -[_tickAnchorDate timeIntervalSinceNow];
    double covered  = _speedMps * elapsed;
    double fraction = wolfox::clampFraction(covered / _totalDistanceMeters);

    wolfox::Coordinate current = wolfox::interpolateGreatCircle(_start, _destination, fraction);

    dispatch_sync(dispatch_get_main_queue(), ^{
        self.currentLatitude  = current.latitude;
        self.currentLongitude = current.longitude;
        self.courseDegrees    = wolfox::initialBearingDegrees(current, _destination);
        self.distanceRemainingMeters = _totalDistanceMeters * (1.0 - fraction);
        self.progress = fraction;
    });

    if (_onTick) {
        _onTick(current.latitude, current.longitude, self.courseDegrees,
                self.distanceRemainingMeters, fraction);
    }
    [[WFEventBus sharedBus] publish:WFEventLocationChanged
        payload:@{@"lat": @(current.latitude), @"lon": @(current.longitude),
                  @"course": @(self.courseDegrees), @"progress": @(fraction)}];

    if (fraction >= 1.0) {
        self.state = WFMovementEngineStateFinished;
        [_tickTimer invalidate];
        if (_onComplete) _onComplete();
        [[WFLogger sharedLogger] logCategory:WFLogMovement message:@"Movement finished"];
    }
}

- (void)pause {
    dispatch_sync(_engineQueue, ^{
        if (self.state != WFMovementEngineStateRunning) return;
        _progressAtPause = self.progress;
        [_tickTimer invalidate];
        _tickTimer = nil;
        self.state = WFMovementEngineStatePaused;
        [[WFLogger sharedLogger] logCategory:WFLogMovement message:@"Movement paused"];
    });
}

- (void)resume {
    dispatch_sync(_engineQueue, ^{
        if (self.state != WFMovementEngineStatePaused) return;
        _progressAtAnchor = _progressAtPause;
        _tickAnchorDate   = [NSDate date];
        self.state = WFMovementEngineStateRunning;
        [self startTickTimer];
        [[WFLogger sharedLogger] logCategory:WFLogMovement message:@"Movement resumed"];
    });
}

- (void)stop {
    dispatch_sync(_engineQueue, ^{ [self stopLocked]; });
}

- (void)stopLocked {
    [_tickTimer invalidate];
    _tickTimer = nil;
    _onTick = nil;
    _onComplete = nil;
    if (self.state != WFMovementEngineStateFinished) {
        self.state = WFMovementEngineStateStopped;
    }
}

@end

#pragma mark - WFAppManager

@interface WFAppManager ()
@property (nonatomic, strong) WFMovementEngine *movementEngine;
@end

@implementation WFAppManager

+ (instancetype)sharedManager {
    static WFAppManager *instance; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[WFAppManager alloc] init]; });
    return instance;
}

- (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[WFLogger sharedLogger] logCategory:WFLogCore
            message:@"WolFox initialize (authorized testing platform)"];
        // Recovery: never resume movement/random/route across launches (§30).
        [[WFRuntimeState sharedState] performUpdate:^(id<WFRuntimeStateMutable> s) {
            s.movementActive       = NO;
            s.movementPaused       = NO;
            s.randomMovementActive = NO;
            s.routeActive          = NO;
            s.routePaused          = NO;
            s.schedulerActive      = NO;
        }];
        [[WFEventBus sharedBus] publish:WFEventRuntimeStateChanged
            payload:[[WFRuntimeState sharedState] snapshotForUI]];
    });
}

#pragma mark Location

- (WFError *)activateStaticLocationWithLatitude:(double)latitude
                                      longitude:(double)longitude {
    return [[WFLocationService sharedService] setLocationWithLatitude:latitude
                                                            longitude:longitude];
}

- (WFError *)restoreDefaultLocation {
    return [[WFLocationService sharedService] restoreDefault];
}

#pragma mark Movement

- (WFError *)startMovementFromLatitude:(double)fromLat longitude:(double)fromLon
                            toLatitude:(double)toLat longitude2:(double)toLon
                                 speed:(double)metersPerSecond {
    WFLocationMode mode = [WFRuntimeState sharedState].locationMode;
    if (wolfox::isModeConflict(wolfox::SimulationMode::Movement,
                               (wolfox::SimulationMode)mode)) {
        return [WFError errorWithCode:WFErrorCodeConflict
                            technical:[NSString stringWithFormat:@"mode %ld active", (long)mode]];
    }
    [self stopMovement]; // stop any non-conflicting active engine first

    __weak typeof(self) weakSelf = self;
    self.movementEngine = [[WFMovementEngine alloc] init];
    WFError *err = [self.movementEngine
        startFromLatitude:fromLat longitude:fromLon
               toLatitude:toLat longitude2:toLon
                    speed:metersPerSecond
           updateInterval:1.0
                   onTick:nil   // UI updates via WFEventLocationChanged
                onComplete:^{ [weakSelf resetMovementState:@"Movement finished"]; }];
    if (err.isSuccess) {
        [[WFRuntimeState sharedState] performUpdate:^(id<WFRuntimeStateMutable> s) {
            s.locationMode   = WFLocationModeMovement;
            s.movementActive = YES;
            s.movementPaused = NO;
            s.movementSpeed  = metersPerSecond;
            s.lastAction     = @"Movement started";
            s.lastError      = @"";
        }];
    }
    return err;
}

- (WFError *)pauseMovement {
    if (!self.movementEngine ||
        self.movementEngine.state != WFMovementEngineStateRunning) {
        return [WFError errorWithCode:WFErrorCodeNotAvailable technical:@"no running movement"];
    }
    [self.movementEngine pause];
    [[WFRuntimeState sharedState] performUpdate:^(id<WFRuntimeStateMutable> s) {
        s.movementPaused = YES;
        s.lastAction     = @"Movement paused";
    }];
    return [WFError success];
}

- (WFError *)resumeMovement {
    if (!self.movementEngine ||
        self.movementEngine.state != WFMovementEngineStatePaused) {
        return [WFError errorWithCode:WFErrorCodeNotAvailable technical:@"no paused movement"];
    }
    [self.movementEngine resume];
    [[WFRuntimeState sharedState] performUpdate:^(id<WFRuntimeStateMutable> s) {
        s.movementPaused = NO;
        s.lastAction     = @"Movement resumed";
    }];
    return [WFError success];
}

- (WFError *)stopMovement {
    if (self.movementEngine) [self.movementEngine stop];
    [self resetMovementState:@"Movement stopped"];
    return [WFError success];
}

- (void)resetMovementState:(NSString *)action {
    self.movementEngine = nil; // engine stop is a safety net via dealloc invalidation
    [[WFRuntimeState sharedState] performUpdate:^(id<WFRuntimeStateMutable> s) {
        if (s.locationMode == WFLocationModeMovement) s.locationMode = WFLocationModeDefault;
        s.movementActive = NO;
        s.movementPaused = NO;
        s.movementSpeed  = 0.0;
        s.lastAction     = action;
    }];
}

#pragma mark Phases 4–9 (honest NotAvailable stubs, spec §45)

- (WFError *)startRandomMovementWithRadius:(double)radiusMeters {
    return [WFError errorWithCode:WFErrorCodeNotAvailable technical:@"Phase 4 pending"];
}
- (WFError *)startRouteWithWaypoints:(NSArray *)waypoints speed:(double)metersPerSecond {
    return [WFError errorWithCode:WFErrorCodeNotAvailable technical:@"Phase 5 pending"];
}
- (WFError *)setActiveWiFiProfileWithID:(NSString *)profileID {
    return [WFError errorWithCode:WFErrorCodeNotAvailable technical:@"Phase 7 pending"];
}
- (WFError *)setActiveDeviceProfileWithID:(NSString *)profileID {
    return [WFError errorWithCode:WFErrorCodeNotAvailable technical:@"Phase 7 pending"];
}
- (WFError *)startScheduler {
    return [WFError errorWithCode:WFErrorCodeNotAvailable technical:@"Phase 6 pending"];
}

@end

