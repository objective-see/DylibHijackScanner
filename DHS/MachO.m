//
//  MachO.m
//  MachOParser
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import "MachO.h"

#import <mach-o/arch.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>



@implementation MachO

@synthesize binaryInfo;
@synthesize binaryData;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc info dictionary
        // ->contains everything collected about the file
        binaryInfo = [NSMutableDictionary dictionary];
        
        //init array for machO headers
        self.binaryInfo[KEY_MACHO_HEADERS] = [NSMutableArray array];
        
        //init array for LC_RPATHS
        self.binaryInfo[KEY_LC_RPATHS] = [NSMutableArray array];
        
        //init array for LC_LOAD_DYLIBs
        self.binaryInfo[KEY_LC_LOAD_DYLIBS] = [NSMutableArray array];
        
        //init array for LC_LOAD_WEAK_DYLIBs
        self.binaryInfo[KEY_LC_LOAD_WEAK_DYLIBS] = [NSMutableArray array];
    }
    
    return self;
}


//parse a binary
// ->extract all required/interesting stuff
-(BOOL)parse:(NSString*)binaryPath 
{
    //ret var
    BOOL wasParsed = NO;
    
    //dbg msg
    //NSLog(@"parsing %@", binaryPath);
    
    //save path
    self.binaryInfo[KEY_BINARY_PATH] = binaryPath;
    
    //load binary into memory
    self.binaryData = [NSData dataWithContentsOfFile:binaryPath];
    if( (nil == self.binaryData) ||
        (NULL == [self.binaryData bytes]) )
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: failed to load %@ into memory", binaryPath);
        
        //bail
        goto bail;
    }
    
    //parse headers
    // ->populates 'KEY_MACHO_HEADERS' array in 'binaryInfo' iVar
    if(YES != [self parseHeaders])
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: failed to find any machO headers");
        
        //bail
        goto bail;
    }
    
    //parse headers
    // ->populates 'KEY_MACHO_HEADERS' array in 'binaryInfo' iVar
    if(YES != [self parseLoadCmds])
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: failed to parse load commands");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    //NSLog(@"parsed load commands");
    
    //happy
    wasParsed = YES;
    
//bail
bail:
    
    return wasParsed;
}

