//
//  CXIAPManager.m
//  TestFace2
//
//  Created by 曹想 on 2019/3/5.
//  Copyright © 2019 ShangHaiXinLaWangLuoKeji. All rig hts reserved.
//

#import "CXIAPManager.h"

//tmcq.zsdkgame.com/WebServer/taiwan_sdk/
//台湾服
//NSString * const autoURL = @"https://tmcq.zsdkgame.com/WebServer/taiwan_sdk/inApplePurchase/verifyXuding.php";//订阅画url
//NSString * const consumptionURL = @"https://tmcq.zsdkgame.com/WebServer/taiwan_sdk/inApplePurchase/verifyReceipt.php";//消耗型url


//测试
NSString * const autoURL = @"http://123.206.107.182/taiwan_sdk/inApplePurchase/verifyXuding.php";//订阅画url
NSString * const consumptionURL = @"http://123.206.107.182/taiwan_sdk/inApplePurchase/verifyReceipt.php";//消耗型url
NSString * const secretKey = @"98756131adf744218121bccce9e2a442";
@interface CXIAPManager ()<SKPaymentTransactionObserver,SKProductsRequestDelegate>

@property (nonatomic,copy) NSString * purchID;

@property (nonatomic,copy) IAPCompletionHandle handle;

@property (nonatomic,strong) NSDictionary * parmas;


@end

@implementation CXIAPManager

+(instancetype)shareCXAPManager{
    static CXIAPManager *IAPManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        IAPManager = [[CXIAPManager alloc] init];
    });
    return IAPManager;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        // 购买监听写在程序入口,程序挂起时移除监听,这样如果有未完成的订单将会自动执行并回调 paymentQueue:updatedTransactions:方法
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

#pragma mark - 🚪public  去苹果服务器请求产品信息
-(void)startPurchWithDict:(NSDictionary *)purch completeHandle:(IAPCompletionHandle)handle{
    if (purch.allKeys.count > 0) {
        self.parmas = purch;
        if ([purch objectForKey:@"productId"]) {
            if ([SKPaymentQueue canMakePayments]) {
                // 开始购买服务
                self.purchID = [purch objectForKey:@"productId"];
                self.handle = handle;
                NSSet *nsset = [NSSet setWithArray:@[self.purchID]];
                SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
                request.delegate = self;
                [request start];
            }else{
                [self handleActionWithType:CXAPPurchNotArrow data:nil];
            }
        }
    }
}

#pragma mark --收到产品返回信息 SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    NSArray *product = response.products;
    if([product count] <= 0){
#if DEBUG
        NSLog(@"--------------没有商品------------------");
#endif
        return;
    }
    
    SKProduct *p = nil;
    for(SKProduct *pro in product){
        if([pro.productIdentifier isEqualToString:self.purchID]){
            p = pro;
            break;
        }
    }
    
#if DEBUG
    NSLog(@"productID:%@", response.invalidProductIdentifiers);
    NSLog(@"产品付费数量:%lu",(unsigned long)[product count]);
    NSLog(@"%@",[p description]);
    NSLog(@"%@",[p localizedTitle]);
    NSLog(@"%@",[p localizedDescription]);
    NSLog(@"%@",[p price]);
    NSLog(@"%@",[p productIdentifier]);
    NSLog(@"发送购买请求");
#endif
    //发送内购请求
    SKPayment *payment = [SKPayment paymentWithProduct:p];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    [CXLoadingHud showHud];
}


//请求失败
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
#if DEBUG
    [CXLoadingHud dismissHud];
    NSLog(@"------------------错误-----------------:%@", error);
#endif
}

- (void)requestDidFinish:(SKRequest *)request{
#if DEBUG
    NSLog(@"------------反馈信息结束-----------------");
#endif
}

#pragma mark - SKPaymentTransactionObserver // 监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    [CXLoadingHud dismissHud];
    for (SKPaymentTransaction *tran in transactions) {
        //NSLog(@"%ld====",(long)tran.transactionState);
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased: //交易完成
                //订阅特殊处理
                if(tran.originalTransaction){
                    //如果是自动续费的订单originalTransaction会有内容
                    NSLog(@"自动续费的订单,originalTransaction = %@",tran.originalTransaction.transactionIdentifier);
                    //tran.originalTransaction.transactionIdentifier
                    //SKPaymentTransaction
                    [self completeTransaction:tran isAutomatically:YES];
                    //[self verifyPurchaseWithPaymentTransaction:tran isTestServer:NO];
                }else{
                    //普通购买，以及 第一次购买 自动订阅
                   // NSLog(@"%@-------",tran.transactionIdentifier);
                    [self completeTransaction:tran isAutomatically:NO];
                }
                
                break;
            case SKPaymentTransactionStatePurchasing://商品添加进列表
#if DEBUG
                
                //NSLog(@"%ld====",tran.error.code);
                //NSLog(@"%@====",[[NSString alloc]initWithData:tran.payment.requestData encoding:NSUTF8StringEncoding]);
                //[TDGAVirtualCurrency onChargeRequst:@"" iapId:@"" currencyAmount:0 currencyType:@"" virtualCurrencyAmount:0 paymentType:@""];
#endif
                break;
            case SKPaymentTransactionStateRestored://购买过
#if DEBUG
                NSLog(@"已经购买过商品");
#endif
                // 消耗型不支持恢复购买
                //[[SKPaymentQueue defaultQueue] finishTransaction:tran];
                break;
            case SKPaymentTransactionStateFailed://交易失败
                  NSLog(@"%@====",tran.error);
                //SKErrorUnknown
                [self failedTransaction:tran];
                
                break;
            default:
                break;
        }
    }
}


