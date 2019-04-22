//
//  AppDelegate.m
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import "Consts.h"
#import "Binary.h"
#import "Scanner.h"
#import "Exception.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "PrefsWindowController.h"

@implementation AppDelegate

@synthesize window;
@synthesize friends;
@synthesize scanButton;
@synthesize initialized;
@synthesize scannerThread;
@synthesize tableContents;
@synthesize versionString;
@synthesize scanButtonLabel;
@synthesize resultsTableView;
@synthesize progressIndicator;
@synthesize aboutWindowController;
@synthesize prefsWindowController;
@synthesize vulnerableAppHeaderIndex;


//center window
// ->also make front
-(void)awakeFromNib
{
    //center once!
    if(YES != self.initialized)
    {
        //center
        [self.window center];
        
        //set flag
        self.initialized = YES;
        
        //disable highlighting
        [self.resultsTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    }
    
    return;
}

//automatically invoked
// init stuffz!
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    //first thing...
    // ->install exception handlers!
    installExceptionHandlers();
    
    //alloc table array
    tableContents = [[NSMutableArray alloc] init];
    
    //center window
    [[self window] center];
    
    //first time run?
    // show thanks to friends window!
    // note: on close, invokes method to show main window
    if(YES != [[NSUserDefaults standardUserDefaults] boolForKey:NOT_FIRST_TIME])
    {
        //set key
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:NOT_FIRST_TIME];
        
        //front
        [self.friends makeKeyAndOrderFront:self];
        
        //front
        [NSApp activateIgnoringOtherApps:YES];
        
        //make first responder
        // calling this without a timeout sometimes fails :/
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            
            //and make it first responder
            [self.friends makeFirstResponder:[self.friends.contentView viewWithTag:1]];
            
        });
        
        //close after 3 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            //close
            [self hideFriends:nil];
            
        });
    }
    
    //make main window active/front
    else
    {
        //make it key window
        [self.window makeKeyAndOrderFront:self];
        
        //make window front
        [NSApp activateIgnoringOtherApps:YES];
        
    }
    
    //check that OS is supported
    if(YES != isSupportedOS())
    {
        //show alert
        [self showUnsupportedAlert];
        
        //exit
        exit(0);
    }
    
    //init table
    [self initTable];
    
    //register for hotkey presses
    [self registerKeypressHandler];
    
    //init mouse-over areas
    [self initTrackingAreas];
    
    //init index of 'Vulnerable Applications' header row
    vulnerableAppHeaderIndex = 4;
    
    //reload table
    [self.resultsTableView reloadData];
    
    //hide status msg
    // ->when user clicks scan, will show up..
    [self.statusText setStringValue:@""];
    
    //hide progress indicator
    self.progressIndicator.hidden = YES;
    
    //init button label
    // ->start scan
    [self.scanButtonLabel setStringValue:START_SCAN];
    
    //set version info
    self.versionString.stringValue = [NSString stringWithFormat:@"version %@", getAppVersion()];
    
    //dark mode
    // set version to light
    if(YES == isDarkMode())
    {
        //set overlay's view color to gray
        self.versionString.textColor = NSColor.lightGrayColor;
    }
    //light mode
    // set overlay to gray
    else
    {
        //set to gray
        self.versionString.textColor = NSColor.grayColor;
    }
    
    //set delegate
    // ->ensures our 'windowWillClose' method, which has logic to fully exit app
    self.window.delegate = self;
    
    //alloc/init prefs
    prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"PrefsWindow"];
    
    //register defaults
    [self.prefsWindowController registerDefaults];
    
    //load prefs
    [self.prefsWindowController loadPreferences];
    
    /*
    
    Scanner* scannerObj = [[Scanner alloc] init];
    
    NSString* binaryPath = @"/Applications/GPG Keychain.app/Contents/MacOS/GPG Keychain";
        //@"/Applications/Xcode.app/Contents/Developer/usr/bin/copySceneKitAssets";
        //@"/Applications/Wireshark.app/Contents/Resources/bin/capinfos-bin";
        //@"/Applications/Adium.app/Contents/MacOS/Adium";
        //@"/Applications/Xcode.app/Contents/PlugIns/IDEiOSSupportCore.ideplugin/Contents/MacOS/IDEiOSSupportCore";
        //@"/Library/Services/GPGServices.service/Contents/MacOS/GPGServices";
        //@"/Applications/Adobe Photoshop CC 2014/Adobe Photoshop CC 2014.app/Contents/MacOS/Adobe Photoshop CC 2014"
    
    Binary* binary = [[Binary alloc] initWithPath:binaryPath];

    //scan
    [scannerObj scanBinary:binary];
     
    */
     
    
    
    
