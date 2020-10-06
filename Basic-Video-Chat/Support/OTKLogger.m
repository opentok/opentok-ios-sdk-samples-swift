//
//  OTKLogger.m
//  Basic-Video-Chat
//
//  Created by rpc on 03/07/2019.
//  Copyright © 2019 tokbox. All rights reserved.
//

#import "OTKLogger.h"

@interface OpenTokObjC : NSObject
+ (void)setLogBlockQueue:(dispatch_queue_t)queue;
+ (void)setLogBlock:(void (^)(NSString* message, void* arg))logBlock;
@end

static dispatch_queue_t _logQueue;

@implementation OTKLogger
+ (void)initialize {
    _logQueue = dispatch_queue_create("log-queue", DISPATCH_QUEUE_SERIAL);
    [OpenTokObjC setLogBlockQueue:_logQueue];
    [OpenTokObjC setLogBlock:^(NSString *message, void *arg) {
        NSLog(@"%@", message);
    }];
}
@end


