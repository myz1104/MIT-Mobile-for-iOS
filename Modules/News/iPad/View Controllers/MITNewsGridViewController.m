#import <objc/runtime.h>

#import "MITNewsGridViewController.h"
#import "MITCoreDataController.h"
#import "MITNewsModelController.h"
#import "MITNewsCategory.h"
#import "MITNewsStory.h"
#import "MITNewsConstants.h"
#import "MITNewsStoryCollectionViewCell.h"
#import "MITNewsiPadViewController.h"
#import "MITNewsGridHeaderView.h"
#import "MITAdditions.h"
#import "MITNewsStoryCollectionViewCell.h"

@interface MITNewsGridViewController ()
@property (nonatomic,strong) NSMapTable *gestureRecognizersByView;
@property (nonatomic,strong) NSMapTable *categoriesByGestureRecognizer;
@end

@implementation MITNewsGridViewController {
    NSMutableDictionary *_layoutCellsByIdentifier;
}

- (instancetype)init
{
    MITCollectionViewGridLayout *layout = [[MITCollectionViewGridLayout alloc] init];
    layout.headerHeight = 44.;
    
    self = [super initWithCollectionViewLayout:layout];
    
    if (self) {
        _numberOfColumnsForLandscapeOrientation = 4;
        _numberOfColumnsForPortraitOrientation = 3;
    }
    
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self didLoadCollectionView];
    self.gestureRecognizersByView = [NSMapTable weakToWeakObjectsMapTable];
    self.categoriesByGestureRecognizer = [NSMapTable weakToStrongObjectsMapTable];
}

- (void)didLoadCollectionView
{
    UICollectionView *collectionView = self.collectionView;

    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.backgroundView = nil;
    
    [self registerNib:[UINib nibWithNibName:MITNewsCellIdentifierStoryJumbo bundle:nil] forDynamicCellWithReuseIdentifier:MITNewsCellIdentifierStoryJumbo];

    [self registerNib:[UINib nibWithNibName:MITNewsCellIdentifierStoryDek bundle:nil] forDynamicCellWithReuseIdentifier:MITNewsCellIdentifierStoryDek];
    [self registerNib:[UINib nibWithNibName:MITNewsCellIdentifierStoryClip bundle:nil] forDynamicCellWithReuseIdentifier:MITNewsCellIdentifierStoryClip];

    [self registerNib:[UINib nibWithNibName:MITNewsCellIdentifierStoryWithImage bundle:nil] forDynamicCellWithReuseIdentifier:MITNewsCellIdentifierStoryWithImage];
    [self registerNib:[UINib nibWithNibName:MITNewsCellIdentifierStoryLoadMore bundle:nil] forDynamicCellWithReuseIdentifier:MITNewsCellIdentifierStoryLoadMore];

    [collectionView registerNib:[UINib nibWithNibName:MITNewsReusableViewIdentifierSectionHeader bundle:nil] forSupplementaryViewOfKind:MITNewsReusableViewIdentifierSectionHeader withReuseIdentifier:MITNewsReusableViewIdentifierSectionHeader];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.collectionView reloadData];

    if (!self.managedObjectContext) {
        self.managedObjectContext = [[MITCoreDataController defaultController] newManagedObjectContextWithConcurrencyType:NSMainQueueConcurrencyType trackChanges:NO];
    }
    
    [self updateLayoutForOrientation:self.interfaceOrientation];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self updateLayoutForOrientation:toInterfaceOrientation];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

#pragma mark Properties
- (MITNewsStory*)selectedStory
{
    UICollectionView *collectionView = self.collectionView;
    NSIndexPath* selectedIndexPath = [[collectionView indexPathsForSelectedItems] firstObject];
    return [self storyAtIndexPath:selectedIndexPath];
}

#pragma mark - Responding to UI events
- (IBAction)tableSectionHeaderTapped:(UIGestureRecognizer *)gestureRecognizer
{
    NSIndexPath *categoryIndexPath = [self.categoriesByGestureRecognizer objectForKey:gestureRecognizer];
    
    if (categoryIndexPath && ![self isFeaturedCategoryInSection:categoryIndexPath.section]) {
        [self didSelectCategoryInSection:[categoryIndexPath indexAtPosition:0]];
    }
}

- (void)updateLayoutForOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([self.collectionViewLayout isKindOfClass:[MITCollectionViewGridLayout class]]) {
        MITCollectionViewGridLayout *gridLayout = (MITCollectionViewGridLayout*)self.collectionViewLayout;
        if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
            gridLayout.numberOfColumns = self.numberOfColumnsForPortraitOrientation;
        } else {
            gridLayout.numberOfColumns = self.numberOfColumnsForLandscapeOrientation;
        }
    }
    
    [self.collectionViewLayout invalidateLayout];
}

