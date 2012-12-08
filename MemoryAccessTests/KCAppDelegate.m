//
//  KCAppDelegate.m
//  MemoryAccessTests
//
//  Created by Kevin Conner on 12/2/12.
//  Copyright (c) 2012 Kevin Conner. All rights reserved.
//

#import "KCAppDelegate.h"
#import "KCMemoryAccessTests.h"

@implementation KCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    [KCMemoryAccessTests runTests];
    exit(0);
    
    return YES;
}

@end
