#import <CoreData/CoreData.h>
#import <RestKit/RestKit.h>

#import "MITMobiusResourceDataSource.h"
#import "MITCoreData.h"
#import "CoreData+MITAdditions.h"
#import "MITAdditions.h"
#import "MITMobiusResource.h"
#import "MITMobiusRoomSet.h"
#import "MITMobiusResourceType.h"

#import "MITMobiusRecentSearchList.h"
#import "MITMobiusRecentSearchQuery.h"

#import "MITMobileServerConfiguration.h"
#import <objc/runtime.h>

static NSString* const MITMobiusResourcePathPattern = @"resource";
static void const *MITDataSourceCachedObjectsClearedKey = &MITDataSourceCachedObjectsClearedKey;

@interface MITMobiusResourceDataSource ()
@property (nonatomic,strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic,strong) NSOperationQueue *mappingOperationQueue;
@property (copy) NSArray *resourceObjectIdentifiers;
@property (nonatomic,copy) NSString *queryString;
@end

@implementation MITMobiusResourceDataSource
@dynamic resources;

+ (NSURL*)defaultServerURL {
    MITMobileWebServerType serverType = MITMobileWebGetCurrentServerType();

    switch (serverType) {
        case MITMobileWebProduction:
        case MITMobileWebStaging:
        case MITMobileWebDevelopment:
            return [NSURL URLWithString:@"https://kairos-dev.mit.edu"];
    }
}

- (instancetype)init
{
    NSManagedObjectContext *managedObjectContext = [[MITCoreDataController defaultController] newManagedObjectContextWithConcurrencyType:NSPrivateQueueConcurrencyType trackChanges:YES];
    return [self initWithManagedObjectContext:managedObjectContext];
}

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext*)managedObjectContext
{
    NSParameterAssert(managedObjectContext);

    self = [super init];
    if (self) {
        [self clearCachedObjects];
        _managedObjectContext = managedObjectContext;
        _mappingOperationQueue = [[NSOperationQueue alloc] init];
    }

    return self;
}


- (void)clearCachedObjects
{
    // This most likely will be a fairly espensive operation
    // since it involves potentially deleting a large number of
    // CoreData objects (especially with a number of subclasses)
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        id firstRunToken = objc_getAssociatedObject(self, MITDataSourceCachedObjectsClearedKey);
        
        if (!firstRunToken) {
            __block NSError *error = nil;
            
            BOOL updatePassed = [self clearCachedObjectsWithManagedObjectContext:self.managedObjectContext error:nil];
                        
            if (!updatePassed) {
                DDLogWarn(@"failed to clear cached objects %@",[error localizedDescription]);
            }
            
            objc_setAssociatedObject(self, MITDataSourceCachedObjectsClearedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }];
    
    [[NSOperationQueue mainQueue] addOperation:blockOperation];
}

- (BOOL)clearCachedObjectsWithManagedObjectContext:(NSManagedObjectContext*)context error:(NSError**)error
{
    NSFetchRequest *fetchRequestForMobiusRoomSet = [[NSFetchRequest alloc] initWithEntityName:@"MobiusRoomSet"];
    NSFetchRequest *fetchRequestForMobiusResourceType = [[NSFetchRequest alloc] initWithEntityName:@"MobiusResourceType"];
    
    NSArray *fetchRequests = @[fetchRequestForMobiusRoomSet, fetchRequestForMobiusResourceType];
    
    for (NSFetchRequest *fetchRequest in fetchRequests) {
        NSArray *result = [context executeFetchRequest:fetchRequest error:error];
        if (!result) {
            return NO;
        }
        
        [context performBlock:^{
            [result enumerateObjectsUsingBlock:^(NSManagedObject *object, NSUInteger idx, BOOL *stop) {
                [context deleteObject:object];
            }];
        }];
    }
    return YES;
}

