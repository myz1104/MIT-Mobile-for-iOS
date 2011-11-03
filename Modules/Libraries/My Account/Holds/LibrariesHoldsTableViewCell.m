#import <QuartzCore/QuartzCore.h>
#import "LibrariesHoldsTableViewCell.h"
#import "Foundation+MITAdditions.h"

@implementation LibrariesHoldsTableViewCell

- (void)setItemDetails:(NSDictionary *)itemDetails
{
    [super setItemDetails:itemDetails];
    
    if (itemDetails) {
        NSMutableString *status = [NSMutableString string];
        [status appendString:[itemDetails objectForKey:@"status"]];
        if ([[itemDetails objectForKey:@"ready"] boolValue]) {
            self.statusLabel.textColor = [UIColor colorWithRed:0
                                                         green:0.5
                                                          blue:0
                                                         alpha:1.0];
            [status appendFormat:@"\nPick up at %@", [itemDetails objectForKey:@"pickup-location"]];
        } else {
            self.statusLabel.textColor = [UIColor blackColor];
        }
        
        self.statusLabel.text = [[status stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByDecodingXMLEntities];
    }
}

@end