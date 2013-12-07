#import "HBFPBlurryLabel.h"

@implementation HBFPBlurryLabel
- (void)drawTextInRect:(CGRect)rect {
	// http://stackoverflow.com/a/1537079/709376

	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);
	CGContextSetShadowWithColor(context, CGSizeMake(1.f, 1.f), 2.f, [UIColor blackColor].CGColor);

	[super drawTextInRect:rect];

	CGContextRestoreGState(context);
}
@end
