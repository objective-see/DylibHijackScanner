//
//  Utilities.m
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import "Consts.h"
#import "Utilities.h"

#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <Collaboration/Collaboration.h>

//check if OS is supported
BOOL isSupportedOS()
{
    //return
    BOOL isSupported = NO;
    
    //major version
    SInt32 versionMajor = 0;
    
    //minor version
    SInt32 versionMinor = 0;
    
    //get version info
    if( (noErr != Gestalt(gestaltSystemVersionMajor, &versionMajor)) ||
        (noErr != Gestalt(gestaltSystemVersionMinor, &versionMinor)) )
    {
        //err
        goto bail;
    }
    
    //check that OS is supported
    // ->10.8+ ?
    if(versionMajor == 10 && versionMinor >= 8)
    {
        //set flag
        isSupported = YES;
    }
    
//bail
bail:
    
    return isSupported;
}

//check if a file is an executable
BOOL isURLExecutable(NSURL* appURL)
{
    //return
    BOOL isExecutable = NO;
    
    //bundle url
    CFURLRef bundleURL = NULL;
    
    //architecture ref
    CFArrayRef archArrayRef = NULL;
    
    //create bundle
    bundleURL = CFURLCreateFromFileSystemRepresentation(NULL, (uint8_t*)[[appURL path] UTF8String], strlen((const char *)(uint8_t*)[[appURL path] UTF8String]), true);
    
    //get executable arch's
    archArrayRef = CFBundleCopyExecutableArchitecturesForURL(bundleURL);
    
    //check arch for i386/x6_64
    if(NULL != archArrayRef)
    {
        //set flag
        isExecutable = [(__bridge NSArray*)archArrayRef containsObject:[NSNumber numberWithInt:kCFBundleExecutableArchitectureX86_64]] || [(__bridge NSArray*)archArrayRef containsObject:[NSNumber numberWithInt:kCFBundleExecutableArchitectureI386]];
    }
    
    //free bundle url
    if(NULL != bundleURL)
    {
        //free
        CFRelease(bundleURL);
    }
    
    //free arch ref
    if(NULL != archArrayRef)
    {
        //free
        CFRelease(archArrayRef);
    }
    
    return isExecutable;
}

