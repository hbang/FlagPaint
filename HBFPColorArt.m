//
//  SLColorArt.m
//  ColorArt
//
//  Created by Aaron Brethorst on 12/11/12.
//
// Copyright (C) 2012 Panic Inc. Code by Wade Cosgrove. All rights reserved.
//
// Redistribution and use, with or without modification, are permitted provided that the following conditions are met:
//
// - Redistributions must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//
// - Neither the name of Panic Inc nor the names of its contributors may be used to endorse or promote works derived from this software without specific prior written permission from Panic Inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL PANIC INC BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#import "HBFPColorArt.h"

#define kAnalyzedBackgroundColor @"kAnalyzedBackgroundColor"
#define kAnalyzedPrimaryColor @"kAnalyzedPrimaryColor"
#define kAnalyzedSecondaryColor @"kAnalyzedSecondaryColor"
#define kAnalyzedDetailColor @"kAnalyzedDetailColor"

@interface UIColor (HBFPDarkAddition)

- (BOOL)flagPaint_isDarkColor;
- (BOOL)flagPaint_isDistinct:(UIColor*)compareColor;
- (UIColor*)flagPaint_colorWithMinimumSaturation:(CGFloat)saturation;
- (BOOL)flagPaint_isBlackOrWhite;
- (BOOL)flagPaint_isContrastingColor:(UIColor*)color;

@end


@interface HBFPCountedColor : NSObject

@property (assign) NSUInteger count;
@property (strong) UIColor *color;

- (id)initWithColor:(UIColor*)color count:(NSUInteger)count;

@end


@interface HBFPColorArt ()
@property(nonatomic, copy) UIImage *image;
@property CGSize scaledSize;
@property(nonatomic,readwrite,strong) UIColor *backgroundColor;
@property(nonatomic,readwrite,strong) UIColor *primaryColor;
@property(nonatomic,readwrite,strong) UIColor *secondaryColor;
@property(nonatomic,readwrite,strong) UIColor *detailColor;
@end

@implementation HBFPColorArt

- (id)initWithImage:(UIImage*)image
{
    self = [super init];

    if (self)
    {
        self.image = image;
        [self _processImage];
    }

    return self;
}

- (void)_processImage
{
    NSDictionary *colors = [self _analyzeImage:self.image];

    self.backgroundColor = [colors objectForKey:kAnalyzedBackgroundColor];
    self.primaryColor = [colors objectForKey:kAnalyzedPrimaryColor];
    self.secondaryColor = [colors objectForKey:kAnalyzedSecondaryColor];
    self.detailColor = [colors objectForKey:kAnalyzedDetailColor];
}

- (NSDictionary*)_analyzeImage:(UIImage*)anImage
{
    NSCountedSet *imageColors = nil;
	UIColor *backgroundColor = [self _findEdgeColor:anImage imageColors:&imageColors];
	UIColor *primaryColor = nil;
	UIColor *secondaryColor = nil;
	UIColor *detailColor = nil;
	BOOL darkBackground = [backgroundColor flagPaint_isDarkColor];

	[self _findTextColors:imageColors primaryColor:&primaryColor secondaryColor:&secondaryColor detailColor:&detailColor backgroundColor:backgroundColor];

	if ( primaryColor == nil )
	{
		if ( darkBackground )
			primaryColor = [UIColor whiteColor];
		else
			primaryColor = [UIColor blackColor];
	}

	if ( secondaryColor == nil )
	{
		if ( darkBackground )
			secondaryColor = [UIColor whiteColor];
		else
			secondaryColor = [UIColor blackColor];
	}

	if ( detailColor == nil )
	{
		if ( darkBackground )
			detailColor = [UIColor whiteColor];
		else
			detailColor = [UIColor blackColor];
	}

    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:4];
    [dict setObject:backgroundColor forKey:kAnalyzedBackgroundColor];
    [dict setObject:primaryColor forKey:kAnalyzedPrimaryColor];
    [dict setObject:secondaryColor forKey:kAnalyzedSecondaryColor];
    [dict setObject:detailColor forKey:kAnalyzedDetailColor];


    return [NSDictionary dictionaryWithDictionary:dict];
}

typedef struct RGBPixel {

    Byte    red;
    Byte    green;
    Byte    blue;

} RGBPixel;

