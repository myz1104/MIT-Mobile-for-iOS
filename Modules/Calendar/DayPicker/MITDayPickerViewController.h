
#import <UIKit/UIKit.h>

@class MITDayPickerViewController;
@protocol MITDayPickerViewControllerDelegate <NSObject>
- (void)dayPickerViewController:(MITDayPickerViewController *)dayPickerViewController dateDidUpdate:(NSDate *)newDate fromOldDate:(NSDate *)oldDate;
@end

@interface MITDayPickerViewController : UIViewController
@property (weak, nonatomic) id<MITDayPickerViewControllerDelegate>delegate;
@property (strong, nonatomic) NSDate *currentlyDisplayedDate;
- (void)reloadCollectionView;
@end
