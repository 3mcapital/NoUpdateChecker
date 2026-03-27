/*
 * NoUpdateChecker.dylib
 * 阻止 iOS App 檢查更新
 * 
 * 使用方法：
 * 1. 編譯成 .dylib
 * 2. 通過 Frida 注入或越獄環境加載
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ============================================================
// 方法 1: Hook NSBundle - 阻止獲取更新資訊
// ============================================================

%hook NSBundle

- (NSDictionary *)infoDictionary {
    NSDictionary *original = %orig;
    
    // 移除 App Store 更新相關的鍵
    NSMutableDictionary *modified = [original mutableCopy];
    
    // 移除更新檢查相關的 key
    [modified removeObjectForKey:@"NSAppTransportSecurity"];
    [modified removeObjectForKey:@"UIAppFonts"];
    
    return modified;
}

%end

// ============================================================
// 方法 2: Hook UIApplication - 阻止更新彈窗
// ============================================================

%hook UIApplication

- (BOOL)openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options 
    completionHandler:(void (^)(BOOL))completion {
    
    // 攔截 App Store 連結
    if ([url.absoluteString containsString:@"itunes.apple.com"] ||
        [url.absoluteString containsString:@"apps.apple.com"] ||
        [url.absoluteString containsString:@"itms-apps"]) {
        
        NSLog(@"[NoUpdate] Blocked App Store URL: %@", url.absoluteString);
        
        if (completion) {
            completion(NO);
        }
        return YES; // 返回 YES 表示已處理，不進行實際打開
    }
    
    return %orig(url, options, completion);
}

%end

// ============================================================
// 方法 3: Hook NSUserDefaults - 阻止 App Store 檢查
// ============================================================

%hook NSUserDefaults

- (id)objectForKey:(NSString *)defaultName {
    // 阻止 Store 相關的 Key
    if ([defaultName containsString:@"Store"] || 
        [defaultName containsString:@"kSStore"] ||
        [defaultName containsString:@"com.apple.AppStore"]) {
        
        NSLog(@"[NoUpdate] Blocked NSUserDefaults key: %@", defaultName);
        return nil;
    }
    
    return %orig(defaultName);
}

%end

// ============================================================
// 方法 4: Hook NSURLSession - 阻擋 App Store API 請求
// ============================================================

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request 
    completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    
    NSString *url = request.URL.absoluteString;
    
    // 阻擋 Apple App Store API
    if ([url containsString:@"itunes.apple.com"] ||
        [url containsString:@"apps.apple.com"] ||
        [url containsString:@"Buy"] ||
        [url containsString:@"lookup"] ||
        [url containsString:@"softwareVersion"]) {
        
        NSLog(@"[NoUpdate] Blocked App Store API: %@", url);
        
        // 返回空響應
        NSData *emptyData = [NSData data];
        NSURLResponse *emptyResponse = [[NSHTTPURLResponse alloc] 
            initWithURL:request.URL 
            statusCode:404 
            HTTPVersion:@"1.1" 
            headerFields:@{}];
        
        completionHandler(emptyData, emptyResponse, nil);
        
        // 返回一個空任務
        return nil;
    }
    
    return %orig(request, completionHandler);
}

%end

// ============================================================
// 方法 5: Hook SKStoreProductViewController (如果有)
// ============================================================

%hook SKStoreProductViewController

- (void)loadProductWithParameters:(NSDictionary<NSString *,id> *)parameters 
    completionBlock:(void (^)(NSError * _Nullable))block {
    
    NSLog(@"[NoUpdate] Blocked SKStoreProductViewController load");
    
    // 返回錯誤阻止加載
    NSError *error = [NSError errorWithDomain:@"NoUpdateChecker" 
                                         code:404 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Update blocked"}];
    if (block) {
        block(error);
    }
    return;
}

%end

// ============================================================
// 初始化
// ============================================================

%ctor {
    NSLog(@"[NoUpdateChecker] Loaded - Update checks disabled");
    NSLog(@"[NoUpdateChecker] This tweak blocks iOS app update checks");
}