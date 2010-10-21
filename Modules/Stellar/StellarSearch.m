#import "StellarSearch.h"
#import "StellarClass.h"
#import "StellarDetailViewController.h"
#import "StellarMainTableController.h"
#import "StellarClassTableCell.h"
#import "UITableView+MITUIAdditions.h"
#import "MITUIConstants.h"



@implementation StellarSearch

@synthesize lastResults;
@synthesize activeMode;
@synthesize searchBar;

- (void) endSearchMode {
	activeMode = NO;
	[searchBar setShowsCancelButton:NO animated:YES];
	[searchBar resignFirstResponder];
	
	[viewController hideSearchResultsTable];
	[viewController hideLoadingView];
	[viewController reloadMyStellarUI];
	
	[viewController.url setPath:@"" query:nil];
	[viewController.url setAsModulePath];
}

- (BOOL) isSearchResultsVisible {
	return hasSearchInitiated && activeMode;
}
	
- (id) initWithSearchBar: theSearchBar viewController: (StellarMainTableController *)controller{
	if(self = [super init]) {
		activeMode = NO;
		searchBar = [theSearchBar retain];
        searchBar.delegate = self;
		viewController = controller;
		self.lastResults = [NSArray array];
		hasSearchInitiated = NO;
	}
	return self;
}

- (void) dealloc {
    [searchBar release];
	[lastResults release];
	[super dealloc];
}

#pragma mark UITableViewDataSource methods

- (NSInteger) tableView: (UITableView *)tableView numberOfRowsInSection: (NSInteger)section {
	return [lastResults count];
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:@"StellarSearch"];
	if(cell == nil) {
		cell = [[[StellarClassTableCell alloc] initWithReusableCellIdentifier:@"StellarSearch"] autorelease];
	}

	StellarClass *stellarClass = [self.lastResults objectAtIndex:indexPath.row];
	[StellarClassTableCell configureCell:cell withStellarClass:stellarClass];
	return cell;
}

- (CGFloat) tableView: (UITableView *)tableView heightForRowAtIndexPath: (NSIndexPath *)indexPath {
	return [StellarClassTableCell cellHeightForTableView:tableView class:[self.lastResults objectAtIndex:indexPath.row]];
}
			
- (NSInteger) numberOfSectionsInTableView: (UITableView *)tableView {
	return 1;
}

- (UIView *) tableView: (UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *headerTitle = nil;
	
	if([lastResults count]) {
		headerTitle = [NSString stringWithFormat:@"%i found", [lastResults count]];
	} else {
		headerTitle = @"No matches found";
	}
	return [UITableView ungroupedSectionHeaderWithTitle:headerTitle];
}

- (CGFloat)tableView: (UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return UNGROUPED_SECTION_HEADER_HEIGHT;
}

#pragma mark UITableViewDelegate methods
- (void) tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	[StellarDetailViewController 
		launchClass:(StellarClass *)[self.lastResults objectAtIndex:indexPath.row]
		viewController:viewController];
}

#pragma mark ClassesSearchDelegate methods
- (void) searchComplete: (NSArray *)classes searchTerms:searchTerms {
	if([searchBar.text isEqualToString:searchTerms]) {
		self.lastResults = classes;
		[viewController hideLoadingView];
		
		if(self.lastResults.count) {		
			[viewController.searchResultsTableView applyStandardCellHeight];
			viewController.searchResultsTableView.allowsSelection = YES;
			[viewController.searchResultsTableView reloadData];
			[viewController showSearchResultsTable];
		
			// if exactly one result found forward user to that result
			if([classes count] == 1) {
				[StellarDetailViewController 
					launchClass:(StellarClass *)[classes lastObject]
					viewController: viewController];
			}
		} else {
			UIAlertView *alertView = [[UIAlertView alloc] 
				initWithTitle:nil message:@"no classes found" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alertView show];
			[alertView release];
		}
	}
}

- (void) handleCouldNotReachStellarWithSearchTerms: (NSString *)searchTerms {
	if([searchBar.text isEqualToString:searchTerms]) {
		[searchBar setShowsCancelButton:NO animated:YES];
		[viewController hideLoadingView];		
		[viewController.searchResultsTableView reloadData];
		[searchBar becomeFirstResponder];
	}
}

#pragma mark UISearchBarDelegate methods
- (void) searchBarSearchButtonClicked: (UISearchBar *)theSearchBar {
	[viewController showLoadingView];
	hasSearchInitiated = YES;
	
	[searchBar resignFirstResponder];
	[StellarModel executeStellarSearch:theSearchBar.text delegate:self];
	
	[viewController.url setPath:@"search-complete" query:theSearchBar.text];
	[viewController.url setAsModulePath];
}

- (void) searchBarTextDidBeginEditing:(UISearchBar *)aSearchBar {
	activeMode = YES;
	NSString *query = nil;
	
	[aSearchBar setShowsCancelButton:YES animated:YES];
	if(self.lastResults.count || searchBar.text.length) {
		query = aSearchBar.text;
	}
	
	[viewController.url setPath:@"search-begin" query:query];
	[viewController.url setAsModulePath];
}

- (void) searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[self endSearchMode];
}

- (void) searchBar: (UISearchBar *)searchBar textDidChange: (NSString *)searchText {
	[viewController hideLoadingView]; // just in case the loading view is showing
	
	// this is to simulate the native searchDisplayControllers overlay for many characters
	
	// we use a delay to work around the issue where apple draws the headers of
	// the tableView behind the Overlay after drawing the overlay
	// but minimize the use of delay to reduce flicker
	
	[viewController reloadMyStellarUI];
	
	hasSearchInitiated = NO;
	
	[viewController.url setPath:@"search-begin" query:searchText];
	[viewController.url setAsModulePath];
}

#pragma mark UIAlertViewDelegate for no classes found alert

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	[searchBar becomeFirstResponder];
}

@end
