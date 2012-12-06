/*
 Copyright 2011 Twitter, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this work except in compliance with the License.
 You may obtain a copy of the License in the LICENSE file, or at:
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "TUIImage.h"
#import "TUIKit.h"
#import "MVGIFDecoder.h"

@interface TUIStretchableImage : TUIImage
{
	@public
	NSInteger leftCapWidth;
	NSInteger topCapHeight;
  float ratio;
	@private
	__strong TUIImage *slices[9];
	struct {
		unsigned int haveSlices:1;
	} _flags;
}
@end

@interface TUIImage ()
@property (strong, readwrite) TUIImage *highDpiImage;
@property (nonatomic, readwrite, getter = isAnimated) BOOL animated;
@property (nonatomic, readwrite) NSUInteger animatedImageCount;
@property (nonatomic, readwrite) CGFloat animatedInterval;
@property (strong, readwrite) NSArray *images;
@property (strong, readwrite) NSArray *animatedDelays;
@end


@implementation TUIImage

@synthesize highDpiImage      = _highDpiImage,
            animated          = _animated,
            animatedImageCount = _animatedImageCount,
            animatedInterval  = _animatedInterval,
            images            = _images,
            animatedDelays    = _animatedDelays;

+ (TUIImage *)_imageWithABImage:(id)abimage
{
	return [self imageWithCGImage:[abimage CGImage]];
}

+ (TUIImage *)imageNamed:(NSString *)name cache:(BOOL)shouldCache
{
	if(!name)
		return nil;
	
	static NSMutableDictionary *cache = nil;
	if(!cache) {
		cache = [[NSMutableDictionary alloc] init];
	}
	
	TUIImage *image = [cache objectForKey:name];
	if(image)
		return image;
	
	NSURL *url = [[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:name];
	if(url) {
		NSData *data = [NSData dataWithContentsOfURL:url];
		if(data) {
			image = [self imageWithData:data];
      
      // check for hidpi image
      url = [[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:
             [NSString stringWithFormat:@"%@@2x.%@",
              name.stringByDeletingPathExtension,
              name.pathExtension]];
      if(url) {
        data = [NSData dataWithContentsOfURL:url];
        if(data) {
          image.highDpiImage = [self imageWithData:data];
        }
      }
      
			if(image) {
				if(shouldCache) {
					[cache setObject:image forKey:name];
				}
			}
		}
	}
	
	return image;
}

+ (TUIImage *)imageNamed:(NSString *)name
{
	return [self imageNamed:name cache:NO]; // differs from default UIKit, use explicit cache: for caching
}

+ (TUIImage *)imageWithData:(NSData *)data
{
	CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
	if(!imageSource) {
		return nil;
	}
	
	CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
	if(!image) {
		CFRelease(imageSource);
		return nil;
	}
	
	TUIImage *i = [TUIImage imageWithCGImage:image];
	CGImageRelease(image);
	CFRelease(imageSource);
	return i;
}

- (id)initWithCGImage:(CGImageRef)imageRef
{
	if((self = [super init]))
	{
		if(imageRef)
			_imageRef = CGImageRetain(imageRef);
    _highDpiImage = nil;
	}
	return self;
}

- (void)dealloc
{
	if(_imageRef)
		CGImageRelease(_imageRef);
}

+ (TUIImage *)imageWithCGImage:(CGImageRef)imageRef
{
	return [[self alloc] initWithCGImage:imageRef];
}

/**
 * @brief Create a new TUIImage from an NSImage
 * 
 * @note Don't use this method in -drawRect: if you use a NSGraphicsContext.  This method may
 * change the current context in order to convert the image and will not restore any previous
 * context.
 * 
 * @param image an NSImage
 * @return TUIImage
 */
