#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT void WFAuditLogNSString(NSString *category, NSString *message);
FOUNDATION_EXPORT void WFAuditLogIntercept(NSString *hookName, NSString *result);
FOUNDATION_EXPORT void WFAuditLogLocation(NSString *source, CLLocation * _Nullable location);

FOUNDATION_EXPORT void WFAuditLogFeature(
    NSString *feature,
    NSString *status,
    NSString * _Nullable details
);

FOUNDATION_EXPORT void WFAuditLogState(
    NSString *source,
    NSDictionary *snapshot
);

FOUNDATION_EXPORT NSString *WFAuditLogFilePath(void);
FOUNDATION_EXPORT NSString *WFAuditReadAll(void);
FOUNDATION_EXPORT void WFAuditClear(void);

FOUNDATION_EXPORT void WFAuditPresentLogs(UIViewController *presentingViewController);

NS_ASSUME_NONNULL_END