- (NSArray*)resources
{
    __block NSArray *resources = nil;
    NSManagedObjectContext *mainQueueContext = [[MITCoreDataController defaultController] mainQueueContext];

    [mainQueueContext performBlockAndWait:^{
        if ([self.resourceObjectIdentifiers count]) {
            NSMutableArray *mutableResources = [[NSMutableArray alloc] init];
            [self.resourceObjectIdentifiers enumerateObjectsUsingBlock:^(NSManagedObjectID *objectID, NSUInteger idx, BOOL *stop) {
                NSManagedObject *object = [mainQueueContext objectWithID:objectID];
                [mutableResources addObject:object];
            }];

            resources = mutableResources;
        }
    }];

    return resources;
}

- (NSDictionary*)resourcesGroupedByKey:(NSString*)key withManagedObjectContext:(NSManagedObjectContext*)context
{
    NSParameterAssert(context);

    if (self.resourceObjectIdentifiers.count > 0) {
        NSMutableDictionary *groupedResources = [[NSMutableDictionary alloc] init];
        [context performBlockAndWait:^{
            [self.resourceObjectIdentifiers enumerateObjectsUsingBlock:^(NSManagedObjectID *objectID, NSUInteger idx, BOOL *stop) {
                NSManagedObject *object = [context existingObjectWithID:objectID error:nil];
                if (object) {
                    id<NSCopying> keyValue = [object valueForKey:key];

                    NSMutableArray *values = groupedResources[keyValue];
                    if (!values) {
                        values = [[NSMutableArray alloc] init];
                        groupedResources[keyValue] = values;
                    }

                    [values addObject:object];
                }
            }];
        }];

        return groupedResources;
    } else {
        return nil;
    }
}

- (void)resourcesWithQuery:(NSString*)queryString completion:(void(^)(MITMobiusResourceDataSource* dataSource, NSError *error))block
{
    if (![queryString length]) {
        self.queryString = nil;
        self.lastFetched = [NSDate date];
        self.resourceObjectIdentifiers = nil;
        [self.managedObjectContext reset];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (block) {
                block(self,nil);
            }
        }];
    } else {
        NSURL *resourceReservations = [MITMobiusResourceDataSource defaultServerURL];
        NSMutableString *urlPath = [NSMutableString stringWithFormat:@"/%@",MITMobiusResourcePathPattern];
#warning temporary fix
        if ([queryString rangeOfString:@"params"].location != NSNotFound) {
            NSString *encodedString = [queryString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            [urlPath appendFormat:@"/?%@&%@",@"format=json",encodedString];
        } else if (queryString) {

            NSString *encodedString = [queryString urlEncodeUsingEncoding:NSUTF8StringEncoding useFormURLEncoded:YES];
            [urlPath appendFormat:@"?%@&q=%@",@"format=json",encodedString];
        }

        NSURL *resourcesURL = [NSURL URLWithString:urlPath relativeToURL:resourceReservations];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:resourcesURL];
        request.HTTPShouldHandleCookies = NO;
        request.HTTPMethod = @"GET";
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

        RKMapping *mapping = [MITMobiusResource objectMapping];
        RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:mapping method:RKRequestMethodAny pathPattern:nil keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];

        RKManagedObjectRequestOperation *requestOperation = [[RKManagedObjectRequestOperation alloc] initWithRequest:request responseDescriptors:@[responseDescriptor]];
        requestOperation.managedObjectContext = self.managedObjectContext;

        RKFetchRequestManagedObjectCache *cache = [[RKFetchRequestManagedObjectCache alloc] init];
        requestOperation.managedObjectCache = cache;

        __weak MITMobiusResourceDataSource *weakSelf = self;
        [requestOperation setCompletionBlockWithSuccess:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
            MITMobiusResourceDataSource *blockSelf = weakSelf;
            if (!blockSelf) {
                return;
            }

            NSManagedObjectContext *context = blockSelf.managedObjectContext;
            [context performBlock:^{
                blockSelf.queryString = queryString;
                blockSelf.lastFetched = [NSDate date];
                blockSelf.resourceObjectIdentifiers = [NSManagedObjectContext objectIDsForManagedObjects:[mappingResult array]];

                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    if (block) {
                        block(blockSelf,nil);
                    }
                }];
            }];
        } failure:^(RKObjectRequestOperation *operation, NSError *error) {
            MITMobiusResourceDataSource *blockSelf = weakSelf;
            if (!blockSelf) {
                return;
            } else {
                DDLogError(@"failed to request Mobius resources: %@",error);
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    if (block) {
                        block(blockSelf,error);
                    }
                }];
            }
        }];

        [self.mappingOperationQueue addOperation:requestOperation];
    }
}