//bail
bail:
    
    return;
}


//init tracking areas for buttons
// ->provide mouse over effects
-(void)initTrackingAreas
{
    //tracking area for buttons
    NSTrackingArea* trackingArea = nil;
    
    //init tracking area
    // ->for scan button
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self.scanButton bounds] options:(NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:self.scanButton.tag]}];
    
    //add tracking area to scan button
    [self.scanButton addTrackingArea:trackingArea];
    
    //init tracking area
    // ->for preference button
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self.showPreferencesButton bounds] options:(NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:self.showPreferencesButton.tag]}];
    
    //add tracking area to pref button
    [self.showPreferencesButton addTrackingArea:trackingArea];
    
    //init tracking area
    // ->for logo button
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self.logoButton bounds] options:(NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:@{@"tag":[NSNumber numberWithUnsignedInteger:self.logoButton.tag]}];
    
    //add tracking area to logo button
    [self.logoButton addTrackingArea:trackingArea];
    
    return;
}

//automatically invoked when window is un-minimized
// since the progress indicator is stopped (bug?), restart it
-(void)windowDidDeminiaturize:(NSNotification *)notification
{
    //make sure scan is going on
    // ->and then restart spinner
    if(YES == [self.scannerThread isExecuting])
    {
        //show
        [self.progressIndicator setHidden:NO];
        
        //start spinner
        [self.progressIndicator startAnimation:nil];
    }
    
    //scan pau
    // ->make sure spinner is hidden
    else
    {
        //stop spinner
        [self.progressIndicator stopAnimation:nil];
        
        //hide progress indicator
        self.progressIndicator.hidden = YES;
    }
    
    return;
}

//display alert about OS not being supported
-(void)showUnsupportedAlert
{
    //alert box
    NSAlert* fullScanAlert = nil;
    
    //alloc/init alert
    fullScanAlert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"OS X %@ is not officially supported", [[NSProcessInfo processInfo] operatingSystemVersionString]] defaultButton:@"Ok" alternateButton:nil otherButton:nil informativeTextWithFormat:@"sorry for the inconvenience!"];
    
    //and show it
    [fullScanAlert runModal];
    
    return;
}

//table delegate
// ->return number of rows
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.tableContents.count;
}

