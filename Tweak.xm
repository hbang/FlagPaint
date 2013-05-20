#import "HBFPBlurryLabel.h"
#import <substrate.h> // >_>
#import <QuartzCore/QuartzCore.h>

@interface BBBulletin : NSObject
-(NSString *)sectionID;
@end

@interface SBBulletinBannerController : NSObject
+(id)sharedInstance;
-(void)showTestBanner;
@end

@interface SBBulletinBannerItem : NSObject
-(BBBulletin *)seedBulletin;
@end

@interface SBBannerView : UIView //5.x
@end

@interface SBBulletinBannerView : SBBannerView //6.x
@end

@interface SBApplication : NSObject
-(NSString *)bundleIdentifier;
@end

@interface SBApplicationController : NSObject
+(id)sharedInstance;
-(SBApplication *)applicationWithDisplayIdentifier:(NSString *)displayIdentifier;
@end

@interface SBApplicationIcon : NSObject
-(id)initWithApplication:(SBApplication *)application;
-(UIImage *)getIconImage:(int)image;
@end

@interface SBMediaController : NSObject
+(id)sharedInstance;
-(NSDictionary *)_nowPlayingInfo;
-(SBApplication *)nowPlayingApplication;
-(NSString *)nowPlayingTitle;
-(NSString *)nowPlayingArtist;
-(NSString *)nowPlayingAlbum;
@end

static NSDictionary *prefs;
static NSMutableDictionary *cache = [[NSMutableDictionary alloc] init];
static BOOL hasDietBulletin = NO;

#define IS_IOS_6 kCFCoreFoundationVersionNumber >= 793
#define GET_BOOL(key, default) ([prefs objectForKey:key] ? [[prefs objectForKey:key] boolValue] : default)

struct pixel {
	unsigned char r, g, b, a;
};

