#import "HBFPListController.h"
#include <notify.h>

@implementation HBFPListController
-(id)specifiers {
	if (!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"FlagPaint" target:self] retain];
	}
	return _specifiers;
}
-(void)follow {
	if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot:"]]) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tweetbot:///user_profile/hbangws"]];
	} else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetings:"]]) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tweetings:///user?screen_name=hbangws"]];
	} else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter:"]]) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"twitter://user?screen_name=hbangws"]];
	} else {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://twitter.com/intent/follow?screen_name=hbangws"]];
	}
}
-(void)showTestBanner {
	notify_post("ws.hbang.flagpaint/TestBanner");
}
@end