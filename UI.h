#import <Foundation/Foundation.h>

@interface WFUIController : NSObject

+ (instancetype)sharedController;
- (void)installWhenReady;

@end