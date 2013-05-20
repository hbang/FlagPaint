@interface HBFPCustomTintsController : PSViewController <UITableViewDelegate, UITableViewDataSource> {
	UITableView *tableView;
	NSMutableArray *apps;
	BOOL isLoading;
}
@end