//parse all machO headers
-(BOOL)parseHeaders
{
    //return var
    BOOL wasParsed = NO;
    
    //start of macho header
    const uint32_t *headerStart = NULL;
    
    //header dictionary
    NSDictionary* header = nil;
    
    //number of machO headers
    uint32_t headerCount = 0;
    
    //header offsets
    NSMutableArray* headerOffsets = nil;
    
    //per-architecture header
    const struct fat_arch *arch = NULL;
    
    //pointer to binary's data
    const void* binaryBytes = NULL;
    
    //alloc array
    headerOffsets = [NSMutableArray array];
    
    //grab binary's bytes
    binaryBytes = [self.binaryData bytes];
    
    //sanity check
    if(NULL == binaryBytes)
    {
        //bail
        goto bail;
    }
    
    //init start of header
    headerStart = binaryBytes;
    
    //handle universal case
    if( (FAT_MAGIC == *headerStart) ||
        (FAT_CIGAM == *headerStart) )
    {
        //dbg msg
        //NSLog(@"parsing universal binary");
        
        //get number of fat_arch structs
        // ->one per each architecture
        headerCount = OSSwapBigToHostInt32(((struct fat_header*)binaryBytes)->nfat_arch);
        
        //get offsets of all headers
        for(uint32_t i = 0; i < headerCount; i++)
        {
            //get current struct fat_arch *
            // ->base + size of fat_header + size of fat_archs
            arch = binaryBytes + sizeof(struct fat_header) + i * sizeof(struct fat_arch);
            
            //save into header offset array
            [headerOffsets addObject:[NSNumber numberWithUnsignedInt:OSSwapBigToHostInt32(arch->offset)]];
        }
    }
    
    //not fat
    // ->just add start as (only) header offset
    else
    {
        //dbg msg
        //NSLog(@"parsing non-universal binary");
        
        //add start
        [headerOffsets addObject:@0x0];
    }
    
    //classify all headers
    for(NSNumber* headerOffset in headerOffsets)
    {
        //skip invalid header offsets
        if(headerOffset.unsignedIntValue > [self.binaryData length])
        {
            //skip
            continue;
        }
        
        //grab start of header
        headerStart = binaryBytes + headerOffset.unsignedIntValue;
        
        //classify header
        switch(*headerStart)
        {
            //32bit mach-O
            // ->little-endian version
            case MH_CIGAM:
                
                //init header dictionary
                header = @{
                           KEY_HEADER_OFFSET:headerOffset,
                           KEY_HEADER_SIZE:@(sizeof(struct mach_header)),
                           KEY_HEADER_BINARY_TYPE:[NSNumber numberWithInt:((struct mach_header*)headerStart)->filetype],
                           KEY_HEADER_BYTE_ORDER: [NSNumber numberWithInt:LITTLE_ENDIAN]
                           };
                
                //add header
                [self.binaryInfo[KEY_MACHO_HEADERS] addObject:header];
                
                //next
                break;

            //32-bit mach-O
            // ->big-endian version
            case MH_MAGIC:
                
                //init header dictionary
                header = @{
                           KEY_HEADER_OFFSET:headerOffset,
                           KEY_HEADER_SIZE:@(sizeof(struct mach_header)),
                           KEY_HEADER_BINARY_TYPE:[NSNumber numberWithInt:((struct mach_header*)headerStart)->filetype],
                           KEY_HEADER_BYTE_ORDER: [NSNumber numberWithInt:BIG_ENDIAN]
                           };
                
                //add header
                [self.binaryInfo[KEY_MACHO_HEADERS] addObject:header];
                
                //next
                break;
                
            //64-bit mach-O
            // ->little-endian version
            case MH_CIGAM_64:
                
                //init header dictionary
                header = @{
                           KEY_HEADER_OFFSET:headerOffset,
                           KEY_HEADER_SIZE:@(sizeof(struct mach_header_64)),
                           KEY_HEADER_BINARY_TYPE:[NSNumber numberWithInt:((struct mach_header_64*)headerStart)->filetype],
                           KEY_HEADER_BYTE_ORDER: [NSNumber numberWithInt:LITTLE_ENDIAN]
                           };
                
                //add header
                [self.binaryInfo[KEY_MACHO_HEADERS] addObject:header];
                
                //next
                break;
                
            //64-bit mach-O
            // ->big-endian version
            case MH_MAGIC_64:
                
                //init header dictionary
                header = @{
                           KEY_HEADER_OFFSET:headerOffset,
                           KEY_HEADER_SIZE:@(sizeof(struct mach_header_64)),
                           KEY_HEADER_BINARY_TYPE:[NSNumber numberWithInt:((struct mach_header_64*)headerStart)->filetype],
                           KEY_HEADER_BYTE_ORDER: [NSNumber numberWithInt:BIG_ENDIAN]
                           };
                
                //add header
                [self.binaryInfo[KEY_MACHO_HEADERS] addObject:header];
                
                //next
                break;
                
            default:
                
                //err msg
                NSLog(@"OBJECTIVE-SEE ERROR: unknown machO magic: %#x", *headerStart);
                
                //next
                break;
                
        }//switch, classifying headers
        
    }//for all headers
    
    //sanity check
    // ->make sure parser found at least one header
    if(0 != [self.binaryInfo[KEY_MACHO_HEADERS] count])
    {
        //happy
        wasParsed = YES;
    }
    
//bail
bail:
    
    return wasParsed;
}

