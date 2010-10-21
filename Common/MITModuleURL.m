#import "MITModuleURL.h"
#import "MITModuleList.h"

@implementation MITModuleURL
@synthesize path, query;

- (id) initWithTag:(NSString *)tag {
	return [self initWithTag:tag path:@"" query:nil];
}

- (id) initWithTag:(NSString *)tag path:(NSString *)aPath query:(NSString *)aQuery {
	if(self = [super init]) {
		[self setPath:aPath query:aQuery];
		moduleTag = [tag retain];
	}
	return self;
}

- (void) dealloc {
	[path release];
	[query release];
	[moduleTag release];
	[super dealloc];
}

- (void) setPath:(NSString *)aPath query:(NSString *)aQuery {
	if (path != aPath) {
		[path release];
		path = [aPath retain];
	}
	
	if (!aQuery) {
		aQuery = @"";
	}

	if (query != aQuery) {
		[query release];
		query = [aQuery retain];
	}
}
	
- (void) setPathWithViewController:(UIViewController *)viewController extension:(NSString *)extension {
	UIViewController *parentController = [[MIT_MobileAppDelegate moduleForTag:moduleTag] parentForViewController:viewController];
	parentController.view;// make sure the parent view controller has loaded (so that the url is defined)
	MITModuleURL *parentURL = ((id<MITModuleURLContainer>)parentController).url;
	[self setPath:[NSString stringWithFormat:@"%@/%@", parentURL.path, extension] query:nil];
}
	
- (void) setAsModulePath {
	MITModule *module = [MIT_MobileAppDelegate moduleForTag:moduleTag];
	module.currentPath = path;
	module.currentQuery = query;
	//NSLog(@"Just saved module state: %@, %@  for module: %@", module.currentPath, module.currentQuery, module);
}

@end
