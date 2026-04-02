#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^UniModuleKeepAliveCallback)(NSDictionary *_Nullable result, BOOL keepAlive);

#ifndef UNI_EXPORT_METHOD
#define UNI_EXPORT_METHOD(method)
#endif

@interface DCUniModule : NSObject
@end

NS_ASSUME_NONNULL_END