#pragma mark - Delegation
#pragma mark UICollectionViewDelegate
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [self numberOfCategories];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [self numberOfStoriesForCategoryInSection:section];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    MITNewsStory *story = [self storyAtIndexPath:indexPath];
    if (story) {
        [self didSelectStoryAtIndexPath:indexPath];
    }
}

- (UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = [self identifierForCellAtIndexPath:indexPath];
    UICollectionViewCell *collectionViewCell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    
    [self configureCell:collectionViewCell atIndexPath:indexPath];
    
    return collectionViewCell;
}

- (UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:MITNewsReusableViewIdentifierSectionHeader]) {
        UICollectionReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:MITNewsReusableViewIdentifierSectionHeader withReuseIdentifier:MITNewsReusableViewIdentifierSectionHeader forIndexPath:indexPath];
        NSUInteger sectionIndex = [indexPath indexAtPosition:0];
        
        if ([headerView isKindOfClass:[MITNewsGridHeaderView class]]) {
            MITNewsGridHeaderView *newsHeaderView = (MITNewsGridHeaderView*)headerView;
            newsHeaderView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.95];
            UIGestureRecognizer *recognizer = [self.gestureRecognizersByView objectForKey:headerView];
            
        	if (!recognizer) {
            	recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tableSectionHeaderTapped:)];
            	[headerView addGestureRecognizer:recognizer];
			}
            
            
            // Keep track of the gesture recognizers we create so we can remove
            // them later
            [self.gestureRecognizersByView setObject:recognizer forKey:headerView];
            
            NSIndexPath *categoryIndexPath = [NSIndexPath indexPathWithIndex:indexPath.section];
            [self.categoriesByGestureRecognizer setObject:categoryIndexPath forKey:recognizer];
            
            newsHeaderView.headerLabel.text = [self titleForCategoryInSection:sectionIndex];
            BOOL featuredStory = [self isFeaturedCategoryInSection:indexPath.section];
            if (featuredStory) {
                newsHeaderView.accessoryView.hidden = YES;
            } else {
                newsHeaderView.accessoryView.hidden = NO;
            }
        }
        
        return headerView;
    }
    
    return nil;
}

- (void)registerNib:(UINib*)nib forDynamicCellWithReuseIdentifier:(NSString*)reuseIdentifier
{
    [self.collectionView registerNib:nib forCellWithReuseIdentifier:reuseIdentifier];
    
    UICollectionViewCell *layoutCell = [[nib instantiateWithOwner:nil options:nil] firstObject];
    [self _setCollectionViewLayoutCell:layoutCell];
    
}

- (NSString*)identifierForCellAtIndexPath:(NSIndexPath*)indexPath
{
    MITNewsStory *story = [self storyAtIndexPath:indexPath];
    BOOL featuredStory = [self isFeaturedCategoryInSection:indexPath.section];
    
    if (featuredStory && indexPath.item == 0) {
        return MITNewsCellIdentifierStoryJumbo;
    } else if ([story.type isEqualToString:MITNewsStoryExternalType]) {
        return MITNewsCellIdentifierStoryClip;
    } else if (story.coverImage)  {
        return MITNewsCellIdentifierStoryWithImage;
    } else {
        return MITNewsCellIdentifierStoryDek;
    }
}

- (void)configureCell:(UICollectionViewCell*)cell atIndexPath:(NSIndexPath*)indexPath
{
    if ([cell isKindOfClass:[MITNewsStoryCollectionViewCell class]]) {
        MITNewsStoryCollectionViewCell *storyCell = (MITNewsStoryCollectionViewCell*)cell;
        storyCell.story = [self storyAtIndexPath:indexPath];
    }
}

#pragma mark MITCollectionViewDelegateNewsGrid
- (void)_setCollectionViewLayoutCell:(UICollectionViewCell*)cell
{
    if (!_layoutCellsByIdentifier) {
        _layoutCellsByIdentifier = [[NSMutableDictionary alloc] init];
    }
    
    _layoutCellsByIdentifier[cell.reuseIdentifier] = cell;
}

- (UICollectionViewCell*)_dequeueLayoutCellForItemAtIndexPath:(NSIndexPath*)indexPath
{
    if (!_layoutCellsByIdentifier) {
        return nil;
    }
    
    NSString *identifier = [self identifierForCellAtIndexPath:indexPath];
    UICollectionViewCell *cell = _layoutCellsByIdentifier[identifier];
    
    return cell;
}

