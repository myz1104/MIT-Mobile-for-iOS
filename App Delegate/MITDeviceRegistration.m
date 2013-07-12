#import "MITDeviceRegistration.h"
#import "MobileRequestOperation.h"

#define APPLE @"apple"
#define DEVICE_TYPE_KEY @"device_type"

@implementation MITIdentity
@synthesize deviceID, passKey;

- (id) initWithDeviceId: (NSString *)aDeviceId passKey: (NSString *)aPassKey {
	self = [super init];
	if (self) {
		deviceID = [aDeviceId retain];
		passKey = [aPassKey retain];
	}
	return self;
}

- (NSMutableDictionary *) mutableDictionary {
	NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
	[mutableDictionary setObject:deviceID forKey:MITDeviceIdKey];
	[mutableDictionary setObject:passKey forKey:MITPassCodeKey];
	[mutableDictionary setObject:APPLE forKey:DEVICE_TYPE_KEY];
	return mutableDictionary;
}

- (void) dealloc {
	[deviceID release];
	[passKey release];
	[super dealloc];
}

@end

@implementation MITDeviceRegistration

+ (NSString *) stringFromToken: (NSData *)deviceToken {
	NSString *hex = [deviceToken description]; // of the form "<21d34 2323a 12324>"
	// eliminate the "<" and ">" and " "
	hex = [hex stringByReplacingOccurrencesOfString:@"<" withString:@""];
	hex = [hex stringByReplacingOccurrencesOfString:@">" withString:@""];
	hex = [hex stringByReplacingOccurrencesOfString:@" " withString:@""];
	return hex;
}
	
+ (void) registerNewDeviceWithToken: (NSData *)deviceToken {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
	if(deviceToken) {
		[parameters setObject:[self stringFromToken:deviceToken] forKey:@"device_token"];
		[parameters setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"] forKey:@"app_id"];
	}
    
    MobileRequestOperation *request = [[[MobileRequestOperation alloc] initWithRelativePath:[NSString stringWithFormat:@"/apis/apps/push/devices/%@",
                                                                                             APPLE] parameters:parameters] autorelease];
    // TODO: check with MIT provisioning profile
    request.usePOST = YES;
    request.completeBlock = ^(MobileRequestOperation *operation, id jsonResult, NSString *contentType, NSError *error) {
        if (error) {
            
        } else {
            [[NSUserDefaults standardUserDefaults] setObject:deviceToken forKey:DeviceTokenKey];
            
            if ([jsonResult isKindOfClass:[NSDictionary class]]) {
                NSDictionary *jsonDict = jsonResult;
                [[NSUserDefaults standardUserDefaults] setObject:[jsonDict objectForKey:MITDeviceIdKey] forKey:MITDeviceIdKey];
                [[NSUserDefaults standardUserDefaults] setObject:[jsonDict objectForKey:MITPassCodeKey] forKey:MITPassCodeKey];
            }
        }
    };
    [[NSOperationQueue mainQueue] addOperation:request];
}

+ (void) newDeviceToken: (NSData *)deviceToken {
	NSMutableDictionary *parameters = [[self identity] mutableDictionary];
	[parameters setObject:[self stringFromToken:deviceToken] forKey:@"device_token"];
	[parameters setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"] forKey:@"app_id"];
    [parameters setObject:[[NSUserDefaults standardUserDefaults] objectForKey:MITPassCodeKey] forKey:@"pass_key"];
    NSString *device_id = [[NSUserDefaults standardUserDefaults] objectForKey:MITDeviceIdKey];
    
    MobileRequestOperation *request = [[[MobileRequestOperation alloc] initWithRelativePath:[NSString stringWithFormat:@"apis/apps/push/devices/%@/%@", APPLE, device_id] parameters:parameters] autorelease];
    request.usePUT = YES;
    request.completeBlock = ^(MobileRequestOperation *operation, id jsonResult, NSString *contentType, NSError *error) {
        if (error) {

        } else {
            [[NSUserDefaults standardUserDefaults] setObject:deviceToken forKey:DeviceTokenKey];
            
            if ([jsonResult isKindOfClass:[NSDictionary class]]) {
                NSDictionary *jsonDict = jsonResult;
                [[NSUserDefaults standardUserDefaults] setObject:[jsonDict objectForKey:MITDeviceIdKey] forKey:MITDeviceIdKey];
                [[NSUserDefaults standardUserDefaults] setObject:[jsonDict objectForKey:MITPassCodeKey] forKey:MITPassCodeKey];
            }
        }
    };
    [[NSOperationQueue mainQueue] addOperation:request];
}
	
+ (MITIdentity *) identity {
	NSString *deviceId = [[[NSUserDefaults standardUserDefaults] objectForKey:MITDeviceIdKey] description];
	NSString *passKey = [[[NSUserDefaults standardUserDefaults] objectForKey:MITPassCodeKey] description];

	if(deviceId) {
		return [[[MITIdentity alloc] initWithDeviceId:deviceId passKey:passKey] autorelease];
	} else {
		return nil;
	}
}
@end