//table delegate method
// ->return populated cell for row
-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    //binary object
    Binary* binary = nil;
    
    //details
    NSString* details = nil;
    
    //detailed text field
    NSTextField* detailedTextField = nil;
    
    //table cell
    NSTableCellView *tableCell = nil;
    
    //tracking area
    NSTrackingArea* trackingArea = nil;
    
    //flag indicating row has tracking area
    // ->ensures we don't add 2x
    BOOL hasTrackingArea = NO;
    
    //grab row item from backing table array
    id rowContents = self.tableContents[row];
    
    //handle header ('group') rows
    if(YES == [self tableView:tableView isGroupRow:row])
    {
        //make a group cell
        tableCell = [tableView makeViewWithIdentifier:@"GroupCell" owner:self];
        if(nil == tableCell)
        {
            //bail
            goto bail;
        }
        
        //set it's text
        [tableCell.textField setStringValue:rowContents];
        
        //header row for 'Hijack Applications'
        if(YES == [self.tableContents[row] isEqualToString:TABLE_HEADER_HIJACK])
        {
            //set image
            tableCell.imageView.image = [NSImage imageNamed:@"virus"];
            
            //set count
            [[tableCell viewWithTag:TABLE_HEADER_TOTAL_TAG] setStringValue:[NSString stringWithFormat:@"total: %lu", (unsigned long)self.hijackCount]];

        }
        //header row for 'Vulnerable Applications'
        else
        {
            //set image
            tableCell.imageView.image = [NSImage imageNamed:@"bug"];
            
            //set count
            [[tableCell viewWithTag:TABLE_HEADER_TOTAL_TAG] setStringValue:[NSString stringWithFormat:@"total: %lu", (unsigned long)self.vulnerableCount]];
        }
    }
    
    //initially empty rows
    else if( (YES == [rowContents isKindOfClass:[NSString class]]) &&
             (YES == [rowContents isEqualToString:@""]))
    {
        //make cell
        tableCell = [tableView makeViewWithIdentifier:@"ImageCell" owner:self];
        if(nil == tableCell)
        {
            //bail
            goto bail;
        }
        
        //hide main text
        [tableCell.textField setStringValue:@""];
        
        //hide image
        tableCell.imageView.image = nil;
        
        //hide finder button
        [[tableCell viewWithTag:TABLE_ROW_FINDER_BUTTON] setHidden:YES];
        
        //hide hijack details
        [[tableCell viewWithTag:TABLE_ROW_SUB_TEXT_TAG] setStringValue:@""];
    }
    
    //content rows
    // ->fill with content :)
    else
    {
        //make cell
        tableCell = [tableView makeViewWithIdentifier:@"ImageCell" owner:self];
        if(nil == tableCell)
        {
            //bail
            goto bail;
        }
        
        //check if cell was previously used (by checking the item name)
        // ->if so, set flag to indicated tracking area does not need to be added
        if( (YES != [tableCell.textField.stringValue isEqualToString:@""]) &&
            (YES != [tableCell.textField.stringValue isEqualToString:@"Item Path"]) )
        {
            //set flag
            hasTrackingArea = YES;
        }
        
        //item in table array is a binary object
        // ->grab that
        binary = (Binary*)rowContents;
        
        //set main text to binary path
        [tableCell.textField setStringValue:binary.path];
        
        //set detailed (sub) text for hijack
        if(YES == binary.isHijacked)
        {
            //set detailed text for rpath hijack
            if(ISSUE_TYPE_RPATH == binary.issueType)
            {
                //set
                details = [NSString stringWithFormat:@"rpath hijacker: %@", binary.issueItem];
                
            }
            //set detailed text for weak hijack
            else
            {
                //set
                details = [NSString stringWithFormat:@"weak hijacker: %@", binary.issueItem];
            }
        }
        //set detailed (sub) text for vulnerable binary
        else
        {
            //set detailed text for rpath issue
            if(ISSUE_TYPE_RPATH == binary.issueType)
            {
                //set
                details = [NSString stringWithFormat:@"rpath vulnerability: %@", binary.issueItem];
                
            }
            //set detailed text for weak issue
            else
            {
                //set
                details = [NSString stringWithFormat:@"weak vulnerability: %@", binary.issueItem];
            }
        }
        
        //grab detailed text field
        detailedTextField = [tableCell viewWithTag:TABLE_ROW_SUB_TEXT_TAG];
        
        //make sure text is gray
        detailedTextField.textColor = [NSColor grayColor];
        
        //set image
        // ->app's icon
        tableCell.imageView.image = getIconForBinary(((Binary*)rowContents).path);
        
        //set detailed text
        [detailedTextField setStringValue:details];
        
        //show finder button
        [[tableCell viewWithTag:TABLE_ROW_FINDER_BUTTON] setHidden:NO];
        
        //only have to add tracking area once
        // ->add it the first time
        if(NO == hasTrackingArea)
        {
            //init tracking area
            // ->for 'show' button
            trackingArea = [[NSTrackingArea alloc] initWithRect:[[tableCell viewWithTag:TABLE_ROW_FINDER_BUTTON] bounds]
             options:(NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:nil];
            
            //add tracking area to 'show' button
            [[tableCell viewWithTag:TABLE_ROW_FINDER_BUTTON] addTrackingArea:trackingArea];
        }
    }
    
//bail
bail:
    
    return tableCell;
}

