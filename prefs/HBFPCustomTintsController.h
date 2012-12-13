#import "TogglerGlobal.h"

@interface HBFPCustomTintsController : PSViewController <UITableViewDelegate, UITableViewDataSource> {
	UITableView *tableView;
	NSMutableArray *apps;
}
@end
