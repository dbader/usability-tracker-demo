//
//  DBFirstViewController.m
//  DBDemoApp
//
//  Created by Daniel Bader on 25.02.13.
//  Copyright (c) 2013 Daniel Bader. All rights reserved.
//

#import "DBFirstViewController.h"

@interface DBFirstViewController ()

@end

@implementation DBFirstViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[UsabilityTracker sharedTracker] enterView:NSStringFromClass([self class])];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
