#import <Foundation/Foundation.h>

#pragma mark - WFLogger

typedef NS_ENUM(NSInteger, WFLogCategory) {
    WFLogCore,
    WFLogLocation,
    WFLogMovement,
    WFLogRandom,
    WFLogRoute,
    WFLogWiFi,
    WFLogDevice,
    WFLogScheduler,
    WFLogStorage,
    WFLogUI
};

@interface WFLogger : NSObject

+ (instancetype)sharedLogger;
- (void)logCategory:(WFLogCategory)category
            message:(NSString *)message;

@end


#pragma mark - WFError

typedef NS_ENUM(NSInteger, WFErrorCode) {
    WFErrorCodeSuccess            = 0,
    WFErrorCodeInvalidInput       = 1,
    WFErrorCodeNotAvailable       = 2,
    WFErrorCodeNetworkError       = 3,
    WFErrorCodeConflict           = 4,
    WFErrorCodeStorageError       = 5,
    WFErrorCodeUnsupportedVersion = 6,
    WFErrorCodeRouteError         = 7,
};

@interface WFError : NSObject

@property (nonatomic, readonly) WFErrorCode errorCode;
@property (nonatomic, readonly, copy) NSString *humanReadableMessage;
@property (nonatomic, readonly, copy) NSString *technicalMessage;

+ (instancetype)errorWithCode:(WFErrorCode)code
                    technical:(NSString *)technicalMessage;

+ (instancetype)success;

- (BOOL)isSuccess;

@end


#pragma mark - WFEventBus

extern NSString * const WFEventLocationChanged;
extern NSString * const WFEventRuntimeStateChanged;
extern NSString * const WFEventRouteProgressChanged;
extern NSString * const WFEventErrorOccurred;

@interface WFEventBus : NSObject

+ (instancetype)sharedBus;

- (void)subscribe:(NSString *)eventName
         observer:(id)observer
            block:(void (^)(NSDictionary *payload))block;

- (void)unsubscribe:(id)observer;

- (void)publish:(NSString *)eventName
        payload:(NSDictionary *)payload;

@end


#pragma mark - WFRuntimeState

typedef NS_ENUM(NSInteger, WFLocationMode) {
    WFLocationModeDefault  = 0,
    WFLocationModeStatic   = 1,
    WFLocationModeMovement = 2,
    WFLocationModeRandom   = 3,
    WFLocationModeRoute    = 4,
};

@protocol WFRuntimeStateMutable <NSObject>

@property (nonatomic, assign, readwrite) BOOL locationEnabled;
@property (nonatomic, assign, readwrite) double currentLatitude;
@property (nonatomic, assign, readwrite) double currentLongitude;
@property (nonatomic, assign, readwrite) WFLocationMode locationMode;

@property (nonatomic, assign, readwrite) BOOL movementActive;
@property (nonatomic, assign, readwrite) BOOL movementPaused;
@property (nonatomic, assign, readwrite) double movementSpeed;
@property (nonatomic, assign, readwrite) double movementCourse;

@property (nonatomic, assign, readwrite) BOOL randomMovementActive;
@property (nonatomic, assign, readwrite) double randomRadius;

@property (nonatomic, assign, readwrite) BOOL routeActive;
@property (nonatomic, assign, readwrite) BOOL routePaused;
@property (nonatomic, assign, readwrite) double routeProgress;
@property (nonatomic, assign, readwrite) double routeDistanceRemaining;
@property (nonatomic, assign, readwrite) double routeSpeed;

@property (nonatomic, copy, readwrite) NSString *activeWiFiProfileID;
@property (nonatomic, copy, readwrite) NSString *activeDeviceProfileID;

@property (nonatomic, assign, readwrite) BOOL schedulerActive;

@property (nonatomic, copy, readwrite) NSString *lastAction;
@property (nonatomic, copy, readwrite) NSString *lastError;

@end


@interface WFRuntimeState : NSObject

+ (instancetype)sharedState;

@property (nonatomic, readonly) BOOL locationEnabled;
@property (nonatomic, readonly) double currentLatitude;
@property (nonatomic, readonly) double currentLongitude;
@property (nonatomic, readonly) WFLocationMode locationMode;

@property (nonatomic, readonly) BOOL movementActive;
@property (nonatomic, readonly) BOOL movementPaused;
@property (nonatomic, readonly) double movementSpeed;
@property (nonatomic, readonly) double movementCourse;

@property (nonatomic, readonly) BOOL randomMovementActive;
@property (nonatomic, readonly) double randomRadius;

@property (nonatomic, readonly) BOOL routeActive;
@property (nonatomic, readonly) BOOL routePaused;
@property (nonatomic, readonly) double routeProgress;
@property (nonatomic, readonly) double routeDistanceRemaining;
@property (nonatomic, readonly) double routeSpeed;

@property (nonatomic, readonly, copy) NSString *activeWiFiProfileID;
@property (nonatomic, readonly, copy) NSString *activeDeviceProfileID;

