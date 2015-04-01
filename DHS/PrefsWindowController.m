//
//  PrefsWindowController.m
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//
#import <Quartz/Quartz.h>
#import "PrefsWindowController.h"


@implementation PrefsWindowController

@synthesize fullScan;
@synthesize saveOutput;
@synthesize weakHijackers;

//automatically invoked when window is loaded
// ->center it
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //center window
    [[self window] center];
    
    return;
}

//'OK' button handler
// ->save prefs and close window
-(IBAction)closeWindow:(id)sender
{
    //save full scan flag
    self.fullScan = self.fullScanButton.state;
    
    //save weak hijacker flag
    self.weakHijackers = self.weakHijackerButton.state;
    
    //save save output flag
    self.saveOutput = self.saveOutputButton.state;

    //close
    [self.window close];
    
    //make un-modal
    [[NSApplication sharedApplication] stopModal];

    return;
}
@end
