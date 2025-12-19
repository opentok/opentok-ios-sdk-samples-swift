//
//  OTCustomSession.m
//  VonageMeetApp
//
//  Created by Jerónimo Valli on 7/10/23.
//

#import "OTCustomSession.h"

@interface OTSession ()
- (void)setApiRootURL:(NSURL*)aURL;
@end

@implementation OTCustomSession
- (void)setApiRootURL:(NSURL *)aURL {
    [super setApiRootURL:aURL];
}
@end
