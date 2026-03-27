/*
 * NoUpdateChecker.m
 * 阻止 iOS App 檢查更新 - 標準 Objective-C 版本
 * 
 * 使用方法：直接編譯成 .dylib
 * 
 * 編譯命令：
 * xcrun clang -dynamiclib -arch arm64 -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
 *   -fobjc-arc -framework Foundation -framework UIKit -framework StoreKit \
 *   -o NoUpdateChecker.dylib NoUpdateChecker.m -undefined dynamic_lookup
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

// ============================================================
// 輔助函數：交換方法實現
// ============================================================

static void swizzleMethod(Class class, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    if (class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
        class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

// ============================================================
// 1. Hook NSURLSession - 阻擋 App Store API 請求
// ============================================================

@interface NSURLSession (NoUpdateChecker)
- (NSURLSessionDataTask *)noUpdate_dataTaskWithRequest:(NSURLRequest *)request 
                                     completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler;
@end

@implementation NSURLSession (NoUpdateChecker)

- (NSURLSessionDataTask *)noUpdate_dataTaskWithRequest:(NSURLRequest *)request 
                                     completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSString *url = request.URL.absoluteString;
    
    // 阻擋 Apple App Store API
    if ([url containsString:@"itunes.apple.com"] ||
        [url containsString:@"apps.apple.com"] ||
        [url containsString:@"lookup"] ||
        [url containsString:@"softwareVersion"] ||
        [url containsString:@"Buy"] ||
        [url containsString:@"sa"] ||
        [url containsString:@"install"]) {
        
        NSLog(@"[NoUpdate] Blocked: %@", url);
        
        // 返回空的 404 響應
        NSData *emptyData = [NSData data];
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                                  statusCode:404
                                                                 HTTPVersion:@"1.1"
                                                                headerFields:@{}];
        
        if (completionHandler) {
            completionHandler(emptyData, response, nil);
        }
        return nil;
    }
    
    return [self noUpdate_dataTaskWithRequest:request completionHandler:completionHandler];
}

@end

// ============================================================
// 2. Hook UIApplication - 阻止打開 App Store
// ============================================================

@interface UIApplication (NoUpdateChecker)
- (BOOL)noUpdate_openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options completionHandler:(void (^)(BOOL))completion;
@end

@implementation UIApplication (NoUpdateChecker)

- (BOOL)noUpdate_openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options completionHandler:(void (^)(BOOL))completion {
    NSString *urlStr = url.absoluteString;
    
    // 攔截 App Store 連結
    if ([urlStr containsString:@"itunes.apple.com"] ||
        [urlStr containsString:@"apps.apple.com"] ||
        [urlStr containsString:@"itms-apps"] ||
        [urlStr containsString:@"itms-services"]) {
        
        NSLog(@"[NoUpdate] Blocked URL: %@", urlStr);
        
        if (completion) {
            completion(NO);
        }
        return YES;
    }
    
    return [self noUpdate_openURL:url options:options completionHandler:completion];
}

@end

// ============================================================
// 3. Hook SKStoreProductViewController
// ============================================================

@interface SKStoreProductViewController (NoUpdateChecker)
- (void)noUpdate_loadProductWithParameters:(NSDictionary<NSString *,id> *)parameters completionBlock:(void (^)(NSError * _Nullable))block;
@end

@implementation SKStoreProductViewController (NoUpdateChecker)

- (void)noUpdate_loadProductWithParameters:(NSDictionary<NSString *,id> *)parameters completionBlock:(void (^)(NSError * _Nullable))block {
    NSLog(@"[NoUpdate] Blocked SKStoreProductViewController load");
    
    if (block) {
        NSError *error = [NSError errorWithDomain:@"NoUpdateChecker" 
                                             code:404 
                                         userInfo:@{NSLocalizedDescriptionKey: @"Update blocked"}];
        block(error);
    }
}

@end

// ============================================================
// 4. Hook NSUserDefaults
// ============================================================

@interface NSUserDefaults (NoUpdateChecker)
- (id)noUpdate_objectForKey:(NSString *)defaultName;
@end

@implementation NSUserDefaults (NoUpdateChecker)

- (id)noUpdate_objectForKey:(NSString *)defaultName {
    // 阻止 Store 相關的 Key
    if ([defaultName containsString:@"Store"] || 
        [defaultName containsString:@"kSStore"] ||
        [defaultName containsString:@"com.apple.AppStore"] ||
        [defaultName containsString:@"com.apple.MobileStore"]) {
        
        NSLog(@"[NoUpdate] Blocked NSUserDefaults key: %@", defaultName);
        return nil;
    }
    
    return [self noUpdate_objectForKey:defaultName];
}

@end

// ============================================================
// 5. Hook NSBundle
// ============================================================

@interface NSBundle (NoUpdateChecker)
- (NSDictionary *)noUpdate_infoDictionary;
@end

@implementation NSBundle (NoUpdateChecker)

- (NSDictionary *)noUpdate_infoDictionary {
    NSDictionary *original = [self noUpdate_infoDictionary];
    NSLog(@"[NoUpdate] infoDictionary accessed");
    return original;
}

@end

// ============================================================
// 初始化 - 註冊所有 Hook
// ============================================================

__attribute__((constructor))
static void NoUpdateCheckerInit(void) {
    NSLog(@"[NoUpdateChecker] Loading...");
    
    // Hook NSURLSession
    swizzleMethod([NSURLSession class], 
                  @selector(dataTaskWithRequest:completionHandler:), 
                  @selector(noUpdate_dataTaskWithRequest:completionHandler:));
    
    // Hook UIApplication
    swizzleMethod([UIApplication class], 
                  @selector(openURL:options:completionHandler:), 
                  @selector(noUpdate_openURL:options:completionHandler:));
    
    // Hook SKStoreProductViewController
    swizzleMethod([SKStoreProductViewController class], 
                  @selector(loadProductWithParameters:completionBlock:), 
                  @selector(noUpdate_loadProductWithParameters:completionBlock:));
    
    // Hook NSUserDefaults
    swizzleMethod([NSUserDefaults class], 
                  @selector(objectForKey:), 
                  @selector(noUpdate_objectForKey:));
    
    // Hook NSBundle
    swizzleMethod([NSBundle class], 
                  @selector(infoDictionary), 
                  @selector(noUpdate_infoDictionary));
    
    NSLog(@"[NoUpdateChecker] Loaded - Update checks disabled!");
}