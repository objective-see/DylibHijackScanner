//
//  Binary.m
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import "Consts.h"
#import "Binary.h"

@implementation Binary

@synthesize path;
@synthesize lcRPATHS;
@synthesize issueType;
@synthesize issueItem;
@synthesize isHijacked;
@synthesize isVulnerable;
@synthesize parserInstance;

//init with a path
-(id)initWithPath:(NSString*)binaryPath
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //save path
        self.path = binaryPath;
        
        //alloc array for run-path search directories
        // ->needed since we resolve these manually
        lcRPATHS = [NSMutableArray array];
    }
    
    return self;
}

//get the machO type from the machO parser instance
// ->just grab from first header (should all by the same)
-(uint32_t)getType
{
    //type
    uint32_t type = 0;
    
    //extract type
    if(nil != self.parserInstance)
    {
        //extract
        type = [[[self.parserInstance.binaryInfo[KEY_MACHO_HEADERS] firstObject] objectForKey:KEY_HEADER_BINARY_TYPE] unsignedIntValue];
    }
    
    return type;
}

//convert object to JSON string
-(NSString*)toJSON
{
    //json string
    NSString *json = nil;
    
    //issue
    NSString* issue = nil;
    
    //init issue
    // ->rpath
    if(ISSUE_TYPE_RPATH == self.issueType)
    {
        issue = @"rpath";
    }
    //init issue
    // ->weak
    else
    {
        issue = @"weak";
    }
    
    //init json
    json = [NSString stringWithFormat:@"\"binary path\": \"%@\", \"issue\": \"%@\", \"dylib path\": \"%@\"", self.path, issue, self.issueItem];
    
    return json;
}

@end
