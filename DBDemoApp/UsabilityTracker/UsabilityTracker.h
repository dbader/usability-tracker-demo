//
//  UsabilityTracker.h
//  Daniel Bader
//
//  Created by Daniel Bader on 31.08.11.
//  Copyright 2011 Daniel Bader. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UsabilityTracker : NSObject <UIAlertViewDelegate>
+ (instancetype) sharedTracker;
- (void) enterView:(NSString *)viewName;
- (void) appActivate;
- (void) appDeactivate;
@end