+ (TUIImage *)imageWithNSImage:(NSImage *)image {
  
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5
  // first, attempt to find an NSBitmapImageRep representation, (the easy way)
  for(NSImageRep *rep in [image representations]){
    CGImageRef cgImage;
    if([rep isKindOfClass:[NSBitmapImageRep class]] && (cgImage = [(NSBitmapImageRep *)rep CGImage]) != nil){
      return [[TUIImage alloc] initWithCGImage:cgImage];
    }
  }
#endif
  
  // if that didn't work, we have to render the image to a context and create the CGImage
  // from that (the hard way)
  TUIImage *result = nil;
  
  CGColorSpaceRef colorspace = NULL;
  CGContextRef context = NULL;
  CGBitmapInfo info = kCGImageAlphaPremultipliedLast;
  
  size_t width  = (size_t)ceil(image.size.width);
  size_t height = (size_t)ceil(image.size.height);
  size_t bytesPerPixel = 4;
  size_t bitsPerComponent = 8;
  
  // create a colorspace for our image
  if((colorspace = CGColorSpaceCreateDeviceRGB()) != NULL){
    // create a context for our image using premultiplied RGBA
    if((context = CGBitmapContextCreate(NULL, width, height, bitsPerComponent, width * bytesPerPixel, colorspace, info)) != NULL){
      
      // setup an NSGraphicsContext for our bitmap context and render our NSImage into it
      [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:FALSE]];
      [image drawAtPoint:CGPointMake(0, 0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
      
      // create an image from the context and use that to create our TUIImage
      CGImageRef cgImage;
      if((cgImage = CGBitmapContextCreateImage(context)) != NULL){
        result = [[TUIImage alloc] initWithCGImage:cgImage];
        CFRelease(cgImage);
      }
      
      CFRelease(context);
    }
    CFRelease(colorspace);
  }
  
  // return the (hopefully sucessfully initialized) TUIImage
  return result;
}

- (CGSize)size
{
	return CGSizeMake(CGImageGetWidth(_imageRef), CGImageGetHeight(_imageRef));
}

- (CGImageRef)CGImage
{
	return _imageRef;
}

- (void)drawAtPoint:(CGPoint)point                                                        // mode = kCGBlendModeNormal, alpha = 1.0
{
	[self drawAtPoint:point blendMode:kCGBlendModeNormal alpha:1.0];
}

- (void)drawAtPoint:(CGPoint)point blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
	CGRect rect;
	rect.origin = point;
	rect.size = [self size];
	[self drawInRect:rect blendMode:blendMode alpha:alpha];
}

- (void)drawInRect:(CGRect)rect                                                           // mode = kCGBlendModeNormal, alpha = 1.0
{
	[self drawInRect:rect blendMode:kCGBlendModeNormal alpha:1.0];
}

- (void)drawInRect:(CGRect)rect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
  CGImageRef ref = _imageRef;
  if([NSScreen mainScreen].backingScaleFactor > 1 && self.highDpiImage)
  {
    ref = self.highDpiImage.CGImage;
  }
	if(ref) {
		CGContextRef ctx = TUIGraphicsGetCurrentContext();
		CGContextSaveGState(ctx);
		CGContextSetAlpha(ctx, alpha);
		CGContextSetBlendMode(ctx, blendMode);
		CGContextDrawImage(ctx, rect, ref);
		CGContextRestoreGState(ctx);
	}
}

- (NSInteger)leftCapWidth
{
	return 0;
}

- (NSInteger)topCapHeight
{
	return 0;
}

- (TUIImage *)stretchableImageWithLeftCapWidth:(NSInteger)leftCapWidth topCapHeight:(NSInteger)topCapHeight
{
	TUIStretchableImage *i = (TUIStretchableImage *)[TUIStretchableImage imageWithCGImage:_imageRef];
  if(self.highDpiImage)
  {
    TUIStretchableImage *hi = (TUIStretchableImage *)[TUIStretchableImage imageWithCGImage:self.highDpiImage.CGImage];
    hi->leftCapWidth = leftCapWidth;
    hi->topCapHeight = topCapHeight;
    hi->ratio = 2;
    i.highDpiImage = hi;
  }
	i->leftCapWidth = leftCapWidth;
	i->topCapHeight = topCapHeight;
  i->ratio = 1;
	return i;
}

