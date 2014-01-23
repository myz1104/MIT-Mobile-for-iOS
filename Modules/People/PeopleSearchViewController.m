#import "PeopleSearchViewController.h"
#import "PersonDetails.h"
#import "PeopleDetailsViewController.h"
#import "PeopleRecentsData.h"
#import "MIT_MobileAppDelegate.h"
#import "ConnectionDetector.h"
#import "MobileRequestOperation.h"
// common UI elements
#import "MITLoadingActivityView.h"
#import "SecondaryGroupedTableViewCell.h"
#import "MITUIConstants.h"
// external modules
#import "Foundation+MITAdditions.h"
#import "UIKit+MITAdditions.h"

#import "MITPeopleResource.h"

@interface PeopleSearchViewController () <UISearchBarDelegate, UIAlertViewDelegate, UIActionSheetDelegate>

@property (nonatomic,strong) IBOutlet UITableView *searchResultsTableView;
@property (nonatomic,strong) UIView *loadingView;
@property (nonatomic,strong) UIView *recentlyViewedHeader;

@property (nonatomic,copy) NSString *searchTerms;
@property (nonatomic,copy) NSArray *searchTokens;

@property (strong) NSURL *directoryPhoneURL;
@property BOOL searchCancelled;
@end

@implementation PeopleSearchViewController
- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nil
                           bundle:nil];
    
    if (self) {
        self.directoryPhoneURL = [NSURL URLWithString:@"telprompt://617.253.1000"];
    }
    
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return MITCanAutorotateForOrientation(interfaceOrientation, [self supportedInterfaceOrientations]);
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad {
	[super viewDidLoad];
    
    self.view.backgroundColor = [UIColor mit_backgroundColor];
    
//    [MITPersonResource personWithID:@"atreat" loaded:^(NSArray *objects, NSError *error) {
//        PersonDetails *test = [objects lastObject];
//    }];
    
//    [MITPeopleResource peopleMatchingQuery:@"john" loaded:^(NSArray *objects, NSError *error) {
//        PersonDetails *test = [objects firstObject];
//    }];

    // set up search controller
    self.searchController.searchBar = self.searchBar;
	self.searchController.delegate = self;

    CGRect tablesFrame = self.tableView.bounds;
    UITableView *searchTableView = [[UITableView alloc] initWithFrame:tablesFrame style:UITableViewStylePlain];
    searchTableView.backgroundView = nil;
	searchTableView.backgroundColor = [UIColor clearColor];
    
    self.searchController.searchResultsTableView = searchTableView;
    self.searchController.searchResultsDelegate = self;
    self.searchController.searchResultsDataSource = self;
    self.searchResultsTableView = searchTableView;

    // set up tableview
    UITableView *tableView = [[UITableView alloc] initWithFrame:tablesFrame style:UITableViewStyleGrouped];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.backgroundView = nil;
	tableView.backgroundColor = [UIColor clearColor];

//	
//	// set up table footer
//    {
//        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
//        [button setFrame:CGRectMake(10.0, 0.0, tableView.frame.size.width - 20.0, 44.0)];
//        button.titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
//        button.titleLabel.shadowOffset = CGSizeMake(0.0, -1.0);
//        button.titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.3];
//        [button setTitle:@"Clear Recents" forState:UIControlStateNormal];
//        
//        // based on code from stackoverflow.com/questions/1427818/iphone-sdk-creating-a-big-red-uibutton
//        [button setBackgroundImage:[[UIImage imageNamed:@"people/redbutton2.png"] stretchableImageWithLeftCapWidth:10.0 topCapHeight:0.0] 
//                          forState:UIControlStateNormal];
//        [button setBackgroundImage:[[UIImage imageNamed:@"people/redbutton2highlighted.png"] stretchableImageWithLeftCapWidth:10.0 topCapHeight:0.0] 
//                          forState:UIControlStateHighlighted];
//        
//        [button addTarget:self action:@selector(showActionSheet) forControlEvents:UIControlEventTouchUpInside];	
//        
//        UIView *buttonContainer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, tableView.frame.size.width, 44.0)];
//        [buttonContainer addSubview:button];
//        tableView.tableFooterView = buttonContainer;
//    }
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    if (![self.searchController isActive]) {
        [self.tableView reloadData];
    } else {
        [self.searchResultsTableView deselectRowAtIndexPath:[self.searchResultsTableView indexPathForSelectedRow] animated:YES];
    }
//    self.tableView.tableFooterView.hidden = ([[[PeopleRecentsData sharedData] recents] count] == 0);
}