#pragma mark - 🍐delegate
// 交易结束
- (void)completeTransaction:(SKPaymentTransaction *)transaction isAutomatically:(BOOL)isAutomatically{
    // Your application should implement these two methods.
    //    票据的校验是保证内购安全完成的非常关键的一步，一般有三种方式：
    //    1、服务器验证，获取票据信息后上传至信任的服务器，由服务器完成与App Store的验证（提倡使用此方法，比较安全）
    //    2、本地票据校验
    //    3、本地App Store请求验证
    
    //    NSString * productIdentifier = transaction.payment.productIdentifier;
    //    NSString * receipt = [transaction.transactionReceipt base64EncodedString];
    //    if ([productIdentifier length] > 0) {
    //
    //    }
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    // 向自己的服务器验证购买凭证
    //NSError *error;
    //转化为base64字符串
    NSString *receiptString=[receipt base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    //除去receiptdata中的特殊字符
    NSString *receipt1=[receiptString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    NSString *receipt2=[receipt1 stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    NSString *receipt3=[receipt2 stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
    //最终将这个receipt3的发送给服务器去验证就没问题啦！
    //自动订阅（自动续费月卡）需要多加一个参数
    
    NSString * product_id = transaction.payment.productIdentifier;
    NSString * transaction_id = transaction.transactionIdentifier;
    
    
    NSMutableDictionary * requestContents = [[NSMutableDictionary alloc]init];
    //订阅特殊处理
    if (isAutomatically) {
         //如果是自动续费的订单originalTransaction会有内容
        NSString * transaction_id2 = transaction.originalTransaction.transactionIdentifier;
        NSString * transaction_id = transaction.transactionIdentifier;
        [requestContents addEntriesFromDictionary:@{@"receipt": receipt3,@"password":secretKey,@"product_id":product_id,@"transaction_id":transaction_id,@"originalTransaction":transaction_id2}];
    }else{
        if (self.parmas.allKeys.count > 0) {
            [requestContents addEntriesFromDictionary:@{@"receipt": receipt3,@"uid":self.parmas[@"uid"],@"amount":self.parmas[@"amount"],@"actorid":self.parmas[@"userRoleId"],@"server":self.parmas[@"serverId"],@"order_no":self.parmas[@"cpOrderNo"],@"password":secretKey,@"product_id":product_id,@"transaction_id":transaction_id}];
        }
    }
    
    NSString * parameters = [self parameters:requestContents];
    NSString * url = isAutomatically ? autoURL : consumptionURL;
    NSURL *storeURL = [NSURL URLWithString:url];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:[parameters dataUsingEncoding:NSUTF8StringEncoding]];
    [storeRequest setTimeoutInterval:30];
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:storeRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //服务器返回的responseObject是gbk编码的字符串，通过gbk编码转码就行了，转码方法如下：
        NSString*gbkStr = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        //转码之后再转utf8解析
        NSDictionary * jsonDict = [NSJSONSerialization JSONObjectWithData:[gbkStr dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
      
        if (jsonDict.allKeys.count > 0) {
            if ([[jsonDict objectForKey:@"code"]intValue] == 0) {
                //[CXLoadingHud showHudWithText:@"购买成功" delay:2];
                NSDictionary * dataDict = jsonDict[@"data"];
                [[CXInformationCollect collectInfo]fb_mobile_purchase:dataDict[@"amount"] currency:@""];
                [[CXInformationCollect collectInfo]af_purchase:@{@"amount":dataDict[@"amount"]}];
            }else if ([[jsonDict objectForKey:@"code"]intValue] == 1){
                [CXLoadingHud showHudWithText:@"服务器验签失败" delay:2];
                
            }
        }
        
    }];
    
    [dataTask resume];

    //本地像苹果app store验证，上面是像自己的服务器验证
    //[self verifyPurchaseWithPaymentTransaction:transaction isTestServer:NO];
    // 验证成功与否都注销交易,否则会出现虚假凭证信息一直验证不通过,每次进程序都得输入苹果账号
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    //[self verifyPurchaseWithPaymentTransaction:transaction isTestServer:NO];
}

-(NSString *)parameters:(NSDictionary *)parameters
{
    //创建可变字符串来承载拼接后的参数
    NSMutableString *parameterString = [NSMutableString new];
    //获取parameters中所有的key
    NSArray *parameterArray = parameters.allKeys;
    for (int i = 0;i < parameterArray.count;i++) {
        //根据key取出所有的value
        id value = parameters[parameterArray[i]];
        //把parameters的key 和 value进行拼接
        NSString *keyValue = [NSString stringWithFormat:@"%@=%@",parameterArray[i],value];
        if (i == parameterArray.count || i == 0) {
            //如果当前参数是最后或者第一个参数就直接拼接到字符串后面，因为第一个参数和最后一个参数不需要加 “&”符号来标识拼接的参数
            [parameterString appendString:keyValue];
        }else
        {
            //拼接参数， &表示与前面的参数拼接
            [parameterString appendString:[NSString stringWithFormat:@"&%@",keyValue]];
        }
    }
    return parameterString;
}


// 交易失败
- (void)failedTransaction:(SKPaymentTransaction *)transaction{
    if (transaction.error.code != SKErrorPaymentCancelled) {
        [self handleActionWithType:CXAPPurchFailed data:nil];
    }else{
        [self handleActionWithType:CXAPPurchCancle data:nil];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)verifyPurchaseWithPaymentTransaction:(SKPaymentTransaction *)transaction isTestServer:(BOOL)flag{
    //交易验证
    NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
    
    if(!receipt){
        // 交易凭证为空验证失败
        [self handleActionWithType:CXAPPurchVerFailed data:nil];
        return;
    }
    // 购买成功将交易凭证发送给服务端进行再次校验
    // [self handleActionWithType:CXAPPurchSuccess data:receipt];
    
    NSError *error;
    NSDictionary *requestContents = @{
                                      @"receipt-data": [receipt base64EncodedStringWithOptions:0]
                                      };
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                          options:0
                                                            error:&error];
    
    if (!requestData) { // 交易凭证为空验证失败
        [self handleActionWithType:CXAPPurchVerFailed data:nil];
        return;
    }
    
    //In the test environment, use https://sandbox.itunes.apple.com/verifyReceipt
    //In the real environment, use https://buy.itunes.apple.com/verifyReceipt
    
    NSString *serverString = @"https://buy.itunes.apple.com/verifyReceipt";
    if (flag) {
        serverString = @"https://sandbox.itunes.apple.com/verifyReceipt";
    }
    NSURL *storeURL = [NSURL URLWithString:serverString];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   // 无法连接服务器,购买校验失败
                                   [self handleActionWithType:CXAPPurchVerFailed data:nil];
                               } else {
                                   NSError *error;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                   if (!jsonResponse) {
                                       // 苹果服务器校验数据返回为空校验失败
                                       [self handleActionWithType:CXAPPurchVerFailed data:nil];
                                   }
                                   // 先验证正式服务器,如果正式服务器返回21007再去苹果测试服务器验证,沙盒测试环境苹果用的是测试服务器
                                   NSString *status = [NSString stringWithFormat:@"%@",jsonResponse[@"status"]];
                                   if (status && [status isEqualToString:@"21007"]) {
                                       [self verifyPurchaseWithPaymentTransaction:transaction isTestServer:YES];
                                   }else if(status && [status isEqualToString:@"0"]){
                                       [self handleActionWithType:CXAPPurchVerSuccess data:nil];
                                   }
#if DEBUG
                                   NSLog(@"----验证结果 %@",jsonResponse);
#endif
                               }
                           }];
    
    
    // 验证成功与否都注销交易,否则会出现虚假凭证信息一直验证不通过,每次进程序都得输入苹果账号
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}


#pragma mark - 🔒private
- (void)handleActionWithType:(CXAPPurchType)type data:(NSData *)data{
#if DEBUG
    switch (type) {
        case CXAPPurchSuccess:
            NSLog(@"购买成功");
            break;
        case CXAPPurchFailed:
            NSLog(@"购买失败");
            break;
        case CXAPPurchCancle:
            NSLog(@"用户取消购买");
            break;
        case CXAPPurchVerFailed:
            NSLog(@"订单校验失败");
            break;
        case CXAPPurchVerSuccess:
            NSLog(@"订单校验成功");
            break;
        case CXAPPurchNotArrow:
            NSLog(@"不允许程序内付费");
            break;
        default:
            break;
    }
#endif
    if(_handle){
        _handle(type,data);
    }
}

@end
