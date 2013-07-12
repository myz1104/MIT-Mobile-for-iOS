#import "LibrariesTellUsViewController.h"
#import "UIKit+MITAdditions.h"


@implementation LibrariesTellUsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Tell Us!";
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return MITCanAutorotateForOrientation(interfaceOrientation, [self supportedInterfaceOrientations]);
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (NSString *)command {
//    return @"sendTellUsEmail";
//    return @"tellUs";
    return @"sendTellForm";
}

- (NSArray *)formGroups {
    LibraryFormElementGroup *feedbackGroup = 
    [LibraryFormElementGroup groupForName:nil
                                 elements:[NSArray arrayWithObjects:
                                           [self statusMenuFormElementWithRequired:NO],
                                           [[[TextAreaLibraryFormElement alloc] 
                                             initWithKey:@"feedback" 
                                             displayLabel:@"Feedback" 
                                             required:YES] autorelease],
                                           nil]];
    
    feedbackGroup.footerText = @"Please let us know your thoughts for improving our services. We'd also appreciate hearing what you like about our current services.";
    
    ExternalLinkLibraryFormElement *suggestedPurchaseElement = 
    [[[ExternalLinkLibraryFormElement alloc] 
     initWithKey:@"suggested_purchase" 
     displayLabel:@"Suggested Purchase Form"
     required:NO] autorelease];
    suggestedPurchaseElement.url = [NSURL URLWithString:@"http://libraries.mit.edu/suggest-purchase"];
    
    LibraryFormElementGroup *suggestedPurchaseGroup = 
    [LibraryFormElementGroup groupForName:nil 
                                 elements:[NSArray arrayWithObjects:
                                           suggestedPurchaseElement,
                                           nil]];
    
    suggestedPurchaseGroup.footerText = @"If you would like to suggest a purchase for our collections, please see the Suggested Purchase form.";

    
    return [NSArray arrayWithObjects:feedbackGroup, suggestedPurchaseGroup, nil];
}

@end