- (UIColor*)_findEdgeColor:(UIImage*)image imageColors:(NSCountedSet**)colors
{
	CGImageRef imageRep = image.CGImage;

	NSInteger pixelsWide = CGImageGetWidth(imageRep);
	NSInteger pixelsHigh = CGImageGetHeight(imageRep);

	NSCountedSet *imageColors = [[NSCountedSet alloc] initWithCapacity:pixelsWide * pixelsHigh];
	NSCountedSet *leftEdgeColors = [[NSCountedSet alloc] initWithCapacity:pixelsHigh];
    CGDataProviderRef provider = CGImageGetDataProvider(imageRep);
    CFDataRef bitmapData = CGDataProviderCopyData(provider);
    const RGBPixel* imageData = (const RGBPixel*)CFDataGetBytePtr(bitmapData);

	for ( NSUInteger x = 0; x < pixelsWide; x++ )
	{
		for ( NSUInteger y = 0; y < pixelsHigh; y++ )
		{
            RGBPixel px = imageData[x*y+y];
            UIColor *color = [UIColor colorWithRed:((CGFloat)px.red)/255.0 green:((CGFloat)px.green)/255.0 blue:((CGFloat)px.blue)/255.0 alpha:1.0];

			if ( x == 0 )
			{
				[leftEdgeColors addObject:color];
			}

			[imageColors addObject:color];
		}
	}

	*colors = imageColors;


	NSEnumerator *enumerator = [leftEdgeColors objectEnumerator];
	UIColor *curColor = nil;
	NSMutableArray *sortedColors = [NSMutableArray arrayWithCapacity:[leftEdgeColors count]];

	while ( (curColor = [enumerator nextObject]) != nil )
	{
		NSUInteger colorCount = [leftEdgeColors countForObject:curColor];

		if ( colorCount <= 2 ) // prevent using random colors, threshold should be based on input image size
			continue;

		HBFPCountedColor *container = [[HBFPCountedColor alloc] initWithColor:curColor count:colorCount];

		[sortedColors addObject:container];
	}

	[sortedColors sortUsingSelector:@selector(compare:)];


	HBFPCountedColor *proposedEdgeColor = nil;

	if ( [sortedColors count] > 0 )
	{
		proposedEdgeColor = [sortedColors objectAtIndex:0];

		if ( [proposedEdgeColor.color flagPaint_isBlackOrWhite] ) // want to choose color over black/white so we keep looking
		{
			for ( NSInteger i = 1; i < [sortedColors count]; i++ )
			{
				HBFPCountedColor *nextProposedColor = [sortedColors objectAtIndex:i];

				if (((double)nextProposedColor.count / (double)proposedEdgeColor.count) > .4 ) // make sure the second choice color is 40% as common as the first choice
				{
					if ( ![nextProposedColor.color flagPaint_isBlackOrWhite] )
					{
						proposedEdgeColor = nextProposedColor;
						break;
					}
				}
				else
				{
					// reached color threshold less than 40% of the original proposed edge color so bail
					break;
				}
			}
		}
	}

	return proposedEdgeColor.color;
}


- (void)_findTextColors:(NSCountedSet*)colors primaryColor:(UIColor**)primaryColor secondaryColor:(UIColor**)secondaryColor detailColor:(UIColor**)detailColor backgroundColor:(UIColor*)backgroundColor
{
	NSEnumerator *enumerator = [colors objectEnumerator];
	UIColor *curColor = nil;
	NSMutableArray *sortedColors = [NSMutableArray arrayWithCapacity:[colors count]];
	BOOL findDarkTextColor = ![backgroundColor flagPaint_isDarkColor];

	while ( (curColor = [enumerator nextObject]) != nil )
	{
		curColor = [curColor flagPaint_colorWithMinimumSaturation:.15];

		if ( [curColor flagPaint_isDarkColor] == findDarkTextColor )
		{
			NSUInteger colorCount = [colors countForObject:curColor];

			HBFPCountedColor *container = [[HBFPCountedColor alloc] initWithColor:curColor count:colorCount];

			[sortedColors addObject:container];
		}
	}

	[sortedColors sortUsingSelector:@selector(compare:)];

	for ( HBFPCountedColor *curContainer in sortedColors )
	{
		curColor = curContainer.color;

		if ( *primaryColor == nil )
		{
			if ( [curColor flagPaint_isContrastingColor:backgroundColor] )
				*primaryColor = curColor;
		}
		else if ( *secondaryColor == nil )
		{
			if ( ![*primaryColor flagPaint_isDistinct:curColor] || ![curColor flagPaint_isContrastingColor:backgroundColor] )
				continue;

			*secondaryColor = curColor;
		}
		else if ( *detailColor == nil )
		{
			if ( ![*secondaryColor flagPaint_isDistinct:curColor] || ![*primaryColor flagPaint_isDistinct:curColor] || ![curColor flagPaint_isContrastingColor:backgroundColor] )
				continue;

			*detailColor = curColor;
			break;
		}
	}
}

