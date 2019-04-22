//
//  PrefsWindowController.m
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//
#import "Consts.h"
#import "Utilities.h"
#import <Quartz/Quartz.h>
#import "PrefsWindowController.h"


@implementation PrefsWindowController

@synthesize fullScan;
@synthesize saveOutput;
@synthesize weakHijackers;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//automatically invoked when window is loaded
// ->center it
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //no dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //check if 'full scan' button should be selected
    if(YES == self.fullScan)
    {
        //set
        self.fullScanButton.state = STATE_ENABLED;
    }
    
    //check if 'weak hijack detection' button should be selected
    if(YES == self.weakHijackers)
    {
        //set
        self.weakHijackerButton.state = STATE_ENABLED;
    }
    
    //check if 'save output' button should be selected
    if(YES == self.saveOutput)
    {
        //set
        self.saveOutputButton.state = STATE_ENABLED;
    }

    return;
}

//register default prefs
// ->only used if user hasn't set any
-(void)registerDefaults
{
    //set defaults
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{PREF_FULL_SYSTEM_SCAN:@NO, PREF_WEAK_HIJACKER_DETECTION:@NO, PREF_SAVE_OUTPUT:@NO}];
    
    return;
}

//load (persistence) preferences from file system
-(void)loadPreferences
{
    //user defaults
    NSUserDefaults* defaults = nil;
    
    //init
    defaults = [NSUserDefaults standardUserDefaults];
    
    //load prefs
    // ->won't be any until user set some...
    if(nil != defaults)
    {
        //load 'full system scan'
        if(nil != [defaults objectForKey:PREF_FULL_SYSTEM_SCAN])
        {
            //save
            self.fullScan = [defaults boolForKey:PREF_FULL_SYSTEM_SCAN];
        }
        
        //load 'weak hijacker detection'
        if(nil != [defaults objectForKey:PREF_WEAK_HIJACKER_DETECTION])
        {
            //save
            self.weakHijackers = [defaults boolForKey:PREF_WEAK_HIJACKER_DETECTION];
        }
        
        //load 'save output'
        if(nil != [defaults objectForKey:PREF_SAVE_OUTPUT])
        {
            //save
            self.saveOutput = [defaults boolForKey:PREF_SAVE_OUTPUT];
        }
    }
    
    return;
}

//'weak hijacker detection' checkbox handler
// ->invoked when user checks/unchecks 'weak hijack detection' checkbox
-(IBAction)hijackDetectionOptions:(id)sender
{
    //alert
    NSAlert* detectionAlert = nil;
    
    //check if user clicked (on)
    if(NSOnState == ((NSButton*)sender).state)
    {
        //alloc/init alert
        detectionAlert = [NSAlert alertWithMessageText:@"This might produce false positives" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"...please consult an expert if any results are found!"];
        
        //show it
        [detectionAlert runModal];
    }
    
    return;
}

//'OK' button handler
// ->save prefs and close window
-(IBAction)closeWindow:(id)sender
{
    //save prefs
    [self savePrefs];
    
    //close
    [self.window close];
    
    //make un-modal
    [[NSApplication sharedApplication] stopModal];

    return;
}

//save preferences
-(void)savePrefs
{
    //user defaults
    NSUserDefaults* defaults = nil;
    
    //init
    defaults = [NSUserDefaults standardUserDefaults];

    //save full scan flag
    self.fullScan = self.fullScanButton.state;
    
    //save weak hijacker flag
    self.weakHijackers = self.weakHijackerButton.state;
    
    //save save output flag
    self.saveOutput = self.saveOutputButton.state;

    //save 'show trusted items'
    [defaults setBool:self.fullScan forKey:PREF_FULL_SYSTEM_SCAN];
    
    //save 'disable vt queries'
    [defaults setBool:self.weakHijackers forKey:PREF_WEAK_HIJACKER_DETECTION];
    
    //save 'save output'
    [defaults setBool:self.saveOutput forKey:PREF_SAVE_OUTPUT];
    
    //flush/save
    [defaults synchronize];
    
    return;
}

@end
