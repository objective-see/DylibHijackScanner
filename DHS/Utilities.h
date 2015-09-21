//
//  Utilities.h
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#ifndef DHS_Utilities_h
#define DHS_Utilities_h

//check if OS is supported
BOOL isSupportedOS();

//check if a file is an executable
BOOL isURLExecutable(NSURL* appURL);

//get the signing info of a file
NSDictionary* signingInfo(NSString* path);

//get all loaded binaries (apps/exes/modules)
NSMutableArray* loadedBinaries();

/* METHODS */

//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForBinary(NSString* binary);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion();

#endif