@end


@implementation UIColor (HBFPDarkAddition)

- (BOOL)flagPaint_isDarkColor
{
	UIColor *convertedColor = self;

	CGFloat r, g, b, a;

	[convertedColor getRed:&r green:&g blue:&b alpha:&a];

	CGFloat lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;

	if ( lum < .5 )
	{
		return YES;
	}

	return NO;
}


- (BOOL)flagPaint_isDistinct:(UIColor*)compareColor
{
	UIColor *convertedColor = self;
	UIColor *convertedCompareColor = compareColor;
	CGFloat r, g, b, a;
	CGFloat r1, g1, b1, a1;

	[convertedColor getRed:&r green:&g blue:&b alpha:&a];
	[convertedCompareColor getRed:&r1 green:&g1 blue:&b1 alpha:&a1];

	CGFloat threshold = .25; //.15

	if ( fabs(r - r1) > threshold ||
		fabs(g - g1) > threshold ||
		fabs(b - b1) > threshold ||
		fabs(a - a1) > threshold )
    {
        // check for grays, prevent multiple gray colors

        if ( fabs(r - g) < .03 && fabs(r - b) < .03 )
        {
            if ( fabs(r1 - g1) < .03 && fabs(r1 - b1) < .03 )
                return NO;
        }

        return YES;
    }

	return NO;
}


- (UIColor*)flagPaint_colorWithMinimumSaturation:(CGFloat)minSaturation
{
	UIColor *tempColor = self;

	if ( tempColor != nil )
	{
		CGFloat hue = 0.0;
		CGFloat saturation = 0.0;
		CGFloat brightness = 0.0;
		CGFloat alpha = 0.0;

		[tempColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

		if ( saturation < minSaturation )
		{
			return [UIColor colorWithHue:hue saturation:minSaturation brightness:brightness alpha:alpha];
		}
	}

	return self;
}


- (BOOL)flagPaint_isBlackOrWhite
{
	UIColor *tempColor = self;

	if ( tempColor != nil )
	{
		CGFloat r, g, b, a;

		[tempColor getRed:&r green:&g blue:&b alpha:&a];

		if ( r > .91 && g > .91 && b > .91 )
			return YES; // white

		if ( r < .09 && g < .09 && b < .09 )
			return YES; // black
	}

	return NO;
}


- (BOOL)flagPaint_isContrastingColor:(UIColor*)color
{
	UIColor *backgroundColor = self;
	UIColor *foregroundColor = color;

	if ( backgroundColor != nil && foregroundColor != nil )
	{
		CGFloat br, bg, bb, ba;
		CGFloat fr, fg, fb, fa;

		[backgroundColor getRed:&br green:&bg blue:&bb alpha:&ba];
		[foregroundColor getRed:&fr green:&fg blue:&fb alpha:&fa];

		CGFloat bLum = 0.2126 * br + 0.7152 * bg + 0.0722 * bb;
		CGFloat fLum = 0.2126 * fr + 0.7152 * fg + 0.0722 * fb;

		CGFloat contrast = 0.;

		if ( bLum > fLum )
			contrast = (bLum + 0.05) / (fLum + 0.05);
		else
			contrast = (fLum + 0.05) / (bLum + 0.05);

		return contrast > 1.6;
	}

	return YES;
}

@end


@implementation HBFPCountedColor

- (id)initWithColor:(UIColor*)color count:(NSUInteger)count
{
	self = [super init];

	if ( self )
	{
		self.color = color;
		self.count = count;
	}

	return self;
}

- (NSComparisonResult)compare:(HBFPCountedColor*)object
{
	if ( [object isKindOfClass:[HBFPCountedColor class]] )
	{
		if ( self.count < object.count )
		{
			return NSOrderedDescending;
		}
		else if ( self.count == object.count )
		{
			return NSOrderedSame;
		}
	}

	return NSOrderedAscending;
}


@end