//table delegate method
// ->determine if a table row is a group ('header') row
-(BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
    //ret var
    BOOL isGroup = NO;
    
    //check for header text
    if(YES == [self.tableContents[row] isKindOfClass:[NSString class]])
    {
        //check names
        if( (YES == [self.tableContents[row] isEqualToString:TABLE_HEADER_HIJACK]) ||
            (YES == [self.tableContents[row] isEqualToString:TABLE_HEADER_VULNERABLE]) )
        {
            //set flag
            isGroup = YES;
        }
    }
    
    return isGroup;
}


//table delegate method
// want big rows, so return that here
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 66.0f;
}

//automatically invoked when user clicks the 'show in finder' icon
// ->open Finder to show binary (app)
-(IBAction)showInFinder:(id)sender
{
    //index of selected row
    NSInteger selectedRow = 0;
    
    //file open error alert
    NSAlert* errorAlert = nil;
    
    //grab selected row
    selectedRow = [self.resultsTableView rowForView:sender];
    
    //open item in Finder
    // ->error alert shown if file open fails
    if(YES != [[NSWorkspace sharedWorkspace] selectFile:[self.tableContents[selectedRow] path] inFileViewerRootedAtPath:@""])
    {
        //alloc/init alert
                errorAlert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"ERROR:\nfailed to open %@", [self.tableContents[selectedRow] path]] defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"errno value: %d", errno];
        
        //show it
        [errorAlert runModal];
    }
    

    return;
}

//automatically invoked when the user clicks 'start'/'stop' scan
-(IBAction)scanButtonHandler:(id)sender
{
    //alert
    // ->for full system scan msg
    NSAlert* fullScanAlert = nil;
    
    //check state
    //if(YES == [((NSButton*)sender).title
    if(YES == [[self.scanButtonLabel stringValue] isEqualToString:@"Start Scan"])
    {
        //update the UI
        // ->reflect the started state
        [self startScanUI];
        
        //alert user that full scans take a long time
        if(YES == self.prefsWindowController.fullScan)
        {
            //alloc/init alert
            fullScanAlert = [NSAlert alertWithMessageText:@"a full system scan takes some time" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"please relax while DHS crunches away :)"];
            
            //and show it
            [fullScanAlert runModal];
        }
       
        //start scan
        // ->kicks off background scanner thread
        [self startScan];
    }

    //stop scan
    else
    {
        //cancel thread
        if(YES == [self.scannerThread isExecuting])
        {
            //dbg msg
            //NSLog(@"OBJECTIVE-SEE INFO: setting thread's state to 'cancelled'");
            
            //cancel!
            [self.scannerThread cancel];
        }
        
        //save results?
        if(YES == self.prefsWindowController.saveOutput)
        {
            //save
            [self saveResults];
        }
        
        //update the UI
        // ->reflect the stopped state
        [self stopScanUI:SCAN_MSG_STOPPED];
    }
    
    return;
}

//kickoff background thread to scan
-(void)startScan
{
    //alloc thread
    scannerThread = [[NSThread alloc] initWithTarget:self selector:@selector(scan) object:nil];
    
    //start thread
    [self.scannerThread start];
    
    return;
}

//thread function
// ->runs in the background and scan the process list or file system
-(void)scan
{
    //scanner obj
    Scanner* scannerObj = nil;
    
    //dictionary for scanner options
    NSDictionary* scannerOptions = nil;
    
    //init dictionary w/ scanner options
    scannerOptions = @{
                       KEY_SCANNER_FULL: [NSNumber numberWithBool:self.prefsWindowController.fullScan],
                       KEY_SCANNER_WEAK_HIJACKERS : [NSNumber numberWithBool:self.prefsWindowController.weakHijackers]
                       };
    //alloc/init
    // ->pass in scanner options
    scannerObj = [[Scanner alloc] initWithOptions:scannerOptions];
    
    //init start time
    //startTime = [NSDate date];
    
    //scan!
    // ->will call back up to add rows to table as vulnerable binaries are found
    [scannerObj scan];
    
    
    //stop ui & show informational alert
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        //save results?
        if(YES == self.prefsWindowController.saveOutput)
        {
            //save
            [self saveResults];
        }
    
        //update the UI
        // ->reflect the stopped state
        [self stopScanUI:SCAN_MSG_COMPLETE];
    });

    return;
}