- (NSData *)dataRepresentationForType:(NSString *)type compression:(CGFloat)compressionQuality
{
	if(_imageRef) {
		NSMutableData *mutableData = [NSMutableData data];
		CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)mutableData, (__bridge CFStringRef)type, 1, NULL);
		
		NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:compressionQuality], kCGImageDestinationLossyCompressionQuality, nil];
		CGImageDestinationAddImage(destination, _imageRef, (__bridge CFDictionaryRef)properties);
		
		CGImageDestinationFinalize(destination);
		CFRelease(destination);
		return mutableData;
	}
	return nil;
}

// Animated GIF

+ (TUIImage *)animatedImageWithData:(NSData *)data {
  @try {
    MVGIFDecoder *gifDecoder = [[MVGIFDecoder alloc] initWithData:data];
    TUIImage *animatedImage = nil;
    
    if(gifDecoder.frameCount <= 1)
      return [TUIImage imageWithData:data];
    
    NSMutableArray *imagesToDrawBefore = [NSMutableArray array];
    NSMutableArray *images = [NSMutableArray array];
    for(int i=0;i <gifDecoder.frameCount; i++) {
      int disposalMethod = ((NSNumber*)([[gifDecoder shouldDispose] objectAtIndex:i])).intValue;
      
      TUIImage *image = [TUIImage imageWithData:[gifDecoder dataFrameAtIndex:i]];
      
      if(image && (imagesToDrawBefore.count > 0))
      {
        size_t width = image.size.width;
        size_t height = image.size.height;
        size_t bitsPerComponent = 8;
        size_t bytesPerRow = 4 * width;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst;
        CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo);
        CGColorSpaceRelease(colorSpace);
        
        CGRect r;
        r.origin = CGPointZero;
        r.size = image.size;
        
        for(int j=0;j<imagesToDrawBefore.count;j++) {
          CGContextDrawImage(ctx, r, ((TUIImage*)[imagesToDrawBefore objectAtIndex:j]).CGImage);
        }
        
        CGRect frameRect = [(NSValue*)[gifDecoder.frameRects objectAtIndex:i] rectValue];
        frameRect.origin.y = height - frameRect.origin.y - frameRect.size.height;
        CGContextClipToRect(ctx, frameRect);
        CGContextDrawImage(ctx, r, image.CGImage);
        
        CGImageRef cgImage = CGBitmapContextCreateImage(ctx);
        
        image = [TUIImage imageWithCGImage:cgImage];
        
        CGImageRelease(cgImage);
        CGContextRelease(ctx);
      }
      
      if(image) {
        [images addObject:image];
        if(!animatedImage) {
          animatedImage = image;
        }
        if (disposalMethod == MVGIFDisposalMethodDoNotDispose ||
            disposalMethod == MVGIFDisposalMethodNone)
        {
          [imagesToDrawBefore removeAllObjects];
          [imagesToDrawBefore addObject:image];
        }
      }
    }
    
    if(images.count <= 1)
      return [TUIImage imageWithData:data];
    
    animatedImage.animated = YES;
    animatedImage.animatedImageCount = images.count;
    animatedImage.images = images;
    animatedImage.animatedDelays = gifDecoder.delays;
    return animatedImage;
  }
  @catch (NSException *exception) {
    return [TUIImage imageWithData:data];
  }
}

- (void)drawImageAtIndex:(NSUInteger)index atPoint:(CGPoint)point {
  [(TUIImage*)[self.images objectAtIndex:index] drawAtPoint:point];
}

- (void)drawImageAtIndex:(NSUInteger)index inRect:(CGRect)rect {
  [(TUIImage*)[self.images objectAtIndex:index] drawInRect:rect];
}
                                       
- (CGFloat)delayAtIndex:(NSUInteger)index {
  if(self.animatedDelays.count == 0)
    return 0.15;
  if(index < self.animatedDelays.count)
    return MAX(0.05,((NSNumber*)([self.animatedDelays objectAtIndex:index])).floatValue / 100);
  return 0.15;
}

@end


@implementation TUIStretchableImage

- (void)dealloc
{
	for(int i = 0; i < 9; ++i)
		;
}

- (NSInteger)leftCapWidth
{
	return leftCapWidth;
}

