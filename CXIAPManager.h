//
//  CXIAPManager.h
//  TestFace2
//
//  Created by 曹想 on 2019/3/5.
//  Copyright © 2019 ShangHaiXinLaWangLuoKeji. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

typedef NS_ENUM(NSInteger, CXAPPurchType) {
     CXAPPurchSuccess = 0,       // 购买成功
     CXAPPurchFailed = 1,        // 购买失败
     CXAPPurchCancle = 2,        // 取消购买
     CXAPPurchVerFailed = 3,     // 订单校验失败
     CXAPPurchVerSuccess = 4,    // 订单校验成功
     CXAPPurchNotArrow = 5,      // 不允许内购
};

typedef void (^IAPCompletionHandle)( CXAPPurchType type,NSData *data);

NS_ASSUME_NONNULL_BEGIN

@interface CXIAPManager : NSObject

+ (instancetype)shareCXAPManager;

//开始内购
- (void)startPurchWithDict:(NSDictionary *)purch completeHandle:(IAPCompletionHandle)handle;

@end

NS_ASSUME_NONNULL_END