- (void)getObjectsForRoute:(MITMobiusQuickSearchType)type completion:(void(^)(NSArray* objects, NSError *error))block
{
    if (type != MITMobiusQuickSearchRoomSet &&
        type != MITMobiusQuickSearchResourceType) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (block) {
                block(nil,nil);
            }
        }];
    } else {
        NSURL *resourceReservations = [MITMobiusResourceDataSource defaultServerURL];
        NSString *urlPath = nil;
        NSFetchRequest *fetchRequest = nil;
        
        if (type == MITMobiusQuickSearchRoomSet) {
            
            fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"MobiusRoomSet"];

            NSString *encodedString = [@"resourceroomset" urlEncodeUsingEncoding:NSUTF8StringEncoding useFormURLEncoded:YES];
            urlPath = [NSString stringWithFormat:@"/%@?%@",encodedString, @"format=json"];
        } else if (type == MITMobiusQuickSearchResourceType) {
            
            fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"MobiusResourceType"];
            
            NSString *encodedString = [@"resourcetype" urlEncodeUsingEncoding:NSUTF8StringEncoding useFormURLEncoded:YES];
            urlPath = [NSString stringWithFormat:@"/%@?%@",encodedString, @"format=json"];
        }
        
        //Check if objects are already in cache
        NSError *error = nil;
        NSArray *objects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (error) {
            if (block) {
                block(nil,error);
                return;
            }
        }
        if ([objects count]) {
            if (block) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    block(objects,nil);
                }];
                return;
            }
        }
        
        NSURL *resourcesURL = [NSURL URLWithString:urlPath relativeToURL:resourceReservations];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:resourcesURL];
        request.HTTPShouldHandleCookies = NO;
        request.HTTPMethod = @"GET";
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        RKMapping *mapping = nil;
        
        if (type == MITMobiusQuickSearchResourceType) {
            mapping = [MITMobiusResourceType objectMapping];
        } else if (type == MITMobiusQuickSearchRoomSet) {
            mapping = [MITMobiusRoomSet objectMapping];
        }
        
        RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:mapping method:RKRequestMethodAny pathPattern:nil keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        
        RKManagedObjectRequestOperation *requestOperation = [[RKManagedObjectRequestOperation alloc] initWithRequest:request responseDescriptors:@[responseDescriptor]];
        requestOperation.managedObjectContext = self.managedObjectContext;
        
        RKFetchRequestManagedObjectCache *cache = [[RKFetchRequestManagedObjectCache alloc] init];
        requestOperation.managedObjectCache = cache;
        
        __weak MITMobiusResourceDataSource *weakSelf = self;
        [requestOperation setCompletionBlockWithSuccess:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
            MITMobiusResourceDataSource *blockSelf = weakSelf;
            if (!blockSelf) {
                return;
            }
            
            NSManagedObjectContext *context = blockSelf.managedObjectContext;
            [context performBlock:^{
                
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    if (block) {
                        block([mappingResult array],nil);
                    }
                }];
            }];
        } failure:^(RKObjectRequestOperation *operation, NSError *error) {
            
            DDLogError(@"failed to request Mobius resources: %@",error);
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                if (block) {
                    block(nil,error);
                }
            }];
        }];
        
        [self.mappingOperationQueue addOperation:requestOperation];
    }
}