#pragma mark MITCollectionViewDelegateNewsGrid
- (CGFloat)heightForItemAtIndexPath:(NSIndexPath*)indexPath withWidth:(CGFloat)width
{
    UICollectionViewCell *cell = [self _dequeueLayoutCellForItemAtIndexPath:indexPath];

    [self configureCell:cell atIndexPath:indexPath];

    NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:cell
                                                                  attribute:NSLayoutAttributeWidth
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:nil
                                                                  attribute:NSLayoutAttributeNotAnAttribute
                                                                 multiplier:1
                                                                   constant:width];

    [cell addConstraint:constraint];

    // Make sure the cell's frame matched the width we were given
    CGRect frame = cell.frame;
    frame.size.width = width;
    cell.frame = frame;

    // Let this re-layout to account for the updated width
    // (such as re-positioning the content view)
    [cell setNeedsLayout];
    [cell layoutIfNeeded];

    // Now that the view has been laid out for the proper width
    // give it a chance to update any constraints which need tweaking
    [cell setNeedsUpdateConstraints];

    // ...and then relayout again!
    [cell setNeedsLayout];
    [cell layoutIfNeeded];

    CGSize cellSize = [cell systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];

    [cell removeConstraint:constraint];

    return ceil(cellSize.height);
}

- (CGFloat)collectionView:(UICollectionView*)collectionView layout:(MITCollectionViewGridLayout*)layout heightForItemAtIndexPath:(NSIndexPath*)indexPath withWidth:(CGFloat)width
{
    return [self heightForItemAtIndexPath:indexPath withWidth:width];
}

- (NSUInteger)collectionView:(UICollectionView*)collectionView layout:(MITCollectionViewGridLayout*)layout featuredStoryVerticalSpanInSection:(NSInteger)section
{
    if ([self isFeaturedCategoryInSection:section]) {
        return 2;
    } else {
        return 0;
    }
}

- (NSUInteger)collectionView:(UICollectionView*)collectionView layout:(MITCollectionViewGridLayout*)layout featuredStoryHorizontalSpanInSection:(NSInteger)section
{
    if ([self isFeaturedCategoryInSection:section]) {
        return 2;
    } else {
        return 0;
    }
}

#pragma mark MITNewsStory delegate/datasource passthru methods
- (NSUInteger)numberOfCategories
{
    if ([self.dataSource respondsToSelector:@selector(numberOfCategoriesInViewController:)]) {
        return [self.dataSource numberOfCategoriesInViewController:self];
    } else {
        return 0;
    }
}

- (BOOL)isFeaturedCategoryInSection:(NSUInteger)index
{
    if ([self.dataSource respondsToSelector:@selector(viewController:isFeaturedCategoryInSection:)]) {
        return [self.dataSource viewController:self isFeaturedCategoryInSection:index];
    } else {
        return NO;
    }
}

- (NSString*)titleForCategoryInSection:(NSUInteger)section
{
    if ([self.dataSource respondsToSelector:@selector(viewController:titleForCategoryInSection:)]) {
        return [self.dataSource viewController:self titleForCategoryInSection:section];
    } else {
        return nil;
    }
}

- (NSUInteger)numberOfStoriesForCategoryInSection:(NSUInteger)section
{
    if ([self.dataSource respondsToSelector:@selector(viewController:numberOfStoriesForCategoryInSection:)]) {
        return [self.dataSource viewController:self numberOfStoriesForCategoryInSection:section];
    } else {
        return 0;
    }
}

- (MITNewsStory*)storyAtIndexPath:(NSIndexPath*)indexPath
{
    if ([self.dataSource respondsToSelector:@selector(viewController:storyAtIndex:forCategoryInSection:)]) {
        return [self.dataSource viewController:self storyAtIndex:indexPath.item forCategoryInSection:indexPath.section];
    } else {
        return nil;
    }
}

- (void)didSelectStoryAtIndexPath:(NSIndexPath*)indexPath
{
    if ([self.delegate respondsToSelector:@selector(viewController:didSelectStoryAtIndex:forCategoryInSection:)]) {
        [self.delegate viewController:self didSelectStoryAtIndex:indexPath.item forCategoryInSection:indexPath.section];
    }
}

- (void)didSelectCategoryInSection:(NSUInteger)section
{
    if ([self.delegate respondsToSelector:@selector(viewController:didSelectCategoryInSection:)]) {
        [self.delegate viewController:self didSelectCategoryInSection:section];
    }
}

@end
