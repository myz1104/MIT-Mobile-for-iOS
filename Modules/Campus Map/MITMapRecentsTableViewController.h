#import <UIKit/UIKit.h>

extern NSString * const kMITMapRecentSearchCellIdentifier;

@protocol MITMapRecentsTableViewControllerDelegate;

@class MITMapPlace;
@class MITMapCategory;

@interface MITMapRecentsTableViewController : UITableViewController

@property (nonatomic, weak) id<MITMapRecentsTableViewControllerDelegate> delegate;
@property (nonatomic, strong) NSArray *recentSearchItems;
@property (nonatomic) BOOL showsTitleHeader;
@property (nonatomic) BOOL showsNoRecentsMessage;

- (void)showTitleHeaderIfNecessary;

@end

@protocol MITMapRecentsTableViewControllerDelegate <NSObject>

- (void)recentsViewController:(MITMapRecentsTableViewController *)recentsViewController didSelectRecentQuery:(NSString *)recentQuery;
- (void)recentsViewController:(MITMapRecentsTableViewController *)recentsViewController didSelectPlace:(MITMapPlace *)place;
- (void)recentsViewController:(MITMapRecentsTableViewController *)recentsViewController didSelectCategory:(MITMapCategory *)category;

@end