//update the UI to reflect that the fact the scan was started
// ->disable settings, set text 'stop scan', etc...
-(void)startScanUI
{
    //if scan was previous run
    // ->reset msg constraint
    if(YES != [[self.statusText stringValue] isEqualToString:@""])
    {
        //reset
        self.statusTextConstraint.constant = 56;
    }

    //show progress indicator
    self.progressIndicator.hidden = NO;
    
    //start spinner
    [self.progressIndicator startAnimation:nil];
    
    //set status msg
    if(NSOnState == self.prefsWindowController.fullScan)
    {
        //full scan
        [self.statusText setStringValue:SCAN_MSG_FULL];
    }
    else
    {
        //partial scan
        [self.statusText setStringValue:SCAN_MSG_PARTIAL];
    }
    
    //update button's image
    self.scanButton.image = [NSImage imageNamed:@"stopScan"];
    
    //update button's backgroud image
    self.scanButton.alternateImage = [NSImage imageNamed:@"stopScanBG"];
    
    //set label text
    // ->'Stop Scan'
    [self.scanButtonLabel setStringValue:STOP_SCAN];
    
    //disable preferences button
    self.showPreferences.enabled = NO;
    
    //reset hijack count
    self.hijackCount = 0;
    
    //reset vulnerable count
    self.vulnerableCount = 0;
    
    //reset table
    [self initTable];
    
    return;
}

//(re)initialize table to original/pristine form
-(void)initTable
{
    //remove everything
    [self.tableContents removeAllObjects];
    
    //add in 'hijacked applications' header
    [self.tableContents addObject:TABLE_HEADER_HIJACK];
    
    //...and its blank rows
    [self.tableContents addObject:@""];
    [self.tableContents addObject:@""];
    
    //add in 'vulnerable applications' header
    [self.tableContents addObject:TABLE_HEADER_VULNERABLE];
    
    //...and its blank rows
    [self.tableContents addObject:@""];
    [self.tableContents addObject:@""];
    [self.tableContents addObject:@""];
    
    //force table re-draw
    [self.resultsTableView reloadData];
    
    return;
}

//update the UI to reflect that the fact the scan was stopped
// ->set text back to 'start scan', etc...
-(void)stopScanUI:(NSString*)statusMsg
{
    //stop spinner
    [self.progressIndicator stopAnimation:nil];
    
    //hide progress indicator
    self.progressIndicator.hidden = YES;
    
    //shift over status msg
    self.statusTextConstraint.constant = 10;
    
    //set status msg
    [self.statusText setStringValue:statusMsg];
    
    //update button's image
    self.scanButton.image = [NSImage imageNamed:@"startScan"];
    
    //update button's backgroud image
    self.scanButton.alternateImage = [NSImage imageNamed:@"startScanBG"];
    
    //set label text
    // ->'Start Scan'
    [self.scanButtonLabel setStringValue:START_SCAN];
    
    //re-enable gear (show prefs) button
    self.showPreferences.enabled = YES;
    
    //display scan stats in UI (popup)
    [self displayScanStats];

    return;
}