- (NSInteger)topCapHeight
{
	return topCapHeight;
}

- (float)ratio
{
  return ratio;
}

/*
 
 x0     x1      x2      x3
 +-------+-------+-------+ y3
 |       |       |       |
 |   6   |   7   |   8   |
 |       |       |       |
 +-------+-------+-------+ y2
 |       |       |       |
 |   3   |   4   |   5   |
 |       |       |       |
 +-------+-------+-------+ y1
 |       |       |       |
 |   0   |   1   |   2   |
 |       |       |       |
 +-------+-------+-------+ y0
 
 */

#define STRETCH_COORDS(X0, Y0, W, H, TOP, LEFT, BOTTOM, RIGHT) \
	CGFloat x0 = X0; \
	CGFloat x1 = X0 + LEFT; \
	CGFloat x2 = X0 + W - RIGHT; \
	CGFloat x3 = X0 + W; \
	CGFloat y0 = Y0; \
	CGFloat y1 = Y0 + BOTTOM; \
	CGFloat y2 = Y0 + H - TOP; \
	CGFloat y3 = Y0 + H; \
	CGRect r[9]; \
	r[0] = CGRectMake(x0, y0, x1-x0, y1-y0); \
	r[1] = CGRectMake(x1, y0, x2-x1, y1-y0); \
	r[2] = CGRectMake(x2, y0, x3-x2, y1-y0); \
	r[3] = CGRectMake(x0, y1, x1-x0, y2-y1); \
	r[4] = CGRectMake(x1, y1, x2-x1, y2-y1); \
	r[5] = CGRectMake(x2, y1, x3-x2, y2-y1); \
	r[6] = CGRectMake(x0, y2, x1-x0, y3-y2); \
	r[7] = CGRectMake(x1, y2, x2-x1, y3-y2); \
	r[8] = CGRectMake(x2, y2, x3-x2, y3-y2);

- (void)drawInRect:(CGRect)rect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
  BOOL highDef = ([NSScreen mainScreen].backingScaleFactor > 1 && self.highDpiImage);
  if(highDef)
  {
    [self.highDpiImage drawInRect:rect blendMode:blendMode alpha:alpha];
    return;
  }
	CGSize s = self.size;
	CGFloat t = topCapHeight;
	CGFloat l = leftCapWidth;
	
	if(t*2 > s.height-1) t -= 1;
	if(l*2 > s.width-1) l -= 1;
	
	if(_imageRef) {
		if(!_flags.haveSlices) {
			STRETCH_COORDS(0.0, 0.0, s.width, s.height, t, l, t, l)
			#define X(I) slices[I] = [self upsideDownCrop:r[I]];
			X(0) X(1) X(2)
			X(3) X(4) X(5)
			X(6) X(7) X(8)
			#undef X
			_flags.haveSlices = 1;
		}
		
		CGContextRef ctx = TUIGraphicsGetCurrentContext();
		CGContextSaveGState(ctx);
		CGContextSetAlpha(ctx, alpha);
		CGContextSetBlendMode(ctx, blendMode);
		STRETCH_COORDS(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height,
                   t / self.ratio,
                   l / self.ratio,
                   t / self.ratio,
                   l / self.ratio)
    #define X(I) CGContextDrawImage(ctx, r[I], slices[I].CGImage);
		X(0) X(1) X(2)
		X(3) X(4) X(5)
		X(6) X(7) X(8)
		#undef X
		CGContextRestoreGState(ctx);
	}
}

#undef STRETCH_COORDS

@end

NSData *TUIImagePNGRepresentation(TUIImage *image)
{
	return [image dataRepresentationForType:(NSString *)kUTTypePNG compression:1.0];
}

NSData *TUIImageJPEGRepresentation(TUIImage *image, CGFloat compressionQuality)
{
	return [image dataRepresentationForType:(NSString *)kUTTypeJPEG compression:compressionQuality];
}

#import <Cocoa/Cocoa.h>

@implementation TUIImage (AppKit)

- (id)nsImage
{
	return [[NSImage alloc] initWithCGImage:self.CGImage size:NSZeroSize];
}

@end

