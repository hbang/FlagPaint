@interface SBBulletinBannerItem : NSObject
@end

// 5.x

@interface SBBannerView : UIView {
	SBBulletinBannerItem *_item;
	UIView *_iconView;
	UILabel *_titleLabel;
	UILabel *_messageLabel;
	float _imageWidth;
	UIImageView *_bannerView;
	UIView *_underlayView;
}
-(id)initWithItem:(id)item;
-(id)item;
-(void)dealloc;
-(void)_createSubviewsWithBannerImage:(id)bannerImage;
-(void)layoutSubviews;
-(id)_bannerMaskStretchedToWidth:(float)width;
-(id)_bannerImageWithAttachmentImage:(id)attachmentImage;
@end

// 6.x

@interface SBBulletinBannerView : UIView {
	UIView *_backgroundShadowView;
	UIView *_contentContainerView;
	UIView *_contentView;
	UIView *_underlayView;
	SBBulletinBannerItem *_item;
	UIView *_iconView;
	UILabel *_titleLabel;
	UILabel *_messageLabel;
	float _imageWidth;
	UIImageView *_accessoryImageView;
	UIImageView *_backgroundImageView;
}

-(id)initWithItem:(id)item;
-(id)bannerItem;
-(id)initWithFrame:(CGRect)frame;
-(void)dealloc;
-(id)contentView;
-(void)layoutSubviews;
-(void)drawStretchableBackground:(CGContext*)background;
-(id)bannerItem;
-(id)_backgroundImageWithAttachmentImage:(id)arg1;
-(void)layoutSubviews;
-(void)_createSubviewsWithBackgroundImage:(id)arg1;
-(void)dealloc;

@end