//get the signing info of a file
NSDictionary* signingInfo(NSString* path)
{
    //info dictionary
    NSMutableDictionary* signingStatus = nil;
    
    //code
    SecStaticCodeRef staticCode = NULL;
    
    //"anchor apple"
    static SecRequirementRef isApple = nil;
    
    //token
    static dispatch_once_t onceToken = 0;
    
    //status
    OSStatus status = !STATUS_SUCCESS;
    
    //signing information
    CFDictionaryRef signingInformation = NULL;
    
    //cert chain
    NSArray* certificateChain = nil;
    
    //index
    NSUInteger index = 0;
    
    //cert
    SecCertificateRef certificate = NULL;
    
    //common name on chert
    CFStringRef commonName = NULL;
    
    //init signing status
    signingStatus = [NSMutableDictionary dictionary];
    
    //only once
    // init requirements
    dispatch_once(&onceToken, ^{
        
        //init apple signing requirement
        SecRequirementCreateWithString(CFSTR("anchor apple"), kSecCSDefaultFlags, &isApple);
        
    });
    
    //create static code
    status = SecStaticCodeCreateWithPath((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, &staticCode);
    if(STATUS_SUCCESS != status)
    {
        //bail
        goto bail;
    }
    
    //check signature
    status = SecStaticCodeCheckValidity(staticCode, kSecCSDoNotValidateResources, NULL);
    
    //save signature status
    signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
    
    //if file is signed
    // check if signed by apple, library validation, and grab signing authorities
    if(STATUS_SUCCESS == status)
    {
        //grab signing information
        status = SecCodeCopySigningInformation(staticCode, kSecCSSigningInformation, &signingInformation);
        if(STATUS_SUCCESS != status)
        {
            //bail
            goto bail;
        }
        
        //check if signed by apple
        if(STATUS_SUCCESS == SecStaticCodeCheckValidity(staticCode, kSecCSDefaultFlags, isApple))
        {
            //signed by apple
            signingStatus[KEY_IS_APPLE] = [NSNumber numberWithInt:YES];
        }
        
        //library validation enabled?
        if(FLAGS_LIBRARY_VALIDATION == ([[(__bridge NSDictionary*)signingInformation objectForKey:(__bridge NSString*)kSecCodeInfoFlags] unsignedIntegerValue] & FLAGS_LIBRARY_VALIDATION))
        {
            //library validation
            signingStatus[KEY_LIBRARY_VALIDATION] = [NSNumber numberWithInt:YES];
        }
    }
    
    //init array for certificate names
    signingStatus[KEY_SIGNING_AUTHORITIES] = [NSMutableArray array];
    
    //get cert chain
    certificateChain = [(__bridge NSDictionary*)signingInformation objectForKey:(__bridge NSString*)kSecCodeInfoCertificates];
    
    //get name of all certs
    for(index = 0; index < certificateChain.count; index++)
    {
        //extract cert
        certificate = (__bridge SecCertificateRef)([certificateChain objectAtIndex:index]);
        
        //get common name
        status = SecCertificateCopyCommonName(certificate, &commonName);
        
        //skip ones that error out
        if( (STATUS_SUCCESS != status) ||
            (NULL == commonName))
        {
            //skip
            continue;
        }
        
        //save
        [signingStatus[KEY_SIGNING_AUTHORITIES] addObject:(__bridge NSString*)commonName];
        
        //release name
        CFRelease(commonName);
    }
    
bail:
    
    //free signing info
    if(NULL != signingInformation)
    {
        //free
        CFRelease(signingInformation);
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
    }
    
    return signingStatus;
}

//get an icon for a process
// for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForBinary(NSString* path)
{
    //icon's file name
    NSString* iconFile = nil;
    
    //icon's path
    NSString* iconPath = nil;
    
    //icon's path extension
    NSString* iconExtension = nil;
    
    //icon
    NSImage* icon = nil;
    
    //system's document icon
    static NSImage* documentIcon = nil;
    
    //bundle
    NSBundle* appBundle = nil;
    
    //invalid path?
    // grab a default icon and bail
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        //set icon to system 'application' icon
        icon = [[NSWorkspace sharedWorkspace]
                iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
        
        //set size to 64 @2x
        [icon setSize:NSMakeSize(128, 128)];
        
        //bail
        goto bail;
    }
    
    //first try grab bundle
    // ->then extact icon from this
    appBundle = findAppBundle(path);
    if(nil != appBundle)
    {
        //get file
        iconFile = appBundle.infoDictionary[@"CFBundleIconFile"];
        
        //get path extension
        iconExtension = [iconFile pathExtension];
        
        //if its blank (i.e. not specified)
        // go with 'icns'
        if(YES == [iconExtension isEqualTo:@""])
        {
            //set type
            iconExtension = @"icns";
        }
        
        //set full path
        iconPath = [appBundle pathForResource:[iconFile stringByDeletingPathExtension] ofType:iconExtension];
        
        //load it
        icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    
    //process is not an app or couldn't get icon
    // try to get it via shared workspace
    if( (nil == appBundle) ||
       (nil == icon) )
    {
        //extract icon
        icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
        
        //load system document icon
        // static var, so only load once
        if(nil == documentIcon)
        {
            //load
            documentIcon = [[NSWorkspace sharedWorkspace] iconForFileType:
                            NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
        }
        
        //if 'iconForFile' method doesn't find and icon, it returns the system 'document' icon
        // the system 'application' icon seems more applicable, so use that here...
        if(YES == [icon isEqual:documentIcon])
        {
            //set icon to system 'application' icon
            icon = [[NSWorkspace sharedWorkspace]
                    iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
        }
        
        //'iconForFileType' returns small icons
        // so set size to 64 @2x
        [icon setSize:NSMakeSize(128, 128)];
    }
    
bail:
    
    return icon;
}

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath)
{
    //app's bundle
    NSBundle* appBundle = nil;
    
    //app's path
    NSString* appPath = nil;
    
    //first just try full path
    appPath = binaryPath;
    
    //try to find the app's bundle/info dictionary
    do
    {
        //try to load app's bundle
        appBundle = [NSBundle bundleWithPath:appPath];
        
        //check for match
        // ->binary path's match
        if( (nil != appBundle) &&
           (YES == [appBundle.executablePath isEqualToString:binaryPath]))
        {
            //all done
            break;
        }
        
        //always unset bundle var since it's being returned
        // ->and at this point, its not a match
        appBundle = nil;
        
        //remove last part
        // ->will try this next
        appPath = [appPath stringByDeletingLastPathComponent];
        
        //scan until we get to root
        // ->of course, loop will be exited if app info dictionary is found/loaded
    } while( (nil != appPath) &&
            (YES != [appPath isEqualToString:@"/"]) &&
            (YES != [appPath isEqualToString:@""]) );
    
    return appBundle;
}

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion()
{
    //read and return 'CFBundleVersion' from bundle
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

//check if (full) dark mode
// meaning, Mojave+ and dark mode enabled
BOOL isDarkMode()
{
    //flag
    BOOL darkMode = NO;
    
    //prior to mojave?
    // bail, since not true dark mode
    if( (YES != [NSProcessInfo instancesRespondToSelector:@selector(isOperatingSystemAtLeastVersion:)]) ||
       (YES != [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 14, 0}]) )
    {
        //bail
        goto bail;
    }
    
    //not dark mode?
    if(YES != [[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] isEqualToString:@"Dark"])
    {
        //bail
        goto bail;
    }
    
    //ok, mojave dark mode it is!
    darkMode = YES;
    
bail:
    
    return darkMode;
}

//get all user
// includes name/home directory
NSMutableDictionary* allUsers()
{
    //users
    NSMutableDictionary* users = nil;
    
    //query
    CSIdentityQueryRef query = nil;
    
    //query results
    CFArrayRef results = NULL;
    
    //error
    CFErrorRef error = NULL;
    
    //identiry
    CBIdentity* identity = NULL;
    
    //alloc dictionary
    users = [NSMutableDictionary dictionary];
    
    //init query
    query = CSIdentityQueryCreate(NULL, kCSIdentityClassUser, CSGetLocalIdentityAuthority());
    
    //exec query
    if(true != CSIdentityQueryExecute(query, 0, &error))
    {
        //bail
        goto bail;
    }
    
    //grab results
    results = CSIdentityQueryCopyResults(query);
    
    //process all results
    // add user and home directory
    for (int i = 0; i < CFArrayGetCount(results); ++i)
    {
        //grab identity
        identity = [CBIdentity identityWithCSIdentity:(CSIdentityRef)CFArrayGetValueAtIndex(results, i)];
        
        //add user
        users[identity.UUIDString] = @{USER_NAME:identity.posixName, USER_DIRECTORY:NSHomeDirectoryForUser(identity.posixName)};
    }
    
bail:
    
    //release results
    if(NULL != results)
    {
        //release
        CFRelease(results);
    }
    
    //release query
    if(NULL != query)
    {
        //release
        CFRelease(query);
    }
    
    return users;
}

//give a list of paths
// convert any `~` to all or current user
NSMutableArray* expandPaths(const __strong NSString* const paths[], int count)
{
    //expanded paths
    NSMutableArray* expandedPaths = nil;
    
    //(current) path
    const NSString* path = nil;
    
    //all users
    NSMutableDictionary* users = nil;
    
    //grab all users
    users = allUsers();
    
    //alloc list
    expandedPaths = [NSMutableArray array];
    
    //iterate/expand
    for(NSInteger i = 0; i < count; i++)
    {
        //grab path
        path = paths[i];
        
        //no `~`?
        // just add and continue
        if(YES != [path hasPrefix:@"~"])
        {
            //add as is
            [expandedPaths addObject:path];
            
            //next
            continue;
        }
        
        //handle '~' case
        // root? add each user
        if(0 == geteuid())
        {
            //add each user
            for(NSString* user in users)
            {
                [expandedPaths addObject:[users[user][USER_DIRECTORY] stringByAppendingPathComponent:[path substringFromIndex:1]]];
            }
        }
        //otherwise
        // just convert to current user
        else
        {
            [expandedPaths addObject:[path stringByExpandingTildeInPath]];
        }
    }
    
    return expandedPaths;
}