//shows alert stating that that scan is complete (w/ stats)
-(void)displayScanStats
{
    //alert from scan completed
    NSAlert* completedAlert = nil;
    
    //detailed scan msg
    NSMutableString* details = nil;
    
    //issue count
    NSUInteger issueCount = 0;
    
    //init issue count
    // ->hijacks and vulnerabilites
    issueCount = self.hijackCount + self.vulnerableCount;
    
    //init detailed msg
    // ->nothing found
    if(0 == issueCount)
    {
        //happy
        details = [NSMutableString stringWithString:@"nothing found :)"];
    }
    
    //init detailed msg
    // ->issues found
    else
    {
        //hrmmm
        details = [NSMutableString stringWithFormat:@"■ found %lu possible issues", (unsigned long)issueCount];
        
        //add info about saving output
        if(YES == self.prefsWindowController.saveOutput)
        {
            //add save msg
            [details appendFormat:@" \r\n■ saved findings to '%@'", OUTPUT_FILE];
        }
    }
    
    //alloc/init alert
    completedAlert = [NSAlert alertWithMessageText:@"dylib hijack scan results" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", details];
    
    //show it
    [completedAlert runModal];
    
    return;
}

//add to table
-(void)addToTable:(Binary*)binary
{
    //row to insert binary
    NSUInteger targetRow = 0;
    
    //header row
    NSTableCellView* headerRow = nil;
    
    //handle logic for hijacked applications
    if(YES == binary.isHijacked)
    {
        //target row is just current count + 1
        targetRow = self.hijackCount+1;
        
        //if there are less than two hijacked items
        // ->replace the blank row
        if(self.hijackCount+1 <= 2)
        {
            //insert binary
            [self.tableContents replaceObjectAtIndex:targetRow withObject:binary];
        }
        //otherwise just insert
        else
        {
            [self.tableContents insertObject:binary atIndex:targetRow];
        }
        
        //inc count
        self.hijackCount++;
        
        //grab 'hijacked applications' header row
        headerRow = [self.resultsTableView viewAtColumn:0 row:0 makeIfNecessary:NO];
        
        //set 'total' text field
        [[headerRow viewWithTag:TABLE_HEADER_TOTAL_TAG] setStringValue:[NSString stringWithFormat:@"total: %lu", (unsigned long)self.hijackCount]];
    }
    //handle logic for vulnerable applications
    else
    {
        //target row is just current count of both
        // ->note: since there are 3 blank rows for the hijack'd apps, there will always be at least 4 rows above
        targetRow = (MAX(self.hijackCount, 2) + 1) + self.vulnerableCount+1;
        
        //if there are less than three vulnerable items
        // ->replace the blank row
        if(self.vulnerableCount+1 <= 3)
        {
            //insert binary
            [self.tableContents replaceObjectAtIndex:targetRow withObject:binary];
        }
        //otherwise just insert
        else
        {
            //insert binary
            [self.tableContents insertObject:binary atIndex:targetRow];
        }
        
        //inc count
        self.vulnerableCount++;
        
        //grab 'vulnerable applications' header row
        headerRow = [self.resultsTableView viewAtColumn:0 row:MAX(self.hijackCount, 2) + 1 makeIfNecessary:NO];
        
        //set 'total' text field
        [[headerRow viewWithTag:TABLE_HEADER_TOTAL_TAG] setStringValue:[NSString stringWithFormat:@"total: %lu", (unsigned long)self.vulnerableCount]];
    }
    
    //force table re-draw
    [self.resultsTableView reloadData];
    
    return;
}

//automatically invoked when mouse entered
-(void)mouseEntered:(NSEvent*)theEvent
{
    //mouse entered
    // ->highlight (visual) state
    [self buttonAppearance:theEvent shouldReset:NO];
    
    return;
}

//automaticall invoked when mouse exits
-(void)mouseExited:(NSEvent*)theEvent
{
    //mouse exited
    // ->so reset button to original (visual) state
    [self buttonAppearance:theEvent shouldReset:YES];
    
    return;
}

//set or unset button's highlight
-(void)buttonAppearance:(NSEvent*)theEvent shouldReset:(BOOL)shouldReset
{
    //tag
    NSUInteger tag = 0;
    
    //image name
    NSString* imageName =  nil;
    
    //button
    NSButton* button = nil;
    
    //extract tag
    tag = [((NSDictionary*)theEvent.userData)[@"tag"] unsignedIntegerValue];
    
    //handle tag table buttons
    if(0 == tag)
    {
        //set
        [self buttonAppearanceForTable:theEvent shouldReset:shouldReset];
        
        //bail
        goto bail;
    }
    
    //restore button back to default (visual) state
    if(YES == shouldReset)
    {
        //set original scan image
        if(SCAN_BUTTON_TAG == tag)
        {
            //scan running?
            if(YES == [self.scanButtonLabel.stringValue isEqualToString:@"Stop Scan"])
            {
                //set
                imageName = @"stopScan";
                
            }
            //scan not running
            else
            {
                //set
                imageName = @"startScan";
            }
            
        }
        //set original preferences image
        else if(PREF_BUTTON_TAG == tag)
        {
            //set
            imageName = @"settings";
        }
        //set original logo image
        else if(LOGO_BUTTON_TAG == tag)
        {
            //set
            imageName = @"logoApple";
        }
    }
    //highlight button
    else
    {
        //set original scan image
        if(SCAN_BUTTON_TAG == tag)
        {
            //scan running
            if(YES == [self.scanButtonLabel.stringValue isEqualToString:@"Stop Scan"])
            {
                //set
                imageName = @"stopScanOver";
                
            }
            //scan not running
            else
            {
                //set
                imageName = @"startScanOver";
            }
            
        }
        //set mouse over preferences image
        else if(PREF_BUTTON_TAG == tag)
        {
            //set
            imageName = @"settingsOver";
        }
        //set mouse over logo image
        else if(LOGO_BUTTON_TAG == tag)
        {
            //set
            imageName = @"logoAppleOver";
        }
    }
    
    //set image
    
    //grab button
    button = [[[self window] contentView] viewWithTag:tag];
    
    if(YES == [button isEnabled])
    {
        //set
        [button setImage:[NSImage imageNamed:imageName]];
    }
    
//bail
bail:
    
    return;
}




//set or unset button's highlight in a table
-(void)buttonAppearanceForTable:(NSEvent*)theEvent shouldReset:(BOOL)shouldReset
{
    //mouse point
    NSPoint mousePoint = {0};
    
    //row index
    NSUInteger rowIndex = -1;
    
    //current row
    NSTableCellView* currentRow = nil;
    
    //grab mouse point
    mousePoint = [self.resultsTableView convertPoint:[theEvent locationInWindow] fromView:nil];
    
    //compute row indow
    rowIndex = [self.resultsTableView rowAtPoint:mousePoint];
    
    //sanity check
    if(-1 == rowIndex)
    {
        //bail
        goto bail;
    }
    
    //get row that's about to be selected
    currentRow = [self.resultsTableView viewAtColumn:0 row:rowIndex makeIfNecessary:YES];
    
    //reset back to default
    if(YES == shouldReset)
    {
        //set image
        [[currentRow viewWithTag:TABLE_ROW_FINDER_BUTTON] setImage:[NSImage imageNamed:@"show"]];
    }
    //highlight button
    else
    {
        //set image
        [[currentRow viewWithTag:TABLE_ROW_FINDER_BUTTON] setImage:[NSImage imageNamed:@"showOver"]];
    }

//bail
bail:
    
    return;
}


//save results to disk
// ->JSON dumped to current directory
-(void)saveResults
{
    //output
    NSMutableString* output = nil;
    
    //item index
    NSUInteger itemIndex = 0;
    
    //current item
    Binary* currentItem = nil;
    
    //output directory
    NSString* outputDirectory = nil;
    
    //output file
    NSString* outputFile = nil;
    
    //error
    NSError* error = nil;
    
    //init output string
    output = [NSMutableString string];
    
    //start w/ hijacked apps
    [output appendString:@"{\"hijacked applications\":["];
    
    //iterate over table
    // ->add each row to output
    for(itemIndex = 0; itemIndex < self.tableContents.count; itemIndex++)
    {
        //grab current item
        currentItem = self.tableContents[itemIndex];
        
        //skip headers/blank rows
        if(YES != [currentItem isKindOfClass:[Binary class]])
        {
            //skip
            continue;
        }
        
        //bail once all hijacked apps are reported
        // ->this are at front of array
        if(YES != currentItem.isHijacked)
        {
            //bail
            break;
        }
        
        //add item
        [output appendFormat:@"{%@},", [currentItem toJSON]];
    }
    
    //if any hijacked items were found
    // ->remove last ','
    if(YES == [output hasSuffix:@","])
    {
        //remove
        [output deleteCharactersInRange:NSMakeRange([output length]-1, 1)];
    }
    
    //terminate list
    [output appendString:@"],"];
    
    //add vulnerable applications
    [output appendString:@"\"vulnerable applications\":["];
    
    //process vulnerable apps (skipping header)
    // ->i.e. rest of output
    for(; itemIndex < self.tableContents.count; itemIndex++)
    {
        //grab current item
        currentItem = self.tableContents[itemIndex];
        
        //skip headers/blank rows
        if(YES != [currentItem isKindOfClass:[Binary class]])
        {
            //skip
            continue;
        }
        
        //add item
        [output appendFormat:@"{%@},", [currentItem toJSON]];
    }
    
    //if any hijacked items were found
    // ->remove last ','
    if(YES == [output hasSuffix:@","])
    {
        //remove
        [output deleteCharactersInRange:NSMakeRange([output length]-1, 1)];
    }
    
    //terminate list/output
    [output appendString:@"] }"];
    
    //init output directory
    // ->app's directory
    outputDirectory = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
    
    //init full path to output file
    outputFile = [NSString stringWithFormat:@"%@/%@", outputDirectory, OUTPUT_FILE];
    
    //save JSON to disk
    if(YES != [output writeToFile:outputFile atomically:YES encoding:NSUTF8StringEncoding error:nil])
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: saving output to %@ failed with %@", outputFile, error);
        
        //bail
        goto bail;
    }
    
//bail
bail:
    
    return;
}

