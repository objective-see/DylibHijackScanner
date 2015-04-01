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
@synthesize resultsTableView;
@synthesize scanButton;
@synthesize scannerThread;
@synthesize tableContents;
@synthesize versionString;
@synthesize scanButtonLabel;
@synthesize progressIndicator;
@synthesize prefsWindowController;
@synthesize vulnerableAppHeaderIndex;

//TODO: scanner activity stopped when minimized...


-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    //first thing...
    // ->install exception handlers!
    installExceptionHandlers();
    
    /*
    int a = 12;
    int b = 0;
    printf("%d", a/b);
    */
  
    //alloc table array
    tableContents = [[NSMutableArray alloc] init];
    
    //make active
    [NSApp activateIgnoringOtherApps:YES];
    
    //bring to front
    [self.window makeKeyAndOrderFront:nil];
    
    //center window
    [[self window] center];
    
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
    [self.versionString setStringValue:[NSString stringWithFormat:@"version %@", getAppVersion()]];
    
    //set delegate
    // ->ensures our 'windowWillClose' method, which has logic to fully exit app
    self.window.delegate = self;
    
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

//display alert about OS not being supported
-(void)showUnsupportedAlert
{
    //response
    // ->index of button click
    NSModalResponse response = 0;
    
    //alert box
    NSAlert* fullScanAlert = nil;
    
    //alloc/init alert
    fullScanAlert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"OS X %@ is not officially supported", [[NSProcessInfo processInfo] operatingSystemVersionString]] defaultButton:@"Ok" alternateButton:nil otherButton:nil informativeTextWithFormat:@"sorry for the inconvenience!"];
    
    //and show it
    response = [fullScanAlert runModal];
    
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
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    //binary object
    Binary* binary = nil;
    
    //binary path
    // ->might be truncated so need this var
    NSString* binaryPath = nil;
    
    //detailed (sub) text
    NSString* details = nil;
    
    //detailed text field
    NSTextField* detailedTextField = nil;
    
    //grab row item from backing table array
    id rowContents = self.tableContents[row];
    
    //handle header ('group') rows
    if(YES == [self tableView:tableView isGroupRow:row])
    {
        //make a group cell
        NSTableCellView *groupCell = [tableView makeViewWithIdentifier:@"GroupCell" owner:self];
        if(nil == groupCell)
        {
            //TODO: implement this?
        }
        
        //set it's text
        [groupCell.textField setStringValue:rowContents];
        
        //header row for 'Hijack Applications'
        if(YES == [self.tableContents[row] isEqualToString:TABLE_HEADER_HIJACK])
        {
            //set image
            groupCell.imageView.image = [NSImage imageNamed:@"virus"];
            
            //set count
            [[groupCell viewWithTag:TABLE_HEADER_TOTAL_TAG] setStringValue:[NSString stringWithFormat:@"total: %lu", (unsigned long)self.hijackCount]];

        }
        //header row for 'Vulnerable Applications'
        else
        {
            //set image
            groupCell.imageView.image = [NSImage imageNamed:@"bug"];
            
            //set count
            [[groupCell viewWithTag:TABLE_HEADER_TOTAL_TAG] setStringValue:[NSString stringWithFormat:@"total: %lu", (unsigned long)self.vulnerableCount]];
        }
        
        return groupCell;
    }
    
    //initially empty rows
    else if( (YES == [rowContents isKindOfClass:[NSString class]]) &&
             (YES == [rowContents isEqualToString:@""]))
    {
        //make cell
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"ImageCell" owner:self];
        
        //hide main text
        [cellView.textField setStringValue:@""];
        
        //hide image
        cellView.imageView.image = nil;
        
        //hide finder button
        [[cellView viewWithTag:TABLE_ROW_FINDER_BUTTON] setHidden:YES];
        
        //hide hijack details
        [[cellView viewWithTag:TABLE_ROW_SUB_TEXT_TAG] setStringValue:@""];
        
        return cellView;
    
    }
    
    //content rows
    // ->fill with content :)
    else
    {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"ImageCell" owner:self];
        
        //cellView.u = UITableViewCellSelectionStyleNone;
        
        //item in table array is a binary object
        // ->grab that
        binary = (Binary*)rowContents;
        
        //process binary path
        // ->make sure its fits in window!
        binaryPath = stringByTruncatingString(cellView.textField, binary.path, cellView.frame.size.width-100);
        
        //set main text to binary path
        [cellView.textField setStringValue:binaryPath];
        
        //set detailed (sub) text for hijack
        if(YES == binary.isHijacked)
        {
            //set detailed text for rpath hijack
            if(ISSUE_TYPE_RPATH == binary.issueType)
            {
                details = [NSString stringWithFormat:@"rpath hijacker: %@", binary.issueItem];
                
            }
            //set detailed text for weak hijack
            else
            {
                details = [NSString stringWithFormat:@"weak hijacker: %@", binary.issueItem];
            }
        }
        //set detailed (sub) text for vulnerable binary
        else
        {
            //set detailed text for rpath issue
            if(ISSUE_TYPE_RPATH == binary.issueType)
            {
                details = [NSString stringWithFormat:@"rpath vulnerability: %@", binary.issueItem];
                
            }
            //set detailed text for weak issue
            else
            {
                details = [NSString stringWithFormat:@"weak vulnerability: %@", binary.issueItem];
            }
        }
        
        //grab detailed text field
        detailedTextField = [cellView viewWithTag:TABLE_ROW_SUB_TEXT_TAG];
        
        //make sure text is gray
        detailedTextField.textColor = [NSColor grayColor];
        
        //make sure detailed text isn't too long
        details = stringByTruncatingString(detailedTextField, details, detailedTextField.frame.size.width-100);
        
        //set image
        // ->app's icon
        cellView.imageView.image = getIconForBinary(((Binary*)rowContents).path);
        
        //set detailed text
        [detailedTextField setStringValue:details];
        
        //show finder button
        [[cellView viewWithTag:TABLE_ROW_FINDER_BUTTON] setHidden:NO];
    
        return cellView;
    }
    
    return nil;
}

