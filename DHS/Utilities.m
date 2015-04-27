//
//  Utilities.m
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import "Consts.h"
#import "Utilities.h"

#import <Foundation/Foundation.h>
#import <Security/Security.h>

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
    
    //create static code
    status = SecStaticCodeCreateWithPath((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, &staticCode);
    
    //sanity check
    if(STATUS_SUCCESS != status)
    {
        //err msg
        //NSLog(@"OBJECTIVE-SEE ERROR: SecStaticCodeCreateWithPath() failed on %@ with %d", path, status);
        
        //bail
        goto bail;
    }
    
    //check signature
    status = SecStaticCodeCheckValidityWithErrors(staticCode, kSecCSDoNotValidateResources, NULL, NULL);
    
    //save signature status
    signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
    
    //if file is signed
    // ->grab signing authorities
    if(STATUS_SUCCESS == status)
    {
        //grab signing authorities
        status = SecCodeCopySigningInformation(staticCode, kSecCSSigningInformation, &signingInformation);
        
        //sanity check
        if(STATUS_SUCCESS != status)
        {
            //err msg
            //NSLog(@"OBJECTIVE-SEE ERROR: SecCodeCopySigningInformation() failed on %@ with %d", path, status);
            
            //bail
            goto bail;
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
    
//bail
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

//get all loaded binaries (apps/exes/modules)
NSMutableArray* loadedBinaries()
{
    //loaded binaries
    NSMutableArray* loadedBinaries;
    
    //alloc/init
    loadedBinaries = [NSMutableArray array];
    
    NSTask *task = [NSTask new];
    [task setLaunchPath:LSOF];
    //[task setLaunchPath:@"/bin/ls"];
    [task setArguments:@[@"/"]];
    
    NSPipe *outPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
    //[task setStandardError:outPipe];
    
    NSFileHandle * readHandle = [outPipe fileHandleForReading];
    
    //dbg msg
    //NSLog(@"exec'ing lsof");
    
    [task launch];
    
    //2MB
    NSMutableData *data = [NSMutableData dataWithCapacity:2*1000000];
    
    while ([task isRunning])
    {
        
        [data appendData:[readHandle readDataToEndOfFile]];
    
    }
    [data appendData:[readHandle readDataToEndOfFile]];
    
    //[task waitUntilExit];
    
    //dbg msg
    //NSLog(@"DONE exec'ing lsof");
    

    //NSFileHandle * read = [outPipe fileHandleForReading];
    //NSData * dataRead = [read readDataToEndOfFile];
    NSString * stringRead = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //NSLog(@"output: %@", stringRead);
    
    NSArray *lines = [stringRead componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    //NSLog(@"lines: %@", lines);
    
    NSUInteger index = 0;
    
    //skip first line
    for(index = 1; index < lines.count-1; index++)
    {
        NSMutableArray *line = [[lines[index] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] mutableCopy];
        line = [[line filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != ''"]] mutableCopy];
        
        NSRange r;
        r.location = 0;
        r.length = 8;
        
        [line removeObjectsInRange:r];
        
        NSString* file = [line componentsJoinedByString:@""];
        
        if( (YES == [[NSFileManager defaultManager] fileExistsAtPath:file]) &&
            (YES == isURLExecutable([NSURL fileURLWithPath:file])) )
           
        {
            //NSLog(@"file: %@", file);
            
            //add it to array
            [loadedBinaries addObject:file];
        }
        
        
    }
    
    //remove dups
    [loadedBinaries setArray:[[NSSet setWithArray:loadedBinaries] allObjects]];
    
    return loadedBinaries;
}

//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
NSImage* getIconForBinary(NSString* binary)
{
    //bundle
    NSBundle* bundle = nil;
    
    //icon's file name
    NSString* iconFile = nil;
    
    //icon's path
    NSString* iconPath = nil;
    
    //icon's path extension
    NSString* iconExtension = nil;
    
    //system's document icon
    NSData* documentIcon = nil;
    
    //icon
    NSImage* icon = nil;
    
    //load bundle
    bundle = findAppBundle(binary);
    
    //for app's
    // ->extract their icon
    if(nil != bundle)
    {
        //get file
        iconFile = bundle.infoDictionary[@"CFBundleIconFile"];
        
        //get path extension
        iconExtension = [iconFile pathExtension];
        
        //if its blank (i.e. not specified)
        // ->go with 'icns'
        if(YES == [iconExtension isEqualTo:@""])
        {
            //set type
            iconExtension = @"icns";
        }
        
        //set full path
        iconPath = [bundle pathForResource:[iconFile stringByDeletingPathExtension] ofType:iconExtension];
        
        //load it
        icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    
    //process is not an app or couldn't get icon
    // ->try to get it via shared workspace
    if( (nil == bundle) ||
        (nil == icon) )
    {
        //extract icon
        icon = [[NSWorkspace sharedWorkspace] iconForFile:binary];
        
        //load system document icon
        documentIcon = [[[NSWorkspace sharedWorkspace] iconForFileType:
                         NSFileTypeForHFSTypeCode(kGenericDocumentIcon)] TIFFRepresentation];
        
        //if 'iconForFile' method doesn't find and icon, it returns the system 'document' icon
        // ->the system 'applicaiton' icon seems more applicable, so use that here...
        if(YES == [[icon TIFFRepresentation] isEqual:documentIcon])
        {
            //set icon to system 'applicaiton' icon
            icon = [[NSWorkspace sharedWorkspace]
                         iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
        }
        
        //'iconForFileType' returns small icons
        // ->so set size to 64
        [icon setSize:NSMakeSize(64, 64)];
    }
    
    return icon;
}


//if string is too long to fit into a the text field
// ->truncate and insert ellipises before /file
NSString* stringByTruncatingString(NSTextField* textField, NSString* string, float width)
{
    //trucated string (with ellipis)
    NSMutableString *truncatedString = nil;
    
    //offset of last '/'
    NSRange lastSlash = {};
    
    //make copy of string
    truncatedString = [string mutableCopy];
    
    //sanity check
    // ->make sure string needs truncating
    if([string sizeWithAttributes: @{NSFontAttributeName: textField.font}].width < width)
    {
        //bail
        goto bail;
    }
    
    //find instance of last '/
    lastSlash = [string rangeOfString:@"/" options:NSBackwardsSearch];
    
    //sanity check
    // ->make sure found a '/'
    if(NSNotFound == lastSlash.location)
    {
        //bail
        goto bail;
    }
    
    //account for added ellipsis
    width -= [ELLIPIS sizeWithAttributes: @{NSFontAttributeName: textField.font}].width;
    
    //delete characters until string will fit into specified size
    while([truncatedString sizeWithAttributes: @{NSFontAttributeName: textField.font}].width > width)
    {
        //sanity check
        // ->make sure we don't run off the front
        if(0 == lastSlash.location)
        {
            //bail
            goto bail;
        }
        
        //skip back
        lastSlash.location--;
        
        //delete char
        [truncatedString deleteCharactersInRange:lastSlash];
    }
    
    //set length of range
    lastSlash.length = ELLIPIS.length;
    
    //back up location
    lastSlash.location -= ELLIPIS.length;
    
    //add in ellipis
    [truncatedString replaceCharactersInRange:lastSlash withString:ELLIPIS];
    
    
//bail
bail:
    
    return truncatedString;
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
