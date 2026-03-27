/*
 * NoUpdateChecker.js
 * Frida 腳本 - 阻止 iOS App 檢查更新
 * 
 * 使用方法：
 * frida -U -f com.target.app -l NoUpdateChecker.js
 * 
 * 或者附加到運行中的 App：
 * frida -U -n "TargetApp" -l NoUpdateChecker.js
 */

console.log("[*] NoUpdateChecker loaded");

// ============================================================
// 方法 1: Hook NSURLSession - 阻擋 App Store API
// ============================================================

var NSURLSession = ObjC.classes.NSURLSession;
var NSURLSession$sharedSession = NSURLSession.sharedSession;

if (NSURLSession) {
    Interceptor.replace(NSURLSession['- dataTaskWithRequest:completionHandler:'].implementation, 
        new NativeCallback(function(request, completionHandler) {
            var url = request.URL().absoluteString();
            
            // 阻擋 Apple App Store API
            if (url.indexOf("itunes.apple.com") !== -1 ||
                url.indexOf("apps.apple.com") !== -1 ||
                url.indexOf("lookup") !== -1 ||
                url.indexOf("softwareVersion") !== -1) {
                
                console.log("[NoUpdate] Blocked: " + url);
                
                // 返回空的 404 響應
                var NSData = ObjC.classes.NSData;
                var NSHTTPURLResponse = ObjC.classes.NSHTTPURLResponse;
                var response = NSHTTPURLResponse.alloc().initWithURL_statusCode_HTTPVersion_headerFields(
                    request.URL(), 404, "1.1", NSDictionary.alloc().init()
                );
                
                completionHandler(NSData.data(), response, NULL);
                return;
            }
            
            return originalDataTask(request, completionHandler);
        }, 'void', ['pointer', 'pointer'])
    );
}

// 保存原始方法
var originalDataTask = NSURLSession['- dataTaskWithRequest:completionHandler:'].implementation;

// ============================================================
// 方法 2: Hook NSBundle - 阻止更新信息獲取
// ============================================================

var NSBundle = ObjC.classes.NSBundle;

if (NSBundle) {
    var originalInfoDictionary = NSBundle['- infoDictionary'].implementation;
    
    Interceptor.replace(originalInfoDictionary, new NativeCallback(function(self, sel) {
        var result = originalInfoDictionary.call(self, sel);
        
        if (result) {
            // 移除更新相關的 key
            // 這裡只是示例，實際可能需要更精確
            console.log("[NoUpdate] infoDictionary accessed");
        }
        
        return result;
    }, 'pointer', ['pointer', 'pointer'])
    );
}

// ============================================================
// 方法 3: Hook UIApplication - 阻止打開 App Store
// ============================================================

var UIApplication = ObjC.classes.UIApplication;

if (UIApplication) {
    var originalOpenURL = UIApplication['- openURL:options:completionHandler:'];
    
    if (originalOpenURL) {
        Interceptor.replace(originalOpenURL.implementation, new NativeCallback(function(self, sel, url, options, completion) {
            var urlStr = url.toString();
            
            // 攔截 App Store 連結
            if (urlStr.indexOf("itunes.apple.com") !== -1 ||
                urlStr.indexOf("apps.apple.com") !== -1 ||
                urlStr.indexOf("itms-apps") !== -1) {
                
                console.log("[NoUpdate] Blocked URL: " + urlStr);
                
                if (completion) {
                    completion(false);
                }
                return;
            }
            
            return originalOpenURL.call(self, sel, url, options, completion);
        }, 'void', ['pointer', 'pointer', 'pointer', 'pointer', 'pointer'])
        );
    }
}

// ============================================================
// 方法 4: Hook SKStoreProductViewController
// ============================================================

var SKStoreProductViewController = ObjC.classes.SKStoreProductViewController;

if (SKStoreProductViewController) {
    var originalLoadProduct = SKStoreProductViewController['- loadProductWithParameters:completionBlock:'];
    
    if (originalLoadProduct) {
        Interceptor.replace(originalLoadProduct.implementation, new NativeCallback(function(self, sel, parameters, completionBlock) {
            console.log("[NoUpdate] Blocked SKStoreProductViewController");
            
            if (completionBlock) {
                var NSError = ObjC.classes.NSError;
                var error = NSError.errorWithDomain_code_userInfo(
                    ObjC.classes.NSString.alloc().initWithUTF8String("NoUpdateChecker"),
                    404,
                    NSDictionary.alloc().init()
                );
                completionBlock(error);
            }
        }, 'void', ['pointer', 'pointer', 'pointer', 'pointer'])
        );
    }
}

// ============================================================
// 方法 5: 阻止 App Store 服務 (NSUserDefaults)
// ============================================================

var NSUserDefaults = ObjC.classes.NSUserDefaults;

if (NSUserDefaults) {
    var originalObjectForKey = NSUserDefaults['- objectForKey:'];
    
    Interceptor.replace(originalObjectForKey.implementation, new NativeCallback(function(self, sel, key) {
        var keyStr = key.toString();
        
        // 阻止 Store 相關的 Key
        if (keyStr.indexOf("Store") !== -1 || 
            keyStr.indexOf("kSStore") !== -1 ||
            keyStr.indexOf("com.apple.AppStore") !== -1) {
            
            console.log("[NoUpdate] Blocked NSUserDefaults key: " + keyStr);
            return NULL;
        }
        
        return originalObjectForKey.call(self, sel, key);
    }, 'pointer', ['pointer', 'pointer'])
    );
}

console.log("[*] NoUpdateChecker active - Update checks will be blocked");