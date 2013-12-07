#import <substrate.h> // >_>
#import <version.h>
#import "HBFPBlurryLabel.h"
#import <BulletinBoard/BBBulletin.h>
#import <QuartzCore/QuartzCore.h>
#import <SpringBoard/SBBulletinBannerController.h>
#import <SpringBoard/SBBulletinBannerItem.h>
#import <SpringBoard/SBBulletinBannerView.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBMediaController.h>

struct pixel {
	unsigned char r, g, b, a;
};

static const char *BackgroundGradientIdentifier = "flagPaint_backgroundGradient";
static const char *HasLaidOutSubviewsIdentifier = "flagPaint_hasLaidOutSubviews";

NSDictionary *prefs;
NSMutableDictionary *cache = [[NSMutableDictionary alloc] init];
BOOL hasDietBulletin = NO;

BOOL shouldTint = YES;
BOOL albumArt = YES;
BOOL oldStyle = NO;
BOOL borderRadius = YES;
BOOL bigIcon = YES;
BOOL semiTransparent = YES;
BOOL removeIcon = NO;
BOOL centerText = NO;
BOOL fadeIn = NO;

#pragma mark - Get dominant color

static UIColor *HBFPGetDominantColor(UIImage *image) {
	NSUInteger red = 0, green = 0, blue = 0;

	pixel *pixels = (pixel *)calloc(1, image.size.width * image.size.height * sizeof(pixel));

	if (pixels) {
		CGContextRef context = CGBitmapContextCreate((void *)pixels, image.size.width, image.size.height, 8.f, image.size.width * 4.f, CGImageGetColorSpace(image.CGImage), kCGImageAlphaPremultipliedLast);

		if (context) {
			CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);

			NSUInteger numberOfPixels = image.size.width * image.size.height;
			for (NSUInteger i = 0; i < numberOfPixels; i++) {
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

	return [UIColor colorWithRed:red / 255.f green:green / 255.f blue:blue / 255.f alpha:1];
}

#pragma mark - Banner hooks

%hook SBBannerView

- (id)initWithItem:(SBBulletinBannerItem *)item {
	self = %orig;

	if (self) {
		HBFPBlurryLabel *titleLabel = MSHookIvar<HBFPBlurryLabel *>(self, "_titleLabel");
		HBFPBlurryLabel *messageLabel = MSHookIvar<HBFPBlurryLabel *>(self, "_messageLabel");
		UIImageView *iconView = MSHookIvar<UIImageView *>(self, "_iconView");

		if (shouldTint) {
			UIImageView *bannerView = MSHookIvar<UIImageView *>(self, IS_IOS_OR_NEWER(iOS_6_0) ? "_backgroundImageView" : "_bannerView");
			BOOL isMusic = !oldStyle && albumArt && [[%c(SBMediaController) sharedInstance] nowPlayingApplication] && [[%c(SBMediaController) sharedInstance] nowPlayingApplication].class == %c(SBApplication) && [item.seedBulletin.sectionID isEqualToString:[[[%c(SBMediaController) sharedInstance] nowPlayingApplication] bundleIdentifier]] && [[[%c(SBMediaController) sharedInstance] _nowPlayingInfo] objectForKey:@"artworkData"];

			if (bigIcon) {
				CAGradientLayer *imageGradientLayer = [CAGradientLayer layer];
				imageGradientLayer.colors = @[ (id)[UIColor whiteColor].CGColor, (id)[UIColor clearColor].CGColor ];
				imageGradientLayer.startPoint = CGPointMake(0.5f, 0.5f);
				imageGradientLayer.endPoint = CGPointMake(1.f, 0.5f);
				iconView.layer.mask = imageGradientLayer;
			}

			if (!oldStyle) {
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
						UIImage *icon = [appIcon getIconImage:SBApplicationIconFormatDefault];

						if (icon) {
							[appIcon release];

							iconView.image = icon;
							[cache setObject:[icon retain] forKey:key];
						}
					}
				}
			}

			UIColor *tint = [UIColor whiteColor];
			NSString *key = isMusic ? [NSString stringWithFormat:@"FPMUSIC_%@%@%@%@", [[[%c(SBMediaController) sharedInstance] nowPlayingApplication] bundleIdentifier], [[%c(SBMediaController) sharedInstance] nowPlayingTitle], [[%c(SBMediaController) sharedInstance] nowPlayingArtist], [[%c(SBMediaController) sharedInstance] nowPlayingAlbum]] : item.seedBulletin.sectionID;
			NSArray *colors = [prefs objectForKey:[NSString stringWithFormat:@"Tint-%@", item.seedBulletin.sectionID]];

			if ([cache objectForKey:key]) {
				tint = [cache objectForKey:key];
			} else if (colors && colors.count == 3) {
				tint = [UIColor colorWithRed:((NSNumber *)[colors objectAtIndex:0]).floatValue green:((NSNumber *)[colors objectAtIndex:1]).floatValue blue:((NSNumber *)[colors objectAtIndex:2]).floatValue alpha:1];
			} else {
				tint = HBFPGetDominantColor(iconView.image) ?: [UIColor whiteColor];
				[cache setObject:[tint retain] forKey:key];
			}

			bannerView.image = nil;

			if (borderRadius) {
				bannerView.layer.cornerRadius = 5.f;
				((SBBannerView *)self).layer.cornerRadius = 5.f;

				if (bigIcon) {
					iconView.layer.cornerRadius = 5.f;
				}
			}

			if (!oldStyle) {
				float hue, saturation, brightness, alpha;

				if ([tint getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
					bannerView.layer.borderColor = [UIColor colorWithHue:hue saturation:saturation brightness:MIN(1, brightness * 1.08f) alpha:0.9f].CGColor;
					bannerView.layer.borderWidth = 1.f;

					UIView *gradientView = [[UIView alloc] initWithFrame:((SBBannerView *)self).frame];
					gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

					CAGradientLayer *gradientLayer = [CAGradientLayer layer];
					gradientLayer.locations = @[ @0, @1 ];
					gradientLayer.colors = @[ (id)[UIColor colorWithHue:hue saturation:saturation brightness:MIN(1, brightness * 2.f) alpha:alpha].CGColor, (id)tint.CGColor ];
					[gradientView.layer addSublayer:gradientLayer];

					if (borderRadius) {
						gradientView.layer.cornerRadius = 5.f;
						gradientLayer.cornerRadius = 5.f;
					}

					objc_setAssociatedObject(self, &BackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

					[bannerView insertSubview:gradientView atIndex:0];
				}

				object_setClass(titleLabel, HBFPBlurryLabel.class);
				object_setClass(messageLabel, HBFPBlurryLabel.class);
			} else {
				bannerView.backgroundColor = tint;
			}

			titleLabel.textColor = [UIColor whiteColor];
			messageLabel.textColor = [UIColor whiteColor];
		}

		if (centerText && !hasDietBulletin) {
			titleLabel.textAlignment = UITextAlignmentCenter;
			messageLabel.textAlignment = UITextAlignmentCenter;
		}

		if (semiTransparent) {
			UIView *underlayView = MSHookIvar<UIView *>(self, "_underlayView");
			underlayView.backgroundColor = [UIColor clearColor];
		}

		if (fadeIn) {
			((SBBannerView *)self).alpha = 0.f;
		} else if (semiTransparent) {
			((SBBannerView *)self).alpha = 0.9f;
		}
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &BackgroundGradientIdentifier);

	if (gradientLayer) {
		gradientLayer.frame = CGRectMake(0, 0, ((SBBannerView *)self).frame.size.width, ((SBBannerView *)self).frame.size.height);
	}

	if (![objc_getAssociatedObject(self, &HasLaidOutSubviewsIdentifier) boolValue]) {
		objc_setAssociatedObject(self, &HasLaidOutSubviewsIdentifier, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_ASSIGN);

		if (fadeIn) {
			[UIView animateWithDuration:0.85f animations:^{
				((SBBannerView *)self).alpha = semiTransparent ? 0.9f : 1.f;
			}];
		}

		if (removeIcon) {
			UILabel *titleLabel = MSHookIvar<UILabel *>(self, "_titleLabel");
			UILabel *messageLabel = MSHookIvar<UILabel *>(self, "_messageLabel");
			UIImageView *iconView = MSHookIvar<UIImageView *>(self, "_iconView");

			CGRect titleFrame = titleLabel.frame;
			float oldX = titleFrame.origin.x;
			titleFrame.origin.x = iconView.frame.origin.x;
			titleFrame.size.width += oldX - titleFrame.origin.x;
			titleLabel.frame = titleFrame;

			if (IS_IOS_OR_NEWER(iOS_6_0)) {
				UIImageView *accessoryImageView = MSHookIvar<UIImageView *>(self, "_accessoryImageView");

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

	if (centerText) {
		UILabel *titleLabel = MSHookIvar<UILabel *>(self, "_titleLabel");
		UILabel *messageLabel = MSHookIvar<UILabel *>(self, "_messageLabel");
		UIImageView *accessoryImageView = IS_IOS_OR_NEWER(iOS_6_0) ? MSHookIvar<UIImageView *>(self, "_accessoryImageView") : nil;

		if (hasDietBulletin) {
			float titleWidth = titleLabel.hidden ? 0 : [titleLabel.text sizeWithFont:titleLabel.font].width;
			float messageWidth = [messageLabel.text sizeWithFont:messageLabel.font].width;

			if (titleWidth + 6.f + messageWidth < ((SBBannerView *)self).frame.size.width - 16.f) {
				UIView *containerView = [[[UIView alloc] init] autorelease];

				[titleLabel removeFromSuperview];
				[containerView addSubview:titleLabel];
				[messageLabel removeFromSuperview];
				[containerView addSubview:messageLabel];
				[((SBBannerView *)self) addSubview:containerView];

				CGRect titleFrame = titleLabel.frame;
				titleFrame.origin.x = 0;
				titleFrame.size.width = titleWidth;
				titleLabel.frame = titleFrame;

				CGRect messageFrame = messageLabel.frame;
				messageFrame.origin.x = titleWidth + 6.f;
				messageFrame.size.width = messageWidth;
				messageLabel.frame = messageFrame;

				containerView.frame = CGRectMake(0, 0, titleWidth + 6.f + messageWidth, ((SBBannerView *)self).frame.size.height);
				containerView.center = CGPointMake(((SBBannerView *)self).frame.size.width / 2, containerView.center.y);

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

	if (shouldTint && bigIcon && !removeIcon) {
		UIImageView *iconView = MSHookIvar<UIImageView *>(self, "_iconView");
		iconView.frame = CGRectMake(-1.f, -1.f, ((SBBannerView *)self).frame.size.height + 2.f, ((SBBannerView *)self).frame.size.height + 2.f);
		iconView.layer.mask.frame = iconView.frame;
	}
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &BackgroundGradientIdentifier) release];
	%orig;
}

%end

#pragma mark - DietBulletin hooks

%group HBFPDietBulletin
%hook DietBulletinMarqueeLabel // tweaking a tweak. fun.

- (void)_startMarquee {
	%orig;
	object_setClass(self, HBFPBlurryLabel.class);
}

%end
%end

#pragma mark - Preferences management

void HBFPLoadPrefs() {
	#define GET_BOOL(key, default) ([prefs objectForKey:key] ? ((NSNumber *)[prefs objectForKey:key]).boolValue : default)

	if (prefs) {
		[prefs release];
	}

	prefs = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/ws.hbang.flagpaint.plist"];

	shouldTint = GET_BOOL(@"Tint", YES);
	albumArt = GET_BOOL(@"AlbumArt", YES);
	oldStyle = GET_BOOL(@"OldStyle", NO);
	borderRadius = GET_BOOL(@"BorderRadius", YES);
	bigIcon = GET_BOOL(@"BigIcon", YES);
	semiTransparent = GET_BOOL(@"Semitransparent", YES);;
	removeIcon = GET_BOOL(@"RemoveIcon", NO);
	centerText = GET_BOOL(@"CenterText", NO);
	fadeIn = GET_BOOL(@"Fade", NO);
}

void HBFPShowTestBanner() {
	[[%c(SBBulletinBannerController) sharedInstance] showTestBanner];
}

%ctor {
	Class bannerClass = %c(SBBulletinBannerView) ?: %c(SBBannerView);
	%init(SBBannerView = bannerClass);

	HBFPLoadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, 0);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, 0);

	hasDietBulletin = [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/DietBulletin.dylib"];

	if (hasDietBulletin) {
		class_replaceMethod(%c(DietBulletinMarqueeLabel), @selector(drawTextInRect:), class_getMethodImplementation(HBFPBlurryLabel.class, @selector(drawTextInRect:)), "v{CGRect={CGPoint=ff}{CGSize=ff}}@:");
		%init(HBFPDietBulletin);

		// TODO: listen for dietbulletin's prefs reload notification and grab its banner size setting
	}
}
