#import <substrate.h> // >_>
#import <version.h>
#import "HBFPBlurryLabel.h"
#import "Emblem.h"
#import <BulletinBoard/BBBulletin.h>
#import <QuartzCore/QuartzCore.h>
#import <SpringBoard/SBBulletinBannerController.h>
#import <SpringBoard/SBBulletinBannerItem.h>
#import <SpringBoard/SBBulletinBannerView.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBMediaController.h>
#import <Accelerate/Accelerate.h>

struct pixel {
	unsigned char r, g, b, a;
};

static const char *BackgroundGradientIdentifier = "flagPaint_backgroundGradient";
static const char *HasLaidOutSubviewsIdentifier = "flagPaint_hasLaidOutSubviews";

NSDictionary *prefs;
NSMutableDictionary *colorCache = [[NSMutableDictionary alloc] init];
NSMutableDictionary *iconCache = [[NSMutableDictionary alloc] init];
BOOL hasDietBulletin = NO;
BOOL hasEmblem = NO;

BOOL shouldTint = YES;
BOOL albumArt = YES;
BOOL oldStyle = NO;
BOOL borderRadius = YES;
BOOL bigIcon = YES;
BOOL semiTransparent = YES;
BOOL removeIcon = NO;
BOOL centerText = NO;
BOOL fadeIn = NO;

static NSUInteger BytesPerPixel = 4;
static NSUInteger BitsPerComponent = 8;

#pragma mark - Get dominant color

UIColor *HBFPGetDominantColor(UIImage *image) {
	NSUInteger red = 0, green = 0, blue = 0;
	NSUInteger numberOfPixels = image.size.width * image.size.height;

	pixel *pixels = (pixel *)calloc(1, image.size.width * image.size.height * sizeof(pixel));

	if (!pixels) {
		return [UIColor whiteColor];
	}

	CGContextRef context = CGBitmapContextCreate(pixels, image.size.width, image.size.height, BitsPerComponent, image.size.width * BytesPerPixel, CGImageGetColorSpace(image.CGImage), kCGImageAlphaPremultipliedLast);

	if (!context) {
		free(pixels);
		return [UIColor whiteColor];
	}

	CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);

	for (NSUInteger i = 0; i < numberOfPixels; i++) {
		red += pixels[i].r;
		green += pixels[i].g;
		blue += pixels[i].b;
	}

	red /= numberOfPixels;
	green /= numberOfPixels;
	blue /= numberOfPixels;

	CGContextRelease(context);
	free(pixels);

	return [UIColor colorWithRed:red / 255.f green:green / 255.f blue:blue / 255.f alpha:1];
}

#pragma mark - Resize image

// http://stackoverflow.com/a/10099016/709376

UIImage *HBFPResizeImage(UIImage *oldImage, CGSize newSize) {
	if (!oldImage) {
		return nil;
	}

	UIImage *newImage = nil;

	CGImageRef cgImage = oldImage.CGImage;
	NSUInteger oldWidth = CGImageGetWidth(cgImage);
	NSUInteger oldHeight = CGImageGetHeight(cgImage);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

	pixel *oldData = (pixel *)calloc(oldHeight * oldWidth * BytesPerPixel, sizeof(pixel));
	NSUInteger oldBytesPerRow = BytesPerPixel * oldWidth;

	CGContextRef context = CGBitmapContextCreate(oldData, oldWidth, oldHeight, BitsPerComponent, oldBytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
	CGContextDrawImage(context, CGRectMake(0, 0, oldWidth, oldHeight), cgImage);
	CGContextRelease(context);

	NSUInteger newWidth = (NSUInteger)newSize.width;
	NSUInteger newHeight = (NSUInteger)newSize.height;
	NSUInteger newBytesPerRow = BytesPerPixel * newWidth;
	pixel *newData = (pixel *)calloc(newHeight * newWidth * BytesPerPixel, sizeof(pixel));

	vImage_Buffer oldBuffer = {
		.data = oldData,
		.height = oldHeight,
		.width = oldWidth,
		.rowBytes = oldBytesPerRow
	};

	vImage_Buffer newBuffer = {
		.data = newData,
		.height = newHeight,
		.width = newWidth,
		.rowBytes = newBytesPerRow
	};

	vImage_Error error = vImageScale_ARGB8888(&oldBuffer, &newBuffer, NULL, kvImageHighQualityResampling);

	free(oldData);

	CGContextRef newContext = CGBitmapContextCreate(newData, newWidth, newHeight, BitsPerComponent, newBytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
	CGImageRef cgImageNew = CGBitmapContextCreateImage(newContext);

	newImage = [UIImage imageWithCGImage:cgImageNew];

	CGImageRelease(cgImageNew);
	CGColorSpaceRelease(colorSpace);
	CGContextRelease(newContext);

	free(newData);

	if (error != kvImageNoError) {
		NSLog(@"warning: failed to scale image: error %ld", error);
		return oldImage;
	}

	return newImage;
}

#pragma mark - Shared banner functions

void HBFPAddGradientToLayer(CAGradientLayer *layer, UIImage *image, BOOL isMusic, NSString *key, NSString *sectionID) {
	NSArray *colors = prefs[[NSString stringWithFormat:@"Tint-%@", sectionID]];

	if (!colorCache[key]) {
		if (colors && colors.count == 3) {
			colorCache[key] = [UIColor colorWithRed:((NSNumber *)colors[0]).floatValue green:((NSNumber *)colors[1]).floatValue blue:((NSNumber *)colors[2]).floatValue alpha:1];
		} else {
			colorCache[key] = HBFPGetDominantColor(image) ?: [UIColor whiteColor];
		}
	}

	UIColor *tint = colorCache[key] ?: [UIColor whiteColor];

	CGFloat hue, saturation, brightness;

	if ([tint getHue:&hue saturation:&saturation brightness:&brightness alpha:nil]) {
		layer.colors = @[ oldStyle ? (id)tint.CGColor : (id)[UIColor colorWithHue:hue saturation:saturation brightness:MIN(1, brightness * 2.f) alpha:1].CGColor, (id)tint.CGColor ];
		layer.borderColor = [UIColor colorWithHue:hue saturation:saturation brightness:MIN(1, brightness * 1.08f) alpha:0.9f].CGColor;
		layer.borderWidth = 1.f;
	}
}

BOOL HBFPIsMusic(NSString *sectionID) {
	SBMediaController *mediaController = [%c(SBMediaController) sharedInstance];

	return !oldStyle && albumArt && mediaController.nowPlayingApplication && mediaController.nowPlayingApplication.class == %c(SBApplication) && ([sectionID isEqualToString:mediaController.nowPlayingApplication.bundleIdentifier] || [sectionID isEqualToString:@"com.apple.Music"]) && mediaController._nowPlayingInfo[@"artworkData"];
}

NSString *HBFPGetKey(NSString *sectionID, BOOL isMusic) {
	SBMediaController *mediaController = [%c(SBMediaController) sharedInstance];

	return isMusic ? [NSString stringWithFormat:@"FPMUSIC_%@_%@_%@_%@", mediaController.nowPlayingApplication.bundleIdentifier, mediaController.nowPlayingTitle, mediaController.nowPlayingArtist, mediaController.nowPlayingAlbum] : sectionID;
}

#pragma mark - Banner hooks

%hook SBBannerView

- (id)initWithItem:(SBBulletinBannerItem *)item {
	self = %orig;

	if (self) {
		HBFPBlurryLabel *titleLabel = MSHookIvar<HBFPBlurryLabel *>(self, "_titleLabel");
		HBFPBlurryLabel *messageLabel = MSHookIvar<HBFPBlurryLabel *>(self, "_messageLabel");
		UIImageView *iconView = MSHookIvar<UIImageView *>(self, "_iconView");

		SBMediaController *mediaController = [%c(SBMediaController) sharedInstance];

		if (shouldTint) {
			BOOL isMusic = HBFPIsMusic(item.seedBulletin.sectionID);
			NSString *key = HBFPGetKey(item.seedBulletin.sectionID, isMusic);

			UIImageView *bannerView = MSHookIvar<UIImageView *>(self, IS_IOS_OR_NEWER(iOS_6_0) ? "_backgroundImageView" : "_bannerView");

			if (bigIcon) {
				CAGradientLayer *imageGradientLayer = [CAGradientLayer layer];
				imageGradientLayer.colors = @[ (id)[UIColor whiteColor].CGColor, (id)[UIColor clearColor].CGColor ];
				imageGradientLayer.startPoint = CGPointMake(0.5f, 0.5f);
				imageGradientLayer.endPoint = CGPointMake(1.f, 0.5f);
				iconView.layer.mask = imageGradientLayer;
			}

			if (isMusic) {
				iconView.layer.minificationFilter = kCAFilterTrilinear;
			}

			if (!oldStyle) {
				if (!iconCache[key]) {
					if (isMusic) {
						iconCache[key] = HBFPResizeImage([UIImage imageWithData:mediaController._nowPlayingInfo[@"artworkData"]], CGSizeMake(120.f, 120.f));
					} else {
						SBApplication *app = [[[%c(SBApplicationController) sharedInstance] applicationWithDisplayIdentifier:item.seedBulletin.sectionID] autorelease];

						if (app) {
							SBApplicationIcon *appIcon = [[[%c(SBApplicationIcon) alloc] initWithApplication:app] autorelease];
							UIImage *icon = [appIcon getIconImage:SBApplicationIconFormatDefault];

							if (icon) {
								iconCache[key] = icon;
							}
						}
					}
				}

				iconView.image = iconCache[key];
			}

			bannerView.image = nil;

			UIView *gradientView = [[UIView alloc] initWithFrame:(CGRect){ CGPointZero, ((SBBannerView *)self).frame.size }];
			gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			[bannerView insertSubview:gradientView atIndex:0];

			CAGradientLayer *gradientLayer = [CAGradientLayer layer];
			gradientLayer.locations = @[ @0, @1 ];
			[gradientView.layer addSublayer:gradientLayer];

			if (borderRadius) {
				gradientView.layer.cornerRadius = 5.f;
				gradientLayer.cornerRadius = 5.f;
			}

			objc_setAssociatedObject(self, &BackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			HBFPAddGradientToLayer(gradientLayer, iconView.image, isMusic, key, item.seedBulletin.sectionID);

			object_setClass(titleLabel, HBFPBlurryLabel.class);
			object_setClass(messageLabel, HBFPBlurryLabel.class);

			if (borderRadius) {
				bannerView.layer.cornerRadius = 5.f;
				((SBBannerView *)self).layer.cornerRadius = 5.f;

				if (bigIcon) {
					iconView.layer.cornerRadius = 5.f;
					iconView.layer.masksToBounds = YES;
					iconView.layer.shouldRasterize = YES;
				}
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
			((SBBannerView *)self).alpha = 0;
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

	if (!((NSNumber *)objc_getAssociatedObject(self, &HasLaidOutSubviewsIdentifier)).boolValue) {
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

#pragma mark - Emblem hooks

%group HBFPEmblem
%hook EBNotificationAlertView // fun indeed...

- (id)initWithAlertItem:(EBNotificationItem *)item {
	self = %orig;

	if (self) {
		if (shouldTint) {
			BOOL isMusic = HBFPIsMusic(item.sectionID);
			NSString *key = HBFPGetKey(item.sectionID, isMusic);

			UIView *backgroundView = MSHookIvar<UIView *>(self, "backgroundView");
			UIImageView *iconView = MSHookIvar<UIImageView *>(self, "iconView");

			HBFPAddGradientToLayer((CAGradientLayer *)backgroundView.layer, iconView.image, isMusic, key, item.sectionID);

			if (!oldStyle) {
				UIView *bulletinView = MSHookIvar<UIView *>(self, "bulletinView");
				HBFPBlurryLabel *titleLabel = MSHookIvar<HBFPBlurryLabel *>(bulletinView, "_titleLabel");
				HBFPBlurryLabel *detailLabel = MSHookIvar<HBFPBlurryLabel *>(bulletinView, "_detailLabel");

				titleLabel.textColor = [UIColor whiteColor];
				detailLabel.textColor = [UIColor whiteColor];

				object_setClass(titleLabel, HBFPBlurryLabel.class);
				object_setClass(detailLabel, HBFPBlurryLabel.class);

				if (isMusic) {
					if (!iconCache[key]) {
						iconCache[key] = HBFPResizeImage([UIImage imageWithData:((SBMediaController *)[%c(SBMediaController) sharedInstance])._nowPlayingInfo[@"artworkData"]], CGSizeMake(120.f, 120.f));
					}

					iconView.image = iconCache[key];
					iconView.layer.cornerRadius = 6.f;
					iconView.layer.masksToBounds = YES;
					iconView.layer.minificationFilter = kCAFilterTrilinear;
					iconView.layer.shouldRasterize = YES;
				}
			}

			UIView *buttonsView = MSHookIvar<UIView *>(self, "buttonsView");
			UIButton *topButton = MSHookIvar<UIButton *>(buttonsView, "topButton");
			UIButton *bottomButton = MSHookIvar<UIButton *>(buttonsView, "bottomButton");

			for (UIButton *button in @[ topButton, bottomButton ]) {
				UIImageView *backgroundView = MSHookIvar<UIImageView *>(button, "_backgroundView");
				backgroundView.alpha = 0.4f;
			}
		}

		if (semiTransparent) {
			self.alpha = 0.9f;
		}
	}

	return self;
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &BackgroundGradientIdentifier) release];
	%orig;
}

%end
%end

#pragma mark - Preferences management

void HBFPLoadPrefs() {
	#define GET_BOOL(key, default) (prefs[key] ? ((NSNumber *)prefs[key]).boolValue : default)

	[prefs release];
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

	hasEmblem = [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/Emblem.dylib"];

	if (hasEmblem) {
		%init(HBFPEmblem);
	}
}
