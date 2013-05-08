#import "DiningHallMenuViewController.h"
#import "DiningMenuCompareViewController.h"
#import "DiningMenuFilterViewController.h"
#import "DiningHallDetailHeaderView.h"
#import "DiningHallMenuFooterView.h"
#import "DiningHallMenuItemTableCell.h"
#import "DiningHallMenuSectionHeaderView.h"
#import "DiningModule.h"
#import "HouseVenue.h"
#import "DiningDay.h"
#import "DiningMeal.h"
#import "DiningMealItem.h"
#import "DiningDietaryFlag.h"
#import "UIKit+MITAdditions.h"
#import "Foundation+MITAdditions.h"

@interface DiningHallMenuViewController ()

@property (nonatomic, strong) UIBarButtonItem *filterBarButton;
@property (nonatomic, strong) NSArray * filtersApplied;
@property (nonatomic, strong) NSArray * mealItems;

@property (nonatomic, strong) DiningMeal * currentMeal;
@property (nonatomic, strong) NSString * currentDateString;

@property (nonatomic, strong) NSManagedObjectContext* managedObjectContext;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@end

@implementation DiningHallMenuViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // set current date string
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    self.currentDateString = [dateFormatter stringFromDate:[NSDate date]];
    
    NSDate *fakeDate = [HouseVenue fakeDate];
    
    // set current meal
    self.currentMeal = [self.venue bestMealForDate:fakeDate];
    
    self.fetchedResultsController = [self fetchedResultsControllerForMeal:self.currentMeal filters:nil];
    self.fetchedResultsController.delegate = self;
    
    [self.fetchedResultsController performFetch:nil];
    
    DiningHallDetailHeaderView *headerView = [[DiningHallDetailHeaderView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), 87)];
    headerView.titleLabel.text = self.venue.name;
    
    NSDictionary *timeData = [self hallStatusStringForMeal:self.currentMeal];
    if ([timeData[@"isOpen"] boolValue]) {
        headerView.timeLabel.textColor = [UIColor colorWithHexString:@"#008800"];
    } else {
        headerView.timeLabel.textColor = [UIColor colorWithHexString:@"#bb0000"];
    }
    headerView.timeLabel.text = timeData[@"text"];
    self.tableView.tableHeaderView = headerView;
    
    DiningHallMenuFooterView *footerView = [[DiningHallMenuFooterView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), 54)];
    self.tableView.tableFooterView = footerView;
    
    self.filterBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Filter" style:UIBarButtonItemStylePlain target:self action:@selector(filterMenu:)];
    self.navigationItem.rightBarButtonItem = self.filterBarButton;
    
    self.tableView.allowsSelection = NO;
}

- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    _managedObjectContext.persistentStoreCoordinator = [[CoreDataManager coreDataManager] persistentStoreCoordinator];
    _managedObjectContext.undoManager = nil;
    _managedObjectContext.stalenessInterval = 0;
    
    return _managedObjectContext;
}

- (NSFetchedResultsController *)fetchedResultsControllerForMeal:(DiningMeal *)meal filters:(NSSet *)dietaryFilters {
    
    self.fetchedResultsController = nil;
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DiningMealItem"
                                              inManagedObjectContext:self.managedObjectContext];
    fetchRequest.entity = entity;
    // TODO: include filters in predicate if they are set
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"meal = %@", meal];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"ordinality" ascending:YES];
    fetchRequest.sortDescriptors = @[sort];
        
    NSFetchedResultsController *fetchedResultsController =
    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                        managedObjectContext:self.managedObjectContext
                                          sectionNameKeyPath:nil
                                                   cacheName:nil];
    
    return fetchedResultsController;
}

