//
//  main.m
//

/* 
 DHS: dynamic hijack scanner
 signing: set 'Code Signing Indentify' to 'Developer ID: *'
          build an archive, then export as a 'Developer ID Signed Application'
          test via, $codesign -dvvv DHS.app (confirm 'Objective-See LLC)
                    $spctl -vat execute DHS.app
 */

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
    return NSApplicationMain(argc, (const char **)argv);
}
