//
//  PrefsWindowController.h
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PrefsWindowController : NSWindowController <NSWindowDelegate>
{
    
}

//buttons
@property (weak) IBOutlet NSButton *fullScanButton;
@property (weak) IBOutlet NSButton *weakHijackerButton;
@property (weak) IBOutlet NSButton *saveOutputButton;

//full scan
@property BOOL fullScan;

//weak hijackers
@property BOOL weakHijackers;

//save output
@property BOOL saveOutput;

/* METHODS */

//register default prefs
// ->only used if user hasn't set any
-(void)registerDefaults;

//load (persistence) preferences from file system
-(void)loadPreferences;

//'OK' button handler
// ->save prefs and close window
-(IBAction)closeWindow:(id)sender;

//button handler
// ->invoked when user checks/unchecks 'weak hijack detection' checkbox
-(IBAction)hijackDetectionOptions:(id)sender;

@end
