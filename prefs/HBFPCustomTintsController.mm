#import "HBFPCustomTintsController.h"

@implementation HBFPCustomTintsController
-(id)initForContentSize:(CGSize)size {
	self = [super init];
	if (self) {
		tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) style:UITableViewStyleGrouped];
		tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		tableView.delegate = self;
		tableView.dataSource = self;
		//self.navigationItem.title = @"Custom Tints";
		isLoading = YES;
	}
	return self;
}
-(UIView *)view {
	return tableView;
}
-(CGSize)contentSize {
	return tableView.frame.size;
}
-(void)loadFromSpecifier:(PSSpecifier *)specifier {
	[self performSelectorInBackground:@selector(getApps) withObject:nil];
}
-(void)viewWillBecomeVisible:(void *)source {
	if (source) {
		[self loadFromSpecifier:(PSSpecifier *)source];
	}
	[super viewWillBecomeVisible:source];
}
-(void)pushController:(id)controller {
	[super pushController:controller];
	[controller setParentController:self];
}
-(void)getApps {

}
-(NSInteger)numberOfSectionsInTableView:(UITableView *)table {
	return 1;
}
-(NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
	return isLoading ? 0 : apps.count;
}
-(NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
	return isLoading ? @"Loading..." : nil;
}
-(UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index {
	UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"FlagPaintAppCell"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FlagPaintAppCell"];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	cell.textLabel.text = [[apps objectAtIndex:index.row] objectAtIndex:1];
	cell.iconView.image = nil;
	return cell;
}
-(void)addToggle {
	/*TogglerSettingsViewController *add = [[TogglerSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
	UINavigationController *addCtrl = [[UINavigationController alloc] initWithRootViewController:add];
	[self.navigationController presentModalViewController:addCtrl animated:YES];*/
}
@end
