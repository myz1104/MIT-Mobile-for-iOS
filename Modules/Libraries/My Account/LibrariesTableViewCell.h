#import <UIKit/UIKit.h>

extern const CGFloat kLibrariesTableCellDefaultWidth;
extern const CGFloat kLibrariesTableCellEditingWidth;

@interface LibrariesTableViewCell : UITableViewCell
@property (nonatomic,copy) NSDictionary *itemDetails;
@property (nonatomic,retain) UILabel *titleLabel;
@property (nonatomic,retain) UILabel *infoLabel;
@property (nonatomic,retain) UILabel *statusLabel;
@property (nonatomic,assign) UIEdgeInsets contentViewInsets;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;

- (void)layoutContentUsingBounds:(CGRect)bounds;
- (CGFloat)heightForContentWithWidth:(CGFloat)width;
@end