@property (nonatomic, readonly) BOOL schedulerActive;

@property (nonatomic, readonly, copy) NSString *lastAction;
@property (nonatomic, readonly, copy) NSString *lastError;

- (void)performUpdate:
    (void (^)(id<WFRuntimeStateMutable> state))updateBlock;

- (NSDictionary *)snapshotForUI;

- (void)resetToDefaultEnvironment;

@end


#pragma mark - WFSettingsStore

@interface WFSettingsStore : NSObject

+ (instancetype)sharedStore;

- (void)setObjectForKey:(NSString *)key value:(id)value;
- (id)objectForKey:(NSString *)key;

- (void)setStringForKey:(NSString *)key value:(NSString *)value;
- (NSString *)stringForKey:(NSString *)key;

- (void)setDoubleForKey:(NSString *)key value:(double)value;
- (double)doubleForKey:(NSString *)key;

- (void)setBoolForKey:(NSString *)key value:(BOOL)value;
- (BOOL)boolForKey:(NSString *)key;

- (void)setArrayForKey:(NSString *)key value:(NSArray *)value;
- (NSArray *)arrayForKey:(NSString *)key;

- (void)setDictionaryForKey:(NSString *)key
                      value:(NSDictionary *)value;

- (NSDictionary *)dictionaryForKey:(NSString *)key;

- (void)removeKey:(NSString *)key;

@end


#pragma mark - WFLocationModel

@interface WFLocationModel : NSObject

@property (nonatomic, copy, readonly) NSString *locationID;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, readonly) double latitude;
@property (nonatomic, readonly) double longitude;
@property (nonatomic, copy, readonly) NSDate *createdAt;

+ (instancetype)locationWithName:(NSString *)name
                        latitude:(double)latitude
                       longitude:(double)longitude;

- (BOOL)coordinateIsValid;

- (NSDictionary *)toDictionary;

+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end


#pragma mark - WFLocationService

@interface WFLocationService : NSObject

+ (instancetype)sharedService;

- (WFError *)setLocationWithLatitude:(double)latitude
                           longitude:(double)longitude;

- (BOOL)isLocationActive;

- (NSDictionary *)currentLocation;

- (WFError *)clearLocation;

- (WFError *)restoreDefault;

- (NSArray<WFLocationModel *> *)favorites;

- (WFError *)addFavoriteWithName:(NSString *)name
                        latitude:(double)latitude
                       longitude:(double)longitude;

- (WFError *)renameFavoriteWithID:(NSString *)locationID
                          newName:(NSString *)newName;

- (WFError *)deleteFavoriteWithID:(NSString *)locationID;

- (WFError *)activateFavoriteWithID:(NSString *)locationID;

@end


#pragma mark - WFMovementEngine

typedef NS_ENUM(NSInteger, WFMovementEngineState) {
    WFMovementEngineStateStopped  = 0,
    WFMovementEngineStateRunning  = 1,
    WFMovementEngineStatePaused   = 2,
    WFMovementEngineStateFinished = 3,
};

@interface WFMovementEngine : NSObject

@property (nonatomic, readonly) WFMovementEngineState state;
@property (nonatomic, readonly) double currentLatitude;
@property (nonatomic, readonly) double currentLongitude;
@property (nonatomic, readonly) double courseDegrees;
@property (nonatomic, readonly) double distanceRemainingMeters;
@property (nonatomic, readonly) double progress;

- (WFError *)startFromLatitude:(double)fromLat
                     longitude:(double)fromLon
                    toLatitude:(double)toLat
                    longitude2:(double)toLon
                         speed:(double)metersPerSecond
                updateInterval:(NSTimeInterval)intervalSeconds
                        onTick:
                            (void (^)(double lat,
                                      double lon,
                                      double course,
                                      double remaining,
                                      double progress))onTick
                    onComplete:(void (^)(void))onComplete;

- (void)pause;
- (void)resume;
- (void)stop;

@end


#pragma mark - WFAppManager

@interface WFAppManager : NSObject

+ (instancetype)sharedManager;

- (void)initialize;

- (WFError *)activateStaticLocationWithLatitude:(double)latitude
                                      longitude:(double)longitude;

- (WFError *)restoreDefaultLocation;

- (WFError *)startMovementFromLatitude:(double)fromLat
                             longitude:(double)fromLon
                            toLatitude:(double)toLat
                            longitude2:(double)toLon
                                 speed:(double)metersPerSecond;

- (WFError *)pauseMovement;
- (WFError *)resumeMovement;
- (WFError *)stopMovement;

- (WFError *)startRandomMovementWithRadius:(double)radiusMeters;

- (WFError *)startRouteWithWaypoints:(NSArray *)waypoints
                               speed:(double)metersPerSecond;

- (WFError *)setActiveWiFiProfileWithID:(NSString *)profileID;

- (WFError *)setActiveDeviceProfileWithID:(NSString *)profileID;

- (WFError *)startScheduler;

@end