#pragma mark -
#pragma mark Search methods

- (void)beginExternalSearch:(NSString *)externalSearchTerms {
	self.searchTerms = externalSearchTerms;
	self.searchBar.text = self.searchTerms;
	
	[self performSearch];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
	self.searchResults = nil;
    self.searchCancelled = YES;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
	self.searchTerms = searchBar.text;
	[self performSearch];
    [self.searchBar resignFirstResponder];
}

- (void)performSearch
{
	// save search tokens for drawing table cells
	NSMutableArray *tempTokens = [NSMutableArray arrayWithArray:[[self.searchTerms lowercaseString] componentsSeparatedByString:@" "]];
	[tempTokens sortUsingComparator:^NSComparisonResult(NSString *string1, NSString *string2) {
        return [@([string1 length]) compare:@([string2 length])];
    }];
    
	self.searchTokens = tempTokens;

    MobileRequestOperation *request = [[MobileRequestOperation alloc] initWithModule:@"people"
                                                                              command:nil
                                                                          parameters:@{@"q" : self.searchTerms}];
    request.completeBlock = ^(MobileRequestOperation *operation, id jsonResult, NSString *contentType, NSError *error) {
        if (_searchCancelled) {
            return;
        }
        
        [self.loadingView removeFromSuperview];	
        if (!error) {
            if ([jsonResult isKindOfClass:[NSArray class]]) {
                self.searchResults = jsonResult;
            } else {
                self.searchResults = nil;
            }
            
            self.searchController.searchResultsTableView.frame = self.tableView.frame;
            [self.view addSubview:self.searchController.searchResultsTableView];
            [self.searchController.searchResultsTableView reloadData];    
        }
    };

    [self showLoadingView];

	_searchCancelled = NO;
    [[NSOperationQueue mainQueue] addOperation:request];
}

#pragma mark -
#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (tableView == self.searchController.searchResultsTableView)
		return 1;
	else if ([[[PeopleRecentsData sharedData] recents] count] > 0)
		return 2;
	else
		return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (tableView == self.tableView) {
		switch (section) {
			case 0: // phone directory & emergency contacts
				return 2;
				break;
			case 1: // recently viewed
				return [[[PeopleRecentsData sharedData] recents] count];
				break;
			default:
				return 0;
				break;
		}
	} else {
		return [self.searchResults count];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	static NSString *recentCellID = @"RecentCell";
    
    static NSString * directoryAssistanceID = @"DirectoryAssistanceCell";

	if (tableView == self.tableView) { // show phone directory tel #, recents
	
	
		if (indexPath.section == 0) {
			
            UITableViewCell *cell;
            if (indexPath.row == 0) {
                cell = [tableView dequeueReusableCellWithIdentifier:directoryAssistanceID forIndexPath:indexPath];
                cell.accessoryView = [UIImageView accessoryViewWithMITType:MITAccessoryViewPhone];
            } else {
                cell = [tableView dequeueReusableCellWithIdentifier:@"EmergencyContactsCell" forIndexPath:indexPath];
//                cell.accessoryView = [UIImageView accessoryViewWithMITType:MITAccessoryViewEmergency];
            }
			
			return cell;
		
		} else { // recents
			
			UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:recentCellID forIndexPath:indexPath];

			PersonDetails *recent = [[PeopleRecentsData sharedData] recents][indexPath.row];
			cell.textLabel.text = [recent displayName];
            
			// show person's title, dept, or email as cell's subtitle text
			cell.detailTextLabel.text = @" ";
			NSString *displayText = nil;
			for (NSString *tag in @[@"title", @"dept"]) {
				displayText = [recent valueForKey:tag];
				if (displayText) {
					cell.detailTextLabel.text = displayText;
					break;
				}
			}
			return cell;
		}
	} else { // search results
		UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"ResultCell"];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ResultCell"];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
			
		NSDictionary *searchResult = self.searchResults[indexPath.row];
		NSString *fullname = searchResult[@"name"][0];

		if (searchResult[@"title"]) {
			cell.detailTextLabel.text = searchResult[@"title"][0];
		} else if (searchResult[@"dept"]) {
			cell.detailTextLabel.text = searchResult[@"dept"][0];
		} else {
            cell.detailTextLabel.text = @" "; // if this is empty textlabel will be bottom aligned
        }
		
        
		// in this section we try to highlight the parts of the results that match the search terms
        UIFont *labelFont = cell.textLabel.font;
        UIFont *boldFont = [UIFont boldSystemFontOfSize:labelFont.pointSize];   // This assumes labelFont will be using the systemFont
        __block NSMutableAttributedString *attributeString = [[NSMutableAttributedString alloc] initWithString:fullname];
        [self.searchTokens enumerateObjectsUsingBlock:^(NSString *token, NSUInteger idx, BOOL *stop) {
            NSRange boldRange = [[fullname lowercaseString] rangeOfString:token];
			if (boldRange.location != NSNotFound) {
				[attributeString addAttribute:NSFontAttributeName value:boldFont range:boldRange];
			}
        }];
		
		cell.textLabel.attributedText = attributeString;
		return cell;
	}
	
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (tableView == self.tableView && indexPath.section == 0) {
		return 44.0;
	} else {
		return CELL_TWO_LINE_HEIGHT;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if (section == 1) {
		return GROUPED_SECTION_HEADER_HEIGHT;
	} else if (tableView == self.searchController.searchResultsTableView && [self.searchResults count] > 0) {
		return UNGROUPED_SECTION_HEADER_HEIGHT;
	} else {
		return 0.0;
	}
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if (section == 1) {
		return [UITableView groupedSectionHeaderWithTitle:@"Recently Viewed"];
	} else if (tableView == self.searchController.searchResultsTableView) {
		NSUInteger numResults = [self.searchResults count];
		switch (numResults) {
			case 0:
				break;
			case 100:
				return [UITableView ungroupedSectionHeaderWithTitle:@"Many found, showing 100"];
				break;
			default:
				return [UITableView ungroupedSectionHeaderWithTitle:[NSString stringWithFormat:@"%d found", numResults]];
				break;
		}
	}
	
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (tableView == self.searchController.searchResultsTableView || indexPath.section == 1) { // user selected search result or recently viewed
		PersonDetails *personDetails = nil;
        
		PeopleDetailsViewController *detailView = [[PeopleDetailsViewController alloc] initWithStyle:UITableViewStyleGrouped];
		if (tableView == self.searchController.searchResultsTableView) {
			personDetails = [PersonDetails retrieveOrCreate:self.searchResults[indexPath.row]];
		} else {
			personDetails = [[PeopleRecentsData sharedData] recents][indexPath.row];
		}

		detailView.personDetails = personDetails;
		[self.navigationController pushViewController:detailView animated:YES];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
	} else { // we are on home screen and user selected phone or emergency contacts
		switch (indexPath.row) {
			case 0:
				[self phoneIconTapped];				
				[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
				break;
			case 1:
                [[UIApplication sharedApplication] openURL:[NSURL internalURLWithModuleTag:EmergencyTag path:@"contacts"]];
				[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
				break;
		}
	}
}

#pragma mark - Connection methods

- (void)showLoadingView {
	if (!self.loadingView) {
        CGRect frame = self.searchBar.frame;
        frame.origin.x = 0.0;
        frame.size.height = CGRectGetHeight(self.view.frame) - CGRectGetHeight(self.searchBar.frame);

		MITLoadingActivityView *loadingView = [[MITLoadingActivityView alloc] initWithFrame:frame];
        [self.view addSubview:loadingView];
        self.loadingView = loadingView;
	}
}

#pragma mark -
#pragma mark Action sheet methods

- (void)showActionSheet
{
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Clear Recents?"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:@"Clear"
                                              otherButtonTitles:nil];
    [sheet showFromAppDelegate];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"Clear"]) {
		[PeopleRecentsData eraseAll];
		self.tableView.tableFooterView.hidden = YES;
		[self.tableView reloadData];
		[self.tableView scrollRectToVisible:CGRectMake(0.0, 0.0, 1.0, 1.0) animated:YES];
	}
}

- (void)phoneIconTapped
{
	if ([[UIApplication sharedApplication] canOpenURL:self.directoryPhoneURL])
		[[UIApplication sharedApplication] openURL:self.directoryPhoneURL];
}


@end