//automatically invoked when window is closing
// ->tell OS that we are done with window so it can (now) be freed
-(void)windowWillClose:(NSNotification *)notification
{
    //exit
    [NSApp terminate:self];
    
    return;
}

//automatically invoked when user clicks gear icon
// ->show preferences
-(IBAction)showPreferences:(id)sender
{
    //show it as modal
    [[NSApplication sharedApplication] runModalForWindow:prefsWindowController.window];

    return;
}

//register handler for hot keys
-(void)registerKeypressHandler
{
    //handler
    NSEvent* (^keypressHandler)(NSEvent *);
    
    //handler logic
    keypressHandler = ^NSEvent * (NSEvent * theEvent){
        
        return [self handleKeypress:theEvent];
        
    };
    
    //register for key-down events
    [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:keypressHandler];
    
    return;
}

//invoked for any (but only) key-down events
-(NSEvent*)handleKeypress:(NSEvent*)event
{
    //flag indicating event was handled
    BOOL wasHandled = NO;
    
    //only care about 'cmd' + something
    if(NSCommandKeyMask != (event.modifierFlags & NSCommandKeyMask))
    {
        //bail
        goto bail;
    }
    
    //handle key-code
    // close window (cmd+w)
    switch ([event keyCode])
    {
        //'w' (close window)
        // ->on main window; same as 'cmd+q' since app will exit with last window
        case KEYCODE_W:
            
            //close window
            [[[NSApplication sharedApplication] keyWindow] close];
                
            //set flag
            wasHandled = YES;
                
            //make un-modal
            [[NSApplication sharedApplication] stopModal];
            
            break;
            
        //'q' (close window)
        // ->exit application
        case KEYCODE_Q:
            
            //quit
            [NSApp terminate:self];
            
            break;
        
        //default
        // ->do nothing
        default:
            break;
            
    }//switch on event
    
//bail
bail:
    
    //nil out event if it was handled
    if(YES == wasHandled)
    {
        //unset
        event = nil;
    }
    
    return event;
}



#pragma mark Menu Handler(s) #pragma mark -

//menu handler
// ->invoked when user clicks 'About/Info
-(IBAction)about:(id)sender
{
    //alloc/init settings window
    if(nil == self.aboutWindowController)
    {
        //alloc/init
        aboutWindowController = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindow"];
    }
    
    //center window
    [[self.aboutWindowController window] center];
    
    //show it
    [self.aboutWindowController showWindow:self];
    
    return;
}

//automatically invoked when user clicks logo
// ->load objective-see's html page
-(IBAction)logoButtonHandler:(id)sender
{
    //open URL
    // ->invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://objective-see.com"]];
    
    return;
}


//hide friends view
// also shows/kicks off main window
- (IBAction)hideFriends:(id)sender
{
    //once
    static dispatch_once_t onceToken;
    
    //close and launch main window
    dispatch_once (&onceToken, ^{
        
        //close
        [self.friends close];
        
    });
    
    return;
}
@end
