//
//  OTCustomSession.h
//  VonageMeetApp
//
//  Created by Jerónimo Valli on 7/10/23.
//

#ifndef OTCustomSession_h
#define OTCustomSession_h

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>

@interface OTCustomSession : OTSession
- (void)setApiRootURL:(NSURL*)aURL;
@end

#endif /* OTCustomSession_h */