//parse the load commands
// ->for now just save LC_RPATH, LC_LOAD_DYLIB, and LC_LOAD_WEAK_DYLIB
-(BOOL)parseLoadCmds
{
    //ret var
    BOOL wasParsed = NO;
    
    //pointer to load command structure
    struct load_command *loadCommand = NULL;
    
    //path in load commands such as LC_LOAD_DYLIB
    NSString* path = nil;
    
    //pointer to binary's data
    const void* binaryBytes = NULL;
    
    //number of load commands
    uint32_t loadCommandCount = 0;
    
    //grab binary's bytes
    binaryBytes = [self.binaryData bytes];
    
    //sanity check
    if(NULL == binaryBytes)
    {
        //bail
        goto bail;
    }

    //iterate over all machO headers
    for(NSDictionary* machoHeader in self.binaryInfo[KEY_MACHO_HEADERS])
    {
        //get number of load commands
        loadCommandCount = [self makeCompatible:((struct mach_header*)(unsigned char*)(binaryBytes + [machoHeader[KEY_HEADER_OFFSET] unsignedIntegerValue]))->ncmds byteOrder:machoHeader[KEY_HEADER_BYTE_ORDER]];
        
        //get first load command
        // ->immediately follows header
        loadCommand = (struct load_command*)(unsigned char*)(binaryBytes + [machoHeader[KEY_HEADER_OFFSET] unsignedIntegerValue] + [machoHeader[KEY_HEADER_SIZE] unsignedIntValue]);
        
        //iterate over all load commands
        // ->number of commands is in 'ncmds' member of (currect) header struct
        for(uint32_t i = 0; i < loadCommandCount; i++)
        {
            //handle load commands of interest
            switch([self makeCompatible:loadCommand->cmd byteOrder:machoHeader[KEY_HEADER_BYTE_ORDER]])
            {
                //LC_RPATHs
                // ->extract and save path
                case LC_RPATH:
                    
                    //extract name
                    path = [self extractPath:loadCommand byteOrder:machoHeader[KEY_HEADER_BYTE_ORDER]];
                    
                    //save if new
                    if(YES != [self.binaryInfo[KEY_LC_RPATHS] containsObject:path])
                    {
                        //dbg msg
                        //NSLog(@"adding %@", path);
                        
                        //save
                        [self.binaryInfo[KEY_LC_RPATHS] addObject:path];
                    }
                    
                    break;
                    
                //LC_LOAD_DYLIB and LC_LOAD_WEAK_DYLIB
                // ->extract and save path
                case LC_LOAD_DYLIB:
                case LC_LOAD_WEAK_DYLIB:
                    
                    //extract name
                    path = [self extractPath:loadCommand byteOrder:machoHeader[KEY_HEADER_BYTE_ORDER]];
                    
                    //save if new dylib
                    if( (LC_LOAD_DYLIB == loadCommand->cmd) &&
                       (YES != [self.binaryInfo[KEY_LC_LOAD_DYLIBS] containsObject:path]) )
                    {
                        //save
                        [self.binaryInfo[KEY_LC_LOAD_DYLIBS] addObject:path];
                    }
                    
                    //save if new weak dylib
                    else if( (LC_LOAD_WEAK_DYLIB == loadCommand->cmd) &&
                            (YES != [self.binaryInfo[KEY_LC_LOAD_WEAK_DYLIBS] containsObject:path]) )
                    {
                        //save
                        [self.binaryInfo[KEY_LC_LOAD_WEAK_DYLIBS] addObject:path];
                    }
                    
                    break;
                    
                default:
                    break;
            }
            
            //got to next load command
            loadCommand = (struct load_command *)(((unsigned char*)((unsigned char*)loadCommand + [self makeCompatible:loadCommand->cmdsize byteOrder:machoHeader[KEY_HEADER_BYTE_ORDER]])));
            
        }//all load commands
        
    }//all machO headers
    
    //happy
    wasParsed = YES;
    
//bail
bail:
    
    return wasParsed;
}

//helper function
// ->given an 32bit value, ensure it the correct byte order
-(uint32_t)makeCompatible:(uint32_t)input byteOrder:(NSNumber*)byteOrder
{
    //compatible value
    uint32_t compatibleValue = 0;
    
    //swap if needed
    if(LITTLE_ENDIAN == [byteOrder unsignedIntegerValue])
    {
        //swap
        compatibleValue = OSSwapInt32(input);
    }
    //no need to swap
    else
    {
        //simply assign
        compatibleValue = input;
    }
    
    return compatibleValue;
}

//helper function
// extract a path from an load command
// ->is a little tricky due to offsets and lengths of strings (null paddings, etc)
-(NSString*)extractPath:(struct load_command *)loadCommand byteOrder:(NSNumber*)byteOrder
{
    //offset
    size_t pathOffset = 0;
    
    //path bytes
    char* pathBytes = NULL;
    
    //length of path
    size_t pathLength = 0;
    
    //path
    NSString* path = nil;
    
    //set path offset
    // ->different based on load command type
    switch([self makeCompatible:loadCommand->cmd byteOrder:byteOrder])
    {
        //LC_RPATHs
        case LC_RPATH:
            
            //set offset
            pathOffset = sizeof(struct rpath_command);
            
            break;
            
        //LC_LOAD_DYLIB or LC_LOAD_WEAK_DYLIB
        case LC_LOAD_DYLIB:
        case LC_LOAD_WEAK_DYLIB:
            
            //set offset
            pathOffset = sizeof(struct dylib_command);
            
            break;
            
        default:
            break;
    }
    
    //init pointer to path's bytes
    pathBytes = (char*)loadCommand + pathOffset;
    
    //set path's length
    // ->min of strlen/value calculated from load command size
    pathLength = MIN(strlen(pathBytes), ([self makeCompatible:loadCommand->cmdsize byteOrder:byteOrder] - pathOffset));
    
    //create nstring version of path
    path = [[NSString alloc] initWithBytes:pathBytes length:pathLength encoding:NSUTF8StringEncoding];
    
    return path;
}


@end
