#import "MITNewsSearchController.h"
#import "MITNewsModelController.h"
#import "MITNewsRecentSearchController.h"
#import "MITNewsConstants.h"
#import "MITNewsStory.h"
#import "MITNewsStoryCell.h"
#import "MITNewsStoryViewController.h"
#import "MIT_MobileAppDelegate.h"
#import "MITCoreDataController.h"
#import "MITLoadingActivityView.h"
#import "MITViewWithCenterTextAndIndicator.h"
#import "MITViewWithCenterText.h"
#import "MITNewsCustomWidthTableViewCell.h"
#import "MITPopoverBackgroundView.h"

@interface MITNewsSearchController() <UIPopoverControllerDelegate>
@property (nonatomic, strong) MITNewsRecentSearchController *recentSearchController;
@property (nonatomic, strong) UIPopoverController *recentSearchPopoverController;
@property (nonatomic) BOOL unwindFromStoryDetail;
@property (nonatomic, weak) MITViewWithCenterTextAndIndicator *messageActivityView;
@property (nonatomic, weak) MITViewWithCenterText *messageView;
@property (nonatomic, strong) NSString *errorMessage;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *resignSearchTapGestureRecognizer;
@end

@implementation MITNewsSearchController {
    BOOL _storyUpdateInProgress;
}
@synthesize recentSearchController = _recentSearchController;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    
    return self;
}

#pragma mark - Dynamic Properties
- (MITNewsRecentSearchController *)recentSearchController
{
    if(!_recentSearchController) {
        MITNewsRecentSearchController *recentSearchController = [[MITNewsRecentSearchController alloc] init];
        recentSearchController.searchController = self;
        _recentSearchController = recentSearchController;
    }
    return _recentSearchController;
}

- (NSManagedObjectContext*)managedObjectContext
{
    if (!_managedObjectContext) {
        DDLogWarn(@"[%@] A managed object context was not set before being added to the view hierarchy. The default main queue NSManaged object context will be used but this will be a fatal error in the future.",self);
        _managedObjectContext = [[[MIT_MobileAppDelegate applicationDelegate] coreDataController] mainQueueContext];
    }
    
    NSAssert(_managedObjectContext, @"[%@] failed to load a valid NSManagedObjectContext", NSStringFromClass([self class]));
    return _managedObjectContext;
}

#pragma mark - View lifecyle
- (void)viewDidLoad
{
    [super viewDidLoad];

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - SearchBar
- (void)searchBarCancelButtonClicked
{
    [self hideSearchField];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [self hideSearchRecents];
    if ([searchBar.text isEqualToString:@""]) {
        [self changeToMainStories];
    } else {
        [self changeToSearchStories];
    }
    self.messageActivityView.alpha = 1;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self.recentSearchController addRecentSearchItem:searchBar.text];
    [self getResultsForString:searchBar.text];
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    if (self.unwindFromStoryDetail || self.recentSearchController.confirmSheet != nil) {
        self.unwindFromStoryDetail = NO;
        return NO;
    }
    return YES;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    self.view.alpha = .5;
    [self removeNoResultsView];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self showSearchRecents];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if ([searchText isEqualToString:@""]) {
        [self.view addGestureRecognizer:self.resignSearchTapGestureRecognizer];
        [self changeToMainStories];
        [self clearTable];
    } else {
        [self.view removeGestureRecognizer:self.resignSearchTapGestureRecognizer];
        
        [self changeToSearchStories];
        
    }
    [self.recentSearchController filterResultsUsingString:searchText];
}

- (void)clearTable
{
    self.dataSource = nil;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self reloadData];
    }];
}