- (NSDictionary *) mealOfInterestForCurrentDay
{
    // gets current meal the closest meal
    NSDate *currentDate = [NSDate date];
    
    NSArray *meals = [self mealsForDay:self.currentDateString];
    if (meals) {
        for (int i = 0; i < [meals count]; i++) {
            NSDictionary * meal = meals[i];
            NSDate *startDate = [NSDate dateForTodayFromTimeString:meal[@"start_time"]];
            NSDate *endDate = [NSDate dateForTodayFromTimeString:meal[@"end_time"]];
            if ([startDate compare:currentDate] == NSOrderedAscending && [currentDate compare:endDate] == NSOrderedAscending) {
                // current meal. current time is within meal time
                return meal;
            } else if ([currentDate compare:startDate] == NSOrderedAscending) {
                // current time is before start time
                return meal;
            } else if ([endDate compare:currentDate] == NSOrderedAscending) {
                // current time is after meal's end time. see if meal is last in day
                if (i == [meals count] - 1) {
                    // return this meal only if it is the last in the day
                    return meal;
                }
            }
        }
    }
    return nil;
}


- (NSArray *) mealsForDay:(NSString *) dateString
{
    // method returns array or nil if day does not have any meals or matching day cannot be found
    
    // date string must be in the yyyy-MM-dd format to match data
    for (DiningDay *day in self.venue.menuDays) {
//        if ([day.date isEqualToString:dateString]) {
//            // we have found our day, return meals
//            return day[@"meals"];
//        }
    }
    return nil;
}

- (NSString *) timeSpanStringForMeal:(NSDictionary *) meal
{
    // returns meal start time and end time formatted
    //      h:mma - h:mma
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"h:mma"];
    NSDate *startDate = [NSDate dateForTodayFromTimeString:meal[@"start_time"]];
    NSDate *endDate = [NSDate dateForTodayFromTimeString:meal[@"end_time"]];
    
    return [NSString stringWithFormat:@"%@ - %@", [dateFormatter stringFromDate:startDate], [dateFormatter stringFromDate:endDate]];
}

- (NSDictionary *) hallStatusStringForMeal:(DiningMeal *) meal
{
//      Returns hall status relative to the curent time of day.
//      Return value is a dictionary with the structure
//          isOpen : YES/NO
//          text : @"User Facing String"
// Example return strings
//          - Closed for the day
//          - Opens at 5:30pm
//          - Open until 4:00pm

    NSDate *rightNow = [NSDate date];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    
    if (!meal) {
        // closed with no hours today
        return @{@"isOpen": @NO,
                 @"text" : @"Closed for the day"};
    }
    
    if (meal.startTime && meal.endTime) {
        // need to calculate if the current time is before opening, before closing, or after closing
        
        BOOL willOpen       = ([meal.startTime compare:rightNow] == NSOrderedDescending); // openDate > rightNow , before the open hours for the day
        BOOL currentlyOpen  = ([meal.startTime compare:rightNow] == NSOrderedAscending && [rightNow compare:meal.endTime] == NSOrderedAscending);  // openDate < rightNow < closeDate , within the open hours
        BOOL hasClosed      = ([rightNow compare:meal.endTime] == NSOrderedDescending); // rightNow > closeDate , after the closing time for the day
        
        [dateFormat setDateFormat:@"h:mm a"];  // adjust format for pretty printing
        
        if (willOpen) {
            NSString *closedStringFormatted = [dateFormat stringFromDate:meal.startTime];
            return @{@"isOpen": @NO,
                     @"text" : [NSString stringWithFormat:@"Opens at %@", closedStringFormatted]};
            
        } else if (currentlyOpen) {
            NSString *openStringFormatted = [dateFormat stringFromDate:meal.endTime];
            return @{@"isOpen": @YES,
                     @"text" : [NSString stringWithFormat:@"Open until %@", openStringFormatted]};
        } else if (hasClosed) {
            return @{@"isOpen": @NO,
                     @"text" : @"Closed for the day"};
        }
    }
    
    // the just in case
    return @{@"isOpen": @NO,
             @"text" : @"Closed for the day"};
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeLeft) {
        return YES;
    }
    return NO;
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration
{
    DiningMenuCompareViewController *vc = [[DiningMenuCompareViewController alloc] init];
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    [self presentViewController:vc animated:YES completion:NULL];
}