#pragma mark - Recent Search List

- (MITMobiusRecentSearchList *)recentSearchListWithManagedObjectContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[MITMobiusRecentSearchList entityName]];
    NSError *error = nil;
    
    NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
    if (error) {
        return nil;
    } else if ([fetchedObjects count] == 0) {
        return [[MITMobiusRecentSearchList alloc] initWithEntity:[MITMobiusRecentSearchList entityDescription] insertIntoManagedObjectContext:context];
    } else {
        return [fetchedObjects firstObject];
    }
}

#pragma mark - Recent Search Items
- (NSInteger)numberOfRecentSearchItemsWithFilterString:(NSString *)filterString
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[MITMobiusRecentSearchQuery entityName]];
    fetchRequest.resultType = NSCountResultType;
    
    if ([filterString length]) {
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"text BEGINSWITH[cd] %@", filterString];
    }
    
    NSInteger numberOfRecentSearchItems = [[MITCoreDataController defaultController].mainQueueContext countForFetchRequest:fetchRequest error:nil];

    // Don't propogate the error up if things go south.
    // Just catch the bad count and return a 0.
    if (numberOfRecentSearchItems == NSNotFound) {
        return 0;
    } else {
        return numberOfRecentSearchItems;
    }
}

- (NSArray *)recentSearchItemswithFilterString:(NSString *)filterString
{
    NSManagedObjectContext *managedObjectContext = [MITCoreDataController defaultController].mainQueueContext;
    MITMobiusRecentSearchList *recentSearchList = [self recentSearchListWithManagedObjectContext:managedObjectContext];
    NSArray *recentSearchItems = [[recentSearchList.recentQueries reversedOrderedSet] array];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO];
    
    if ([filterString length] > 0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"text BEGINSWITH[cd] %@", filterString];
        return [[recentSearchItems filteredArrayUsingPredicate:predicate] sortedArrayUsingDescriptors:@[sortDescriptor]];
    }
    
    return [[recentSearchList.recentQueries array] sortedArrayUsingDescriptors:@[sortDescriptor]];
}

- (void)addRecentSearchItem:(NSString *)searchTerm error:(NSError**)error
{
    [[MITCoreDataController defaultController] performBackgroundUpdateAndWait:^(NSManagedObjectContext *context, NSError *__autoreleasing *updateError) {
        
        MITMobiusRecentSearchList *recentSearchList = [self recentSearchListWithManagedObjectContext:context];
        NSArray *recentSearchItems = [recentSearchList.recentQueries array];
        
        __block MITMobiusRecentSearchQuery *searchItem = nil;
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"text =[c] %@", searchTerm];
        [recentSearchItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            BOOL objectMatches = [predicate evaluateWithObject:obj];
            if (objectMatches) {
                (*stop) = YES;
                searchItem = (MITMobiusRecentSearchQuery*)obj;
            }
        }];
        
        if (!searchItem) {
            searchItem = [[MITMobiusRecentSearchQuery alloc] initWithEntity:[MITMobiusRecentSearchQuery entityDescription] insertIntoManagedObjectContext:context];
            searchItem.text = searchTerm;
            searchItem.search = recentSearchList;
        }
        
        searchItem.date = [NSDate date];
        return YES;
    } error:error];
}

- (void)clearRecentSearches
{
    [[MITCoreDataController defaultController] performBackgroundUpdateAndWait:^(NSManagedObjectContext *context, NSError **updateError) {
        MITMobiusRecentSearchList *recentSearchList = [self recentSearchListWithManagedObjectContext:context];
        [context deleteObject:recentSearchList];
        recentSearchList = [self recentSearchListWithManagedObjectContext:context];
        
        if (recentSearchList) {
            return YES;
        } else {
            return NO;
        }
    } error:nil];
}

@end