static UIColor* HBFPGetDominant(UIImage *image) {
	NSUInteger red = 0, green = 0, blue = 0;

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

static void HBFPBannerInit(SBBannerView *banner, SBBulletinBannerItem *item) {
	HBFPBlurryLabel *titleLabel = MSHookIvar<HBFPBlurryLabel *>(banner, "_titleLabel");
	HBFPBlurryLabel *messageLabel = MSHookIvar<HBFPBlurryLabel *>(banner, "_messageLabel");
	UIImageView *iconView = MSHookIvar<UIImageView *>(banner, "_iconView");

	if (GET_BOOL(@"Tint", YES)) {
		UIImageView *bannerView = MSHookIvar<UIImageView *>(banner, IS_IOS_6 ? "_backgroundImageView" : "_bannerView");

		BOOL isMusic = NO;

		if (!GET_BOOL(@"OldStyle", NO)) {
			isMusic = GET_BOOL(@"AlbumArt", YES) && [[%c(SBMediaController) sharedInstance] nowPlayingApplication] && [[%c(SBMediaController) sharedInstance] nowPlayingApplication].class == %c(SBApplication) && [item.seedBulletin.sectionID isEqualToString:[[[%c(SBMediaController) sharedInstance] nowPlayingApplication] bundleIdentifier]] && [[[%c(SBMediaController) sharedInstance] _nowPlayingInfo] objectForKey:@"artworkData"];

			CAGradientLayer *imageGradientLayer = [CAGradientLayer layer];
			imageGradientLayer.colors = @[(id)[UIColor whiteColor].CGColor, (id)[UIColor clearColor].CGColor];
			imageGradientLayer.startPoint = CGPointMake(0.5f, 0.5f);
			imageGradientLayer.endPoint = CGPointMake(1.f, 0.5f);
			iconView.layer.mask = imageGradientLayer;

			NSString *key = [@"FPICON_" stringByAppendingString:isMusic ? [NSString stringWithFormat:@"FPMUSIC_%@%@%@%@", [[[%c(SBMediaController) sharedInstance] nowPlayingApplication] bundleIdentifier], [[%c(SBMediaController) sharedInstance] nowPlayingTitle], [[%c(SBMediaController) sharedInstance] nowPlayingArtist], [[%c(SBMediaController) sharedInstance] nowPlayingAlbum]] : item.seedBulletin.sectionID];

			if ([cache objectForKey:key]) {
				iconView.image = [cache objectForKey:key];
			} else if (isMusic) {
				iconView.image = [UIImage imageWithData:[[[%c(SBMediaController) sharedInstance] _nowPlayingInfo] objectForKey:@"artworkData"]];
				[cache setObject:[iconView.image retain] forKey:key];
			} else {
				SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:item.seedBulletin.sectionID];

				if (app) {
					SBApplicationIcon *appIcon = [[%c(SBApplicationIcon) alloc] initWithApplication:app];
					[app release];
					UIImage *icon = [appIcon getIconImage:1];

					if (icon) {
						[appIcon release];

						iconView.image = icon;
						[cache setObject:[icon retain] forKey:key];
					}
				}
			}
		}

		iconView.layer.cornerRadius = 5.f;

		UIColor *tint = [UIColor whiteColor];

		/*NSArray *colors = [prefs objectForKey:[NSString stringWithFormat:@"Tint-%@", item.seedBulletin.sectionID]];

		if (colors && colors.count == 3) {
			tint = [UIColor colorWithRed:[[colors objectAtIndex:0] floatValue] green:[[colors objectAtIndex:1] floatValue] blue:[[colors objectAtIndex:2] floatValue] alpha:1];
		} else {*/
			NSString *key = isMusic ? [NSString stringWithFormat:@"FPMUSIC_%@%@%@%@", [[[%c(SBMediaController) sharedInstance] nowPlayingApplication] bundleIdentifier], [[%c(SBMediaController) sharedInstance] nowPlayingTitle], [[%c(SBMediaController) sharedInstance] nowPlayingArtist], [[%c(SBMediaController) sharedInstance] nowPlayingAlbum]] : item.seedBulletin.sectionID;

			if ([cache objectForKey:key]) {
				tint = [cache objectForKey:key];
			} else {
				tint = HBFPGetDominant(iconView.image) ?: [UIColor whiteColor];

				[cache setObject:[tint retain] forKey:key];
			}
		//}

		bannerView.image = nil;
		bannerView.layer.cornerRadius = 5.f;
		banner.layer.cornerRadius = 5.f;

		if (!GET_BOOL(@"OldStyle", NO)) {
			float hue, saturation, brightness, alpha;

			if ([tint getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
				bannerView.layer.borderColor = [UIColor colorWithHue:hue saturation:saturation brightness:MIN(1, brightness * 1.08f) alpha:0.9f].CGColor;
				bannerView.layer.borderWidth = 1.f;

				UIView *gradientView = [[UIView alloc] initWithFrame:banner.frame];
				gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
				gradientView.layer.cornerRadius = 5.f;

				CAGradientLayer *gradientLayer = [CAGradientLayer layer];
				gradientLayer.locations = @[@0, @1];
				gradientLayer.colors = @[(id)[UIColor colorWithHue:hue saturation:saturation brightness:MIN(1, brightness * 2.f) alpha:alpha].CGColor, (id)tint.CGColor];
				gradientLayer.cornerRadius = 5.f;
				[gradientView.layer addSublayer:gradientLayer];

				objc_setAssociatedObject(banner, "flagPaint_backgroundGradient", [gradientLayer retain], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

				[bannerView addSubview:gradientView];
			}

			object_setClass(titleLabel, HBFPBlurryLabel.class);
			object_setClass(messageLabel, HBFPBlurryLabel.class);
		} else {
			bannerView.backgroundColor = tint;
		}

		titleLabel.textColor = [UIColor whiteColor];
		messageLabel.textColor = [UIColor whiteColor];
	}

	if (GET_BOOL(@"CenterText", YES) && !hasDietBulletin) {
		titleLabel.textAlignment = UITextAlignmentCenter;
		messageLabel.textAlignment = UITextAlignmentCenter;
	}

	if (GET_BOOL(@"Semitransparent", YES)) {
		UIView *underlayView = MSHookIvar<UIView *>(banner, "_underlayView");
		underlayView.backgroundColor = [UIColor clearColor];
	}

	if (GET_BOOL(@"Fade", YES)) {
		banner.alpha = 0.f;
	} else if (GET_BOOL(@"Semitransparent", YES)) {
		banner.alpha = 0.9f;
	}
}

static void HBFPBannerLayoutSubviews(SBBannerView *banner) {
	CAGradientLayer *gradientLayer = objc_getAssociatedObject(banner, "flagPaint_backgroundGradient");

	if (gradientLayer) {
		gradientLayer.frame = CGRectMake(0, 0, banner.frame.size.width, banner.frame.size.height);
	}

	if (![objc_getAssociatedObject(banner, "flagPaint_hasLaidOutSubviews") boolValue]) {
		objc_setAssociatedObject(banner, "flagPaint_hasLaidOutSubviews", [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_ASSIGN);

		if (GET_BOOL(@"Fade", YES)) {
			[UIView animateWithDuration:0.85f animations:^{
				banner.alpha = GET_BOOL(@"Semitransparent", YES) ? 0.9f : 1.f;
			}];
		}

		if (GET_BOOL(@"RemoveIcon", NO)) {
			UILabel *titleLabel = MSHookIvar<UILabel *>(banner, "_titleLabel");
			UILabel *messageLabel = MSHookIvar<UILabel *>(banner, "_messageLabel");
			UIImageView *iconView = MSHookIvar<UIImageView *>(banner, "_iconView");

			CGRect titleFrame = titleLabel.frame;
			float oldX = titleFrame.origin.x;
			titleFrame.origin.x = iconView.frame.origin.x;
			titleFrame.size.width += oldX - titleFrame.origin.x;
			titleLabel.frame = titleFrame;

			if (IS_IOS_6) {
				UIImageView *accessoryImageView = MSHookIvar<UIImageView *>(banner, "_accessoryImageView");

				CGRect accessoryFrame = accessoryImageView.frame;
				accessoryFrame.origin.x -= oldX - iconView.frame.origin.x;
				accessoryImageView.frame = accessoryFrame;
			}

			CGRect messageFrame = messageLabel.frame;

			if (hasDietBulletin) {
				messageFrame.origin.x -= oldX - titleFrame.origin.x;
			} else {
				oldX = messageFrame.origin.x;
				messageFrame.origin.x = iconView.frame.origin.x;
				messageFrame.size.width += oldX - messageFrame.origin.x;
			}

			messageLabel.frame = messageFrame;

			iconView.hidden = YES;
		}
	}

	if (GET_BOOL(@"CenterText", YES)) {
		UILabel *titleLabel = MSHookIvar<UILabel *>(banner, "_titleLabel");
		UILabel *messageLabel = MSHookIvar<UILabel *>(banner, "_messageLabel");
		UIImageView *accessoryImageView = IS_IOS_6 ? MSHookIvar<UIImageView *>(banner, "_accessoryImageView") : nil;

		if (hasDietBulletin) {
			float titleWidth = titleLabel.hidden ? 0 : [titleLabel.text sizeWithFont:titleLabel.font].width;
			float messageWidth = [messageLabel.text sizeWithFont:messageLabel.font].width;

			if (titleWidth + 6.f + messageWidth < banner.frame.size.width - 16.f) {
				UIView *containerView = [[UIView alloc] init];
				containerView.tag = 1337;

				[titleLabel removeFromSuperview];
				[containerView addSubview:titleLabel];
				[messageLabel removeFromSuperview];
				[containerView addSubview:messageLabel];
				[banner addSubview:containerView];

				CGRect titleFrame = titleLabel.frame;
				titleFrame.origin.x = 0;
				titleFrame.size.width = titleWidth;
				titleLabel.frame = titleFrame;

				CGRect messageFrame = messageLabel.frame;
				messageFrame.origin.x = titleWidth + 6.f;
				messageFrame.size.width = messageWidth;
				messageLabel.frame = messageFrame;

				containerView.frame = CGRectMake(0, 0, titleWidth + 6.f + messageWidth, banner.frame.size.height);
				containerView.center = CGPointMake(banner.frame.size.width / 2, containerView.center.y);

				[containerView release];
			}
		} else if (accessoryImageView) {
			CGRect titleFrame = titleLabel.frame;
			titleFrame.size.width = messageLabel.frame.size.width;
			titleLabel.frame = titleFrame;

			CGRect accessoryFrame = accessoryImageView.frame;
			accessoryFrame.origin.x = titleLabel.center.x + ([titleLabel.text sizeWithFont:titleLabel.font].width / 2) + 4.f;
			accessoryImageView.frame = accessoryFrame;
		}
	}

	if (GET_BOOL(@"Tint", YES) && !GET_BOOL(@"OldStyle", NO) && !GET_BOOL(@"RemoveIcon", NO)) {
		UIImageView *iconView = MSHookIvar<UIImageView *>(banner, "_iconView");

		iconView.frame = CGRectMake(-1.f, -1.f, banner.frame.size.height + 2.f, banner.frame.size.height + 2.f);
		iconView.layer.mask.frame = iconView.frame;
	}
}

%group HBFPiOS5
%hook SBBannerView
-(id)initWithItem:(SBBulletinBannerItem *)item {
	self = %orig;

	if (self) {
		HBFPBannerInit(self, item);
	}

	return self;
}

-(void)layoutSubviews {
	%orig;

	HBFPBannerLayoutSubviews(self);
}
%end
%end

%group HBFPiOS6
%hook SBBulletinBannerView
-(id)initWithItem:(SBBulletinBannerItem *)item {
	self = %orig;

	if (self) {
		HBFPBannerInit((SBBannerView *)self, item);
	}

	return self;
}

-(void)layoutSubviews {
	%orig;

	HBFPBannerLayoutSubviews((SBBannerView *)self);
}
%end
%end

static void HBFPLoadPrefs() {
	prefs = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/ws.hbang.flagpaint.plist"];
}

static void HBFPShowTestBanner() {
	[[%c(SBBulletinBannerController) sharedInstance] showTestBanner];
}

%ctor{
	%init;

	if (IS_IOS_6) {
		%init(HBFPiOS6);
	} else {
		%init(HBFPiOS5);
	}

	HBFPLoadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, 0);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, 0);
	hasDietBulletin = [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/DietBulletin.dylib"];
}
