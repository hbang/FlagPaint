//#import "UIColor-Expanded.h"
#import "HBFPColorArt.h"

@interface SBBulletinBannerController : NSObject
+(SBBulletinBannerController *)sharedInstance;
-(void)showTestBanner;
@end

@interface SBBulletinBannerItem : NSObject
@property (nonatomic, retain) UIImage *iconImage;
@property (nonatomic, retain) NSString *_appName;
@end

@interface SBBannerView : UIView
@end

@interface SBBulletinBannerView : UIView
@end

static NSDictionary *prefs;
static BOOL hasDietBulletin = NO;

struct pixel {
    unsigned char r, g, b, a;
};

#define getBool(key, default) [prefs objectForKey:key] ? [[prefs objectForKey:key] boolValue] : default

static UIColor *HBFPGetDominant(UIImage *image) {
	NSUInteger red = 0;
	NSUInteger green = 0;
	NSUInteger blue = 0;

	struct pixel *pixels = (struct pixel *) calloc(1, image.size.width * image.size.height * sizeof(struct pixel));
	if (pixels != nil) {
		CGContextRef context = CGBitmapContextCreate((void *) pixels, image.size.width, image.size.height, 8, image.size.width * 4, CGImageGetColorSpace(image.CGImage), kCGImageAlphaPremultipliedLast);

		if (context != NULL) {
			CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);

			NSUInteger numberOfPixels = image.size.width * image.size.height;
			for (unsigned i = 0; i < numberOfPixels; i++) {
				red += pixels[i].r;
				green += pixels[i].g;
				blue += pixels[i].b;
			}

			red /= numberOfPixels;
			green /= numberOfPixels;
			blue /= numberOfPixels;

			CGContextRelease(context);
		}

		free(pixels);
	}
	return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:1];
}

%group FPiOS5
%hook SBBannerView
-(id)initWithItem:(SBBulletinBannerItem *)item {
	self = %orig;
	if (self) {
		UIView *bannerIcon = MSHookIvar<UIImageView *>(self, "_iconView");
		UILabel *titleLabel = MSHookIvar<UILabel *>(self, "_titleLabel");
		UILabel *messageLabel = MSHookIvar<UILabel *>(self, "_messageLabel");

		if (getBool(@"Tint", YES)) {
			UIImageView *bannerView = MSHookIvar<UIImageView *>(self, "_bannerView");
			UIView *underlayView = MSHookIvar<UIView *>(self, "_underlayView");
			UIColor *tint;
			BOOL oldAlgorithm = NO;

			/*if (NSArray *colors = [prefs objectForKey:[NSString stringWithFormat:@"Tint-%@", item._appName]]) {
				tint = [UIColor colorWithRed:[[colors objectAtIndex:0] floatValue] green:[[colors objectAtIndex:1] floatValue] blue:[[colors objectAtIndex:2] floatValue] alpha:1];
				oldAlgorithm = YES;
			} else*/ if (getBool(@"OldAlgorithm", NO)) {
				tint = HBFPGetDominant(item.iconImage);
				oldAlgorithm = YES;
			} else {
				HBFPColorArt *tints = [[HBFPColorArt alloc] initWithImage:item.iconImage];
				tint = tints.backgroundColor;
				titleLabel.textColor = tints.primaryColor;
				messageLabel.textColor = tints.secondaryColor;
			}

			bannerView.image = nil;
			bannerView.backgroundColor = tint;
			underlayView.backgroundColor = [UIColor clearColor];

			if (oldAlgorithm) {
				const CGFloat *components = CGColorGetComponents(tint.CGColor);
				titleLabel.textColor = messageLabel.textColor = ((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000 < 125 ? [UIColor whiteColor] : [UIColor blackColor];
			}
		}

		if (getBool(@"RemoveIcon", NO)) {
			bannerIcon.hidden = YES;
		}

		if (getBool(@"Fade", YES)) {
			self.alpha = 0;
		} else if (getBool(@"Semitransparent", YES)) {
			self.alpha = 0.9f;
		}

		if (getBool(@"Fade", YES)) {
			[UIView animateWithDuration:0.5f animations:^{
				self.alpha = getBool(@"Semitransparent", YES) ? 0.9f : 1;
			}];
		}
	}
	return self;
}

-(void)layoutSubviews {
	%orig;

	UILabel *titleLabel = MSHookIvar<UILabel *>(self, "_titleLabel");
	UILabel *messageLabel = MSHookIvar<UILabel *>(self, "_messageLabel");

	if (getBool(@"RemoveIcon", NO)) {
		CGRect titleFrame = titleLabel.frame;
		titleFrame.origin.x -= hasDietBulletin ? 18.f : 32.f;
		titleFrame.size.width += hasDietBulletin ? 18.f : 32.f;
		titleLabel.frame = titleFrame;

		CGRect messageFrame = messageLabel.frame;
		messageFrame.origin.x -= hasDietBulletin ? 18.f : 32.f;
		messageFrame.size.width += hasDietBulletin ? 18.f : 32.f;
		messageLabel.frame = messageFrame;
	}

	if (getBool(@"CenterText", YES)) {
		if (hasDietBulletin) {
			float titleWidth = titleLabel.hidden ? 0 : [titleLabel.text sizeWithFont:titleLabel.font].width;
			float messageWidth = [messageLabel.text sizeWithFont:messageLabel.font].width;

			if (titleWidth + 6.f + messageWidth < self.frame.size.width - 16.f) {
				UIView *container = [[UIView alloc] init];

				[titleLabel removeFromSuperview];
				[container addSubview:titleLabel];
				[messageLabel removeFromSuperview];
				[container addSubview:messageLabel];
				[self addSubview:[container autorelease]];

				CGRect titleFrame = titleLabel.frame;
				titleFrame.origin.x = 0;
				titleFrame.size.width = titleWidth;
				titleLabel.frame = titleFrame;

				CGRect messageFrame = messageLabel.frame;
				messageFrame.origin.x = titleWidth + 6.f;
				messageFrame.size.width = messageWidth;
				messageLabel.frame = messageFrame;

				CGRect containerFrame = CGRectMake(0, 0, titleWidth + 6.f + messageWidth, self.frame.size.height);
				containerFrame.origin.x = (self.frame.size.width / 2) - (containerFrame.size.width / 2);
				container.frame = containerFrame;
			}
		} else {
			titleLabel.textAlignment = UITextAlignmentCenter;
			messageLabel.textAlignment = UITextAlignmentCenter;
		}
	}
}
%end
%end

%group FPiOS6
%end

static void HBFPLoadPrefs() {
	prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/ws.hbang.flagpaint.plist"];
}

static void HBFPShowTestBanner() {
	[[%c(SBBulletinBannerController) sharedInstance] showTestBanner];
}

%ctor{
	%init;

	if (kCFCoreFoundationVersionNumber >= 793) {
		%init(FPiOS6);
	} else {
		%init(FPiOS5);
	}

	HBFPLoadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, 0);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, 0);
	hasDietBulletin = [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/DietBulletin.dylib"];
}