//table delegate method
// ->invoke when user clicks row (to select)
//   if its a content row, allow the selection (and handle text highlighting issues)
-(BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
    //ret var
    BOOL shouldSelect = NO;
    
    //current row
    NSTableCellView* currentRow = nil;
    
    //previously selected row
    NSTableCellView* previousRow = nil;
    
    //detailed text
    NSTextField* detailedTextField = nil;
    
    //get row that's about to be selected
    currentRow = [self.resultsTableView viewAtColumn:0 row:rowIndex makeIfNecessary:YES];
    
    //if new row is a content row (e.g. its allowed it to be selected)
    // ->reset detailed text color of previous content row that was just unselected
    if( (nil != currentRow) &&
        (YES == [self.tableContents[rowIndex] isKindOfClass:[Binary class]]) )
    {
        if(-1 != tableView.selectedRow)
        {
            //get previous row
            previousRow = [self.resultsTableView viewAtColumn:0 row:tableView.selectedRow makeIfNecessary:NO];
            
            //get detailed text of previous row
            detailedTextField = [previousRow viewWithTag:TABLE_ROW_SUB_TEXT_TAG];
                
            //reset its color to gray
            detailedTextField.textColor = [NSColor grayColor];
        }
            
        //get detailed text of current row
        detailedTextField = [currentRow viewWithTag:TABLE_ROW_SUB_TEXT_TAG];
        
        //set its color to white
        detailedTextField.textColor = [NSColor whiteColor];
        
        //allow it to be selected
        shouldSelect = YES;
    }
    
    return shouldSelect;
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
// ->return height (note group rows are smaller)
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    //ret var
    CGFloat rowHeight = 0;
    
    //default to default height
    rowHeight = [tableView rowHeight];
    
    //group rows are shorter (thinner)
    if(YES == [self tableView:tableView isGroupRow:row])
    {
        //set height
        rowHeight = 50;
    }
    return rowHeight;
}


//automatically invoked when user clicks the 'reveal in finder' icon
// ->open Finder to show binary (app)
-(IBAction)showInFinder:(id)sender
{
    //index of selected ro
    NSInteger selectedRow = 0;
    
    //grab selected row
    selectedRow = [self.resultsTableView rowForView:sender];
    
    //open Finder
    // ->will reveal binary
    [[NSWorkspace sharedWorkspace] selectFile:[self.tableContents[selectedRow] path] inFileViewerRootedAtPath:nil];
    
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
            fullScanAlert = [NSAlert alertWithMessageText:@"a full system scan takes some time..." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"relax while we do the hard work!"];
            
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
    //status msg's frame
    CGRect newFrame = {};
    
    //if scan was previous run
    // ->will need to shift status msg back over
    if(YES != [[self.statusText stringValue] isEqualToString:@""])
    {
        //grab status msg's frame
        newFrame = self.statusText.frame;
        
        //shift it over (since activity spinner is about to be shown)
        newFrame.origin.x -= 50;
        
        //update status msg w/ new frame
        self.statusText.frame = newFrame;
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
    //status msg's frame
    CGRect newFrame = {};
    
    //stop spinner
    [self.progressIndicator stopAnimation:nil];
    
    //hide progress indicator
    self.progressIndicator.hidden = YES;
    
    //grab status msg's frame
    newFrame = self.statusText.frame;
    
    //shift it over (since activity spinner is gone)
    newFrame.origin.x += 50;
    
    //update status msg w/ new frame
    self.statusText.frame = newFrame;
    
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

//button handler
// ->invoked when user checks/unchecks 'weak hijack detection' checkbox
-(IBAction)hijackDetectionOptions:(id)sender
{
    //alert
    NSAlert* detectionAlert = nil;
    
    //check if user clicked (on)
    if(NSOnState == ((NSButton*)sender).state)
    {
        //alloc/init alert
        detectionAlert = [NSAlert alertWithMessageText:@"This might produce false positives" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"please consult an expert if any results are found!"];
        
        //show it
        [detectionAlert runModal];
    }
    
    return;
}

//automatically invoked when user clicks gear icon
// ->show preferences
-(IBAction)showPreferences:(id)sender
{
    //alloc/init settings window
    if(nil == self.prefsWindowController)
    {
        //alloc/init
        prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"PrefsWindow"];
    }

    //show it
    [self.prefsWindowController showWindow:self];
    
    //make it modal
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSApplication sharedApplication] runModalForWindow:prefsWindowController.window];
    });

    
    return;
}
#pragma mark Menu Handler(s) #pragma mark -

//menu handler
// ->invoked when user clicks 'About/Info
- (IBAction)about:(id)sender
{
    //open URL
    // ->invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://objective-see.com/products/dhs.html"]];
    
    return;
}

@end