#pragma mark - search
- (void)getResultsForString:(NSString *)searchTerm
{
    [self changeToSearchStories];
    [self.view removeGestureRecognizer:self.resignSearchTapGestureRecognizer];
    [self removeNoResultsView];
    [self addLoadingView];
    [self reloadData];
    self.searchBar.text = searchTerm;
    self.dataSource = [MITNewsStoriesDataSource dataSourceForQuery:searchTerm];
    
    __weak MITNewsSearchController *weakSelf = self;
    [self.dataSource refresh:^(NSError *error) {
        MITNewsSearchController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (error) {
            DDLogWarn(@"failed to refresh data source %@",self.dataSource);
            if (error.code == NSURLErrorNotConnectedToInternet) {
                strongSelf.errorMessage = @"No Internet Connection";
            } else {
                strongSelf.errorMessage = @"Failed...";
            }
            [strongSelf removeLoadingView];
            [strongSelf addNoResultsView];

        } else {
            DDLogVerbose(@"refreshed data source %@",self.dataSource);
            [strongSelf removeLoadingView];
            strongSelf.view.alpha = 0;
            if ([strongSelf.dataSource.objects count] == 0) {
                [strongSelf addNoResultsView];
                strongSelf.view.alpha = 1;
            }
            [strongSelf reloadData];
        }
    }];
    [self.searchBar resignFirstResponder];
    [self.recentSearchPopoverController dismissPopoverAnimated:YES];
}

#pragma mark - hide/show Recents
- (void)hideSearchRecents
{
    if (self.recentSearchPopoverController != nil && self.recentSearchController.confirmSheet == nil) {
        [self.recentSearchPopoverController dismissPopoverAnimated:YES];
        self.recentSearchPopoverController = nil;
    }
}

- (void)showSearchRecents
{
    if (self.recentSearchPopoverController) {
        return;
    }
    UIPopoverController *recentSearchPopoverController = [[UIPopoverController alloc] initWithContentViewController:self.recentSearchController];
    recentSearchPopoverController.popoverContentSize = CGSizeMake(300, 350);
    recentSearchPopoverController.delegate = self;
    recentSearchPopoverController.passthroughViews = @[self.searchBar];
    recentSearchPopoverController.popoverBackgroundViewClass = [MITPopoverBackgroundView class];
    [recentSearchPopoverController presentPopoverFromRect:[self.searchBar bounds] inView:self.searchBar permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    
    self.recentSearchPopoverController = recentSearchPopoverController;
}

- (void)hideSearchField
{
    [self.delegate hideSearchField];
}

#pragma mark - Popover
- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    [self.searchBar resignFirstResponder];
    if (self.view.alpha == .5) {
        [self hideSearchField];
    }
    return YES;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.recentSearchPopoverController = nil;
}

- (IBAction)tappedHideSearchFieldArea:(id)sender
{
    [self hideSearchField];
}

#pragma mark No Results / Loading More View
- (void)addNoResultsView
{
    MITViewWithCenterText *noResultsView = [[[NSBundle mainBundle] loadNibNamed:@"MITViewWithCenterText" owner:self options:nil] objectAtIndex:0];
    noResultsView.frame = self.view.frame;
    if (self.errorMessage) {
        noResultsView.overviewText.text = self.errorMessage;
        self.errorMessage = nil;
    }
    [self.view addSubview:noResultsView];
    self.messageView = noResultsView;
}

- (void)removeNoResultsView
{
    [self.messageView removeFromSuperview];
    self.messageView = nil;
}

- (void)addLoadingView
{
    MITViewWithCenterTextAndIndicator *loadingActivityView = [[[NSBundle mainBundle] loadNibNamed:@"MITViewWithCenterTextAndIndicator" owner:self options:nil] objectAtIndex:0];
    loadingActivityView.frame = self.view.frame;
    [self.view addSubview:loadingActivityView];
    self.messageActivityView = loadingActivityView;
}

- (void)removeLoadingView
{
    [self.messageActivityView removeFromSuperview];
    self.messageActivityView = nil;
}

#pragma mark delegate methods
- (void)changeToSearchStories
{
    [self.delegate changeToSearchStories];
}

- (void)changeToMainStories
{
    [self.delegate changeToMainStories];
}

- (void)reloadData
{
    [self.delegate reloadData];
}

@end
