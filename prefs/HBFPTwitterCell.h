@interface PSSpecifier : NSObject
-(id)properties;
@end

@interface PSTableCell : UITableViewCell
-(id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier;
@end

@interface HBFPTwitterCell : PSTableCell {
	UIButton *_twitterButton;
	UIView *_underlineView;
	NSString *_user;
}
@end
