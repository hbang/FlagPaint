#import "HBFPListController.h"
#include <notify.h>

@implementation HBFPListController
-(id)specifiers {
	if (!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"FlagPaint" target:self] retain];

		if (access("/var/lib/dpkg/info/org.thebigboss.flagpaint.list", F_OK) == -1) {
			UIAlertView *sadFace = [[[UIAlertView alloc] initWithTitle:@"Please purchase FlagPaint." message:@"We've detected that your copy of FlagPaint is pirated. We won't prevent you from using it, but please note that we don't provide support for pirated packages and aren't responsible if any problems occur." delegate:self cancelButtonTitle:@"I Agree" otherButtonTitles:@"Purchase FlagPaint", @"Try FlagPaint Lite", nil] autorelease];
			[sadFace show];
		}
	}

	return _specifiers;
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	switch (buttonIndex) {
		case 1:
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/org.thebigboss.flagpaint"]];
			break;

		case 2:
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/ws.hbang.flagpaintlite"]];
			break;
	}
}

-(void)showTestBanner {
	notify_post("ws.hbang.flagpaint/TestBanner");
}
@end
