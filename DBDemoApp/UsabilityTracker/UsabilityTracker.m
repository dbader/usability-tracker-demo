//
//  UsabilityTracker.m
//  Daniel Bader
//
//  Created by Daniel Bader on 31.08.11.
//  Copyright 2011 Daniel Bader. All rights reserved.
//

/** A circular buffer used to implement the event store for view changes. */
@interface CircularBuffer : NSObject {
@private
    NSUInteger maxSize;
}
@property (readonly) NSMutableArray *items;
@end

@implementation CircularBuffer

- (id) initWithCapacity:(NSUInteger)capacity {
    self = [super init];
    if (self) {
        maxSize = capacity;
        _items = [[NSMutableArray alloc] initWithCapacity:maxSize];
    }
    return self;
}

- (void) addObject:(id)obj {
    if ([_items count] == maxSize) {
        [_items removeLastObject];
    }

    [_items insertObject:obj atIndex:0];
}

- (void) clear {
    [_items removeAllObjects];
}

@end


/** A value object that represents a View Change Event. */
@interface ViewChangeEvent : NSObject
@property (assign) long retentionTime;
@property (copy) NSString *viewName;
@end

@implementation ViewChangeEvent
@synthesize retentionTime;
@synthesize viewName;

- (NSString *) description {
    return [NSString stringWithFormat:@"%@<%lu, %@>", NSStringFromClass([self class]), retentionTime, viewName];
}

@end


/**
 * The `meat` of the Usability Tracker. Does the following things:
 *
 * - Tracks View Change Events
 * - checks for Low Discoverability Issues
 * - shows an `automatic questionnaire` if a LD issue is detected
 * - writes a textual log file to the app's Documents folder
 */
@interface UsabilityTracker () {
@private
    CircularBuffer *viewTransitionHistory;
    NSFileHandle *trackerFile;
    ViewChangeEvent *currentView;
    long baseTime;
    long viewBaseTime;
}
- (void) log:(NSString *)text;
- (void) showQuestionnaireDialog;
- (BOOL) hasLowRetentionTimes;
- (BOOL) hasLoops;
@end

static int const kUTEventHistorySize = 6;
static float const kUTLowRetentionTimeThreshold = 6.0f; // seconds

@implementation UsabilityTracker

+ (instancetype) sharedTracker {
    static UsabilityTracker *sharedTracker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedTracker = [[self alloc] init];
    });
    return sharedTracker;
}

- (id) init {
    self = [super init];
    if (self) {
        viewTransitionHistory = [[CircularBuffer alloc] initWithCapacity:kUTEventHistorySize];
        baseTime = (long) [[NSDate date] timeIntervalSince1970];

        NSNumber *utcTimestamp = [NSNumber numberWithLong:baseTime];
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *filename = [NSString stringWithFormat:@"UsabilityTracker-%@-%@.txt",
                                                        [UIDevice currentDevice].uniqueIdentifier, utcTimestamp];
        NSString *filePath = [documentsPath stringByAppendingPathComponent:filename];

        [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        trackerFile = [NSFileHandle fileHandleForWritingAtPath:filePath];
    }
    return self;
}

- (BOOL) hasLowRetentionTimes {
    int numSamples = 0;
    int numBelowThreshold = 0;

    for (ViewChangeEvent *transition in viewTransitionHistory.items) {
        numSamples++;
        if (transition.retentionTime < kUTLowRetentionTimeThreshold) {
            numBelowThreshold++;
        }
    }

    if (numSamples >= kUTEventHistorySize && numSamples == numBelowThreshold) {
        return YES;
    }

    return NO;
}

- (BOOL) hasLoops {
    for (ViewChangeEvent *transition in viewTransitionHistory.items) {
        for (ViewChangeEvent *innerTransition in viewTransitionHistory.items) {
            if (innerTransition == transition) {
                continue;
            }

            if ([innerTransition.viewName isEqualToString:transition.viewName]) {
                return YES;
            }
        }
    }

    return NO;
}

- (void) enterView:(NSString *)viewName {
    NSLog(@"UsabilityTracker: transition to view \"%@\"", viewName);

    long utcNow = (long) [[NSDate date] timeIntervalSince1970];

    if (currentView) {
        currentView.retentionTime = utcNow - viewBaseTime;
        [viewTransitionHistory addObject:currentView];
    }

    currentView = [[ViewChangeEvent alloc] init];
    currentView.viewName = viewName;
    viewBaseTime = utcNow;

    [self log:viewName];

    BOOL hasLowRetentionTimes = [self hasLowRetentionTimes];
    BOOL hasLoops = [self hasLoops];

    if (hasLowRetentionTimes) {
        NSLog(@"Low Retention Times detected");
    }

    if (hasLoops) {
        NSLog(@"Navigational Loop(s) detected");
    }

    if (hasLowRetentionTimes && hasLoops) {
        NSLog(@"Low Discoverability detected");
        [self showQuestionnaireDialog];
    }
}

- (void) appActivate {
    [self log:@"_ACTIVATE_"];
}

- (void) appDeactivate {
    [self log:@"_DEACTIVATE_"];
}

- (void) log:(NSString *)text {
    NSNumber *utcTimestamp = [NSNumber numberWithLong:(long) [[NSDate date] timeIntervalSince1970]];
    NSString *writeString = [NSString stringWithFormat:@"%@,%@\n", utcTimestamp, text];
//    NSLog(@"%@", writeString);
    [trackerFile writeData:[writeString dataUsingEncoding:NSUTF8StringEncoding]];
    [trackerFile synchronizeFile];
}

- (void) showQuestionnaireDialog {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Questionnaire"
                                                        message:@"Just now a required function is hard to find:\n\n"
                                                                        "--          -            0          +          ++\n\n\n"
                                                       delegate:self
                                              cancelButtonTitle:nil otherButtonTitles:@"Continue", nil];

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(12.0, 125, 260.0, 25.0)];
    slider.minimumValue = 1;
    slider.maximumValue = 5;
    slider.value = 3;
    [alertView addSubview:slider];

    alertView.tag = 1;

    [alertView show];
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 1) {
        //
        // Slider view
        //
        UISlider *slider = [[alertView subviews] lastObject];

        NSString *history = [NSString string];

        for (ViewChangeEvent *transition in viewTransitionHistory.items) {
            history = [history stringByAppendingFormat:@"%lu:%@,", transition.retentionTime, transition.viewName];
        }

        [viewTransitionHistory clear];

        // Strip the trailing comma
        history = [history stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
        [self log:[NSString stringWithFormat:@"_QUESTIONNAIRE1_,%.2f,%@", slider.value, history]];

        if (slider.value >= 3.5) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"I'm looking for:"
                                                            message:@"\n\n\n"
                                                           delegate:self
                                                  cancelButtonTitle:nil otherButtonTitles:@"Continue", nil];
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(12, 60, 260, 25)];
            textField.backgroundColor = [UIColor whiteColor];
            textField.borderStyle = UITextBorderStyleRoundedRect;
            [textField becomeFirstResponder];
            [alert addSubview:textField];
            alert.tag = 2;
            [alert show];
        }
    } else if (alertView.tag == 2) {
        //
        // Textfield view
        //
        UITextField *textField = [[alertView subviews] lastObject];
        [self log:[NSString stringWithFormat:@"_QUESTIONNAIRE2_,'%@'", textField.text]];
    }
}

@end
