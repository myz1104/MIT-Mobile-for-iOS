//
//  DiningHallMenuCompareLayout.m
//  MIT Mobile
//
//  Created by Austin Emmons on 4/22/13.
//
//

#import "DiningHallMenuCompareLayout.h"
#import "PSTCollectionView.h"

NSString * const MITDiningMenuComparisonCellKind = @"DiningMenuCell";
NSString * const MITDiningMenuComparisonSectionHeaderKind = @"DiningMenuSectionHeader";

@interface DiningHallMenuCompareLayout ()

@property (nonatomic) UIEdgeInsets itemInsets;
@property (nonatomic) CGSize itemSize;
@property (nonatomic) CGFloat interItemSpacingY;
@property (nonatomic) NSInteger numberOfColumns;
@property (nonatomic) CGFloat heightOfSectionHeader;

@property (nonatomic, strong) NSDictionary *layoutInfo;

@end

@implementation DiningHallMenuCompareLayout

- (void) setup
{
    // layout some default values
    self.itemInsets = UIEdgeInsetsMake(0, 1, 0, 1);
    self.itemSize = CGSizeMake(60, 40);
    self.interItemSpacingY = 5;
    self.numberOfColumns = 5;
    self.heightOfSectionHeader = 48;
}

- (id) init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (id<CollectionViewDelegateMenuCompareLayout>) layoutDelegate
{
    // Helper method to get delegate
    return (id<CollectionViewDelegateMenuCompareLayout>)self.collectionView.delegate;
}

- (void) prepareLayout
{
    NSMutableDictionary *newLayoutInfo = [NSMutableDictionary dictionary];
    NSMutableDictionary *cellLayoutInfo = [NSMutableDictionary dictionary];
    NSMutableDictionary *headerLayoutInfo = [NSMutableDictionary dictionary];
    
    NSInteger sectionCount = [self.collectionView numberOfSections];
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
    
    for (NSInteger section = 0; section < sectionCount; section++) {
        NSInteger itemCount = [self.collectionView numberOfItemsInSection:section];
        
        for (NSInteger item = 0; item < itemCount; item++) {
            indexPath = [NSIndexPath indexPathForRow:item inSection:section];
            
            PSTCollectionViewLayoutAttributes *itemAttributes = [PSTCollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            itemAttributes.frame = [self frameForMenuItemAtIndexPath:indexPath inLayoutSet:newLayoutInfo];
            
            cellLayoutInfo[indexPath] = itemAttributes;
            
            if (indexPath.row == 0) {
                PSTCollectionViewLayoutAttributes *headerAttributes = [PSTCollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:MITDiningMenuComparisonSectionHeaderKind withIndexPath:indexPath];
                headerAttributes.frame = [self frameForHeaderAtIndexPath:indexPath];
                
                headerLayoutInfo[indexPath] = headerAttributes;
                newLayoutInfo[MITDiningMenuComparisonSectionHeaderKind] = headerLayoutInfo;
            }
            
            newLayoutInfo[MITDiningMenuComparisonCellKind] = cellLayoutInfo;
        }
    }
    
    self.layoutInfo = newLayoutInfo;
}

- (CGRect) frameForMenuItemAtIndexPath:(NSIndexPath *)indexPath inLayoutSet:(NSDictionary *)layoutDictionary
{

    CGFloat itemHeight = [[self layoutDelegate] collectionView:self.collectionView layout:self heightForItemAtIndexPath:indexPath];
    
    if (indexPath.row == 0) {
        // first item in section. should be placed at top, just under sectionHeader
        return CGRectMake(self.columnWidth * indexPath.section, self.heightOfSectionHeader, self.columnWidth, itemHeight);
    } else {
        // not first item in section. need to look back and place directly below previous frame
        NSDictionary *cellLayoutInfo = layoutDictionary[MITDiningMenuComparisonCellKind];
        NSIndexPath *previousIndexPath = [NSIndexPath indexPathForItem:indexPath.row - 1 inSection:indexPath.section];
        PSTCollectionViewLayoutAttributes *previousItemAttributes = cellLayoutInfo[previousIndexPath];
        CGRect previousFrame = previousItemAttributes.frame;
        
        return CGRectMake(previousFrame.origin.x, previousFrame.origin.y + previousFrame.size.height, self.columnWidth, itemHeight);
    }
    
    return CGRectZero;
}

- (CGRect) frameForHeaderAtIndexPath:(NSIndexPath *)indexPath
{
    CGRect frame = CGRectMake(self.columnWidth * indexPath.section, 0, self.columnWidth, self.heightOfSectionHeader);
    return frame;
}

- (NSArray *) layoutAttributesForElementsInRect:(CGRect)rect
{
    NSMutableArray *allAttributes = [NSMutableArray arrayWithCapacity:self.layoutInfo.count];
    
    [self.layoutInfo enumerateKeysAndObjectsUsingBlock:^(NSString *elementsIdentifier, NSDictionary *elementsInfo, BOOL *stop) {
        
        [elementsInfo enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *indexPath, PSTCollectionViewLayoutAttributes *attributes, BOOL *innerstop) {
            if (CGRectIntersectsRect(rect, attributes.frame)) {
                [allAttributes addObject:attributes];
            }
        }];
    }];
    
    return allAttributes;
}

- (PSTCollectionViewLayoutAttributes *) layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return self.layoutInfo[MITDiningMenuComparisonCellKind][indexPath];
}

- (PSTCollectionViewLayoutAttributes *) layoutAttributesForSupplementaryViewOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    return self.layoutInfo[MITDiningMenuComparisonSectionHeaderKind][indexPath];
}

- (CGSize) collectionViewContentSize
{
    __block CGFloat height = 0;
    
    // get max Y for the tallest column. return collectionView width and calculated height
    [self.layoutInfo enumerateKeysAndObjectsUsingBlock:^(NSString *elementsIdentifier, NSDictionary *elementsInfo, BOOL *stop) {
        [elementsInfo enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *indexPath, PSTCollectionViewLayoutAttributes *attributes, BOOL *innerstop) {
            CGFloat tempHeight = CGRectGetMaxY(attributes.frame);
            if (tempHeight > height) {
                height = tempHeight;
            }
        }];
    }];
    
    return CGSizeMake(CGRectGetWidth(self.collectionView.bounds), height);
}




@end