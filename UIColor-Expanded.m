#import "UIColor-Expanded.h"

/*

 Thanks to Poltras, Millenomi, Eridius, Nownot, WhatAHam, jberry,
 and everyone else who helped out but whose name is inadvertantly omitted

*/

/*
 Current outstanding request list:

 - PolarBearFarm - color descriptions ([UIColor warmGrayWithHintOfBlueTouchOfRedAndSplashOfYellowColor])
 - Crayola color set
 - Eridius - UIColor needs a method that takes 2 colors and gives a third complementary one
 - Consider UIMutableColor that can be adjusted (brighter, cooler, warmer, thicker-alpha, etc)
 */

/*
 FOR REFERENCE: Color Space Models: enum CGColorSpaceModel {
	kCGColorSpaceModelUnknown = -1,
	kCGColorSpaceModelMonochrome,
	kCGColorSpaceModelRGB,
	kCGColorSpaceModelCMYK,
	kCGColorSpaceModelLab,
	kCGColorSpaceModelDeviceN,
	kCGColorSpaceModelIndexed,
	kCGColorSpaceModelPattern
};
*/

#pragma mark -

@implementation UIColor (UIColor_Expanded)

#pragma mark String utilities

- (NSString *)flagPaint_stringFromColor {
	NSAssert(CGColorSpaceGetModel(CGColorGetColorSpace(self.CGColor)) == kCGColorSpaceModelRGB, @"Must be an RGB color to use -stringFromColor");
	if (self.flagPaint_colorSpaceModel == kCGColorSpaceModelRGB) {
		const CGFloat *components = CGColorGetComponents(self.CGColor);
		return [NSString stringWithFormat:@"{%0.3f, %0.3f, %0.3f, %0.3f}", c[0], c[1], c[2], CGColorGetAlpha(self.CGColor);];
	}
	return nil;
}

+ (UIColor *)flagPaint_colorWithString:(NSString *)stringToConvert {
	NSScanner *scanner = [NSScanner scannerWithString:stringToConvert];
	if (![scanner scanString:@"{" intoString:NULL]) return nil;
	const NSUInteger kMaxComponents = 4;
	CGFloat c[kMaxComponents];
	NSUInteger i = 0;
	if (![scanner scanFloat:&c[i++]]) return nil;
	while (1) {
		if ([scanner scanString:@"}" intoString:NULL]) break;
		if (i >= kMaxComponents) return nil;
		if ([scanner scanString:@"," intoString:NULL]) {
			if (![scanner scanFloat:&c[i++]]) return nil;
		} else {
			// either we're at the end or there's an unexpected character here
			// both cases are error conditions
			return nil;
		}
	}
	if (![scanner isAtEnd]) return nil;
	UIColor *color;
	switch (i) {
		case 2: // monochrome
			color = [UIColor colorWithWhite:c[0] alpha:c[1]];
			break;
		case 4: // RGB
			color = [UIColor colorWithRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
			break;
		default:
			color = nil;
	}
	return color;
}

@end