#pragma mark - Filter
- (void) filterMenu:(id)sender
{
    DiningMenuFilterViewController *filterVC = [[DiningMenuFilterViewController alloc] initWithStyle:UITableViewStyleGrouped];
    [filterVC setFilters:self.filtersApplied];
    filterVC.delegate = self;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:filterVC];
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    navController.navigationBar.barStyle = UIBarStyleBlack;
    
    [self presentViewController:navController animated:YES completion:NULL];
}

- (void) applyFilters:(NSArray *)filters
{
    self.filtersApplied = filters;
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray *sections = [self.fetchedResultsController sections];
    if ([sections count] > 0) {
        id<NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex:0];
        return [sectionInfo numberOfObjects];
    }
    return 0;
    // return 1;       // will be used to show 'No meals this day'
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DiningMealItem *item = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (item) {
        return [DiningHallMenuItemTableCell cellHeightForCellWithStation:item.station title:item.name subtitle:item.subtitle];
    }
    return 54;  // 'No meals' cells are static 54px
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DiningMealItem *item = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (item) {
        static NSString *CellIdentifier = @"Cell";
        DiningHallMenuItemTableCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (!cell) {
            cell = [[DiningHallMenuItemTableCell alloc] initWithReuseIdentifier:CellIdentifier];
        }
        
        cell.station.text       = item.station;
        cell.title.text         = item.name;
        cell.subtitle.text      = item.subtitle;
        
        NSArray *imagePaths = [[item.dietaryFlags mapObjectsUsingBlock:^id(id obj) {
            return ((DiningDietaryFlag *)obj).pdfPath;
        }] allObjects];
        cell.dietaryImagePaths  = [imagePaths sortedArrayUsingSelector:@selector(compare:)];
        
        return cell;
    } else {
        static NSString *EmptyCellIdentifier = @"ListEmptyCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:EmptyCellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:EmptyCellIdentifier];
        }
        
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.font = [UIFont systemFontOfSize:17];
        cell.textLabel.text = @"No meals this day";
        
        return cell;
    }
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        DiningHallMenuSectionHeaderView *header = [[DiningHallMenuSectionHeaderView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(tableView.bounds), 56)]; // height does not matter here, calculated in heightForHeaderInSection: delegate
        
        NSString * mealString = [self.currentMeal.name capitalizedString];
        header.mainLabel.text = // [DiningHallMenuSectionHeaderView stringForMeal:self.currentMeal onDate:self.currentDateString];
        header.mealLabel.text = mealString;
        header.timeLabel.text = [self.currentMeal hoursSummary];
        
        [header.leftButton addTarget:self action:@selector(pageLeft) forControlEvents:UIControlEventTouchUpInside];
        [header.rightButton addTarget:self action:@selector(pageRight) forControlEvents:UIControlEventTouchUpInside];
        header.currentFilters = self.filtersApplied;
        
        if ([self.fetchedResultsController.fetchedObjects count] == 0) {
            header.showMealBar = NO;
        }
        
        return header;
    }
    return nil;
}

-(CGFloat)tableView:(UITableView *) tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        CGFloat height = [DiningHallMenuSectionHeaderView heightForPagerBar];
        if ([self.filtersApplied count] > 0) {
            height+=[DiningHallMenuSectionHeaderView heightForFilterBar];
        }
        
        if ([self.fetchedResultsController.fetchedObjects count] > 0) {
            height+=[DiningHallMenuSectionHeaderView heightForMealBar];
        }
        
        return height;
    }
    return 0;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


#pragma mark - Paging between meals
- (void) pageLeft
{
    NSLog(@"Page Left");
}

- (void) pageRight
{
    NSLog(@"Page Right");
}



@end
