//
//  OTVideoCaptureSwift30Proxy.h
//  2.Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 20/09/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenTok/OpenTok.h>

@interface OTVideoCaptureSwift30Proxy: NSObject<OTVideoCapture>
@property(atomic, assign) id<OTVideoCaptureConsumer>videoCaptureConsumer;

- (id<OTVideoCapture>)videoCapture;
- (void)proxyInit;
- (void)proxyRelease;
- (int32_t)proxyStart;
- (int32_t)proxyStop;
- (BOOL)proxyIsStarted;
- (int32_t)proxySettings:(OTVideoFormat *)videoFormat;
@end
