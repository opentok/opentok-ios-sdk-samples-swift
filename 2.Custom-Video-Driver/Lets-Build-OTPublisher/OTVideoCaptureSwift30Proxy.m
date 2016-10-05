//
//  OTVideoCaptureSwift30Proxy.m
//  2.Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 20/09/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

#import "OTVideoCaptureSwift30Proxy.h"

@implementation OTVideoCaptureSwift30Proxy
- (void)initCapture {
    [self proxyInit];
}
- (void)releaseCapture {
    [self proxyRelease];
}
- (int32_t)startCapture {
    return [self proxyStart];
}
- (int32_t)stopCapture {
    return [self proxyStop];
}
- (BOOL)isCaptureStarted {
    return [self proxyIsStarted];
}
- (int32_t)captureSettings:(OTVideoFormat*)videoFormat {
    return [self proxySettings:videoFormat];
}

- (id<OTVideoCapture>)videoCapture {
    return self;
}

#pragma mark - Proxy Methods
- (void)proxyInit {}
- (void)proxyRelease {}
- (int32_t)proxyStart { return -1; }
- (int32_t)proxyStop { return -1; }
- (BOOL)proxyIsStarted{ return NO; }
- (int32_t)proxySettings:(OTVideoFormat *)videoFormat { return -1; }
@end
