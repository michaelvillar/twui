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

#import "TUITextRenderer.h"
#import "TUITextRenderer+Event.h"
#import "TUIFont.h"
#import "TUIColor.h"
#import "TUIKit.h"
#import "CoreText+Additions.h"

NSBezierPath* AB_NSBezierPathRoundedFromRects(CGRect providedRects[], CFIndex rectCount);
NSBezierPath* AB_NSBezierPathRoundedFromRects(CGRect providedRects[], CFIndex rectCount)
{
  CGRect rects[rectCount];
  CFIndex newRectCount = 0;
  CGRect rect;
  // remove empty rects
  for(CFIndex i = 0; i < rectCount; ++i) {
    rect = CGRectIntegral(providedRects[i]);
    if(rect.size.width > 0 && rect.size.height > 0)
    {
      rects[newRectCount++] = rect;
    }
  }
  rectCount = newRectCount;
  
  NSBezierPath *path = [NSBezierPath bezierPath];
  CGRect oldRect = NSMakeRect(0, 0, 0, 0);
  float r = 5;
  float r2;
  
  // right edge
  for(CFIndex i = 0; i < rectCount; ++i) {
    rect = rects[i];
    r2 = r;
    if(i == 0) {
      [path moveToPoint:CGPointMake(NSMaxX(rect) - r, NSMaxY(rect))];
    }
    else {
      CGPoint toPoint;
      CGPoint lineToPoint;
      float d = fabs(NSMaxX(rect) - NSMaxX(oldRect)) / 2;
      r2 = (d > r ? r : d);
      if(NSMaxX(rect) > NSMaxX(oldRect))
      {
        toPoint = CGPointMake(NSMaxX(oldRect) + r, NSMinY(oldRect));
        lineToPoint = CGPointMake(NSMaxX(rect) - r, NSMaxY(rect));
      }
      else
      {
        toPoint = CGPointMake(NSMaxX(oldRect) - r, NSMinY(oldRect));
        lineToPoint = CGPointMake(NSMaxX(rect) + r, NSMaxY(rect));
      }
      [path appendBezierPathWithArcFromPoint:CGPointMake(NSMaxX(oldRect), NSMinY(oldRect)) 
                                     toPoint:toPoint 
                                      radius:r2];   
      
      [path lineToPoint:lineToPoint];
    }
    
    if(NSMaxX(rect) <= NSMinX(oldRect) + r)
    {
      [path lineToPoint:CGPointMake(NSMaxX(rect) - r, NSMaxY(rect))];
      r2 = r;
    }
    [path appendBezierPathWithArcFromPoint:CGPointMake(NSMaxX(rect), NSMaxY(rect)) 
                                   toPoint:CGPointMake(NSMaxX(rect), NSMaxY(rect) - r) 
                                    radius:r2];
    [path lineToPoint:CGPointMake(NSMaxX(rect), NSMinY(rect) + r)];
    
    if(i == rectCount - 1)
    {
      [path appendBezierPathWithArcFromPoint:CGPointMake(NSMaxX(rect), NSMinY(rect)) 
                                     toPoint:CGPointMake(NSMaxX(rect) - r, NSMinY(rect)) 
                                      radius:r];
    }
    
    oldRect = rect;
  }
  
  // left edge
  for(CFIndex i = rectCount - 1; i >= 0; --i) {
    rect = rects[i];
    
    r2 = r;
    if(i != rectCount - 1)
    {
      CGPoint toPoint;
      CGPoint lineToPoint;
      float d = fabs(NSMinX(rect) - NSMinX(oldRect)) / 2;
      r2 = (d > r ? r : d);
      if(NSMinX(rect) > NSMinX(oldRect))
      {
        toPoint = CGPointMake(NSMinX(oldRect) + r, NSMaxY(oldRect));
        lineToPoint = CGPointMake(NSMinX(rect) - r, NSMinY(rect));
      }
      else
      {
        toPoint = CGPointMake(NSMinX(oldRect) - r, NSMaxY(oldRect));
        lineToPoint = CGPointMake(NSMinX(rect) + r, NSMinY(rect));
      }
      [path appendBezierPathWithArcFromPoint:CGPointMake(NSMinX(oldRect), NSMaxY(oldRect)) 
                                     toPoint:toPoint 
                                      radius:r2];
      [path lineToPoint:lineToPoint];
    }
    
    if(NSMinX(rect) >= NSMaxX(oldRect) - r)
    {
      [path lineToPoint:CGPointMake(NSMinX(rect) + r, NSMinY(rect))];
      r2 = r;
    }
    [path appendBezierPathWithArcFromPoint:CGPointMake(NSMinX(rect), NSMinY(rect)) 
                                   toPoint:CGPointMake(NSMinX(rect), NSMinY(rect) + r) 
                                    radius:r2];
    [path lineToPoint:CGPointMake(NSMinX(rect), NSMaxY(rect) - r)];
    
    if(i == 0)
    {
      [path appendBezierPathWithArcFromPoint:CGPointMake(NSMinX(rect), NSMaxY(rect)) 
                                     toPoint:CGPointMake(NSMinX(rect) + r, NSMaxY(rect)) 
                                      radius:r];
    }
    
    oldRect = rect;
  }
  
  [path closePath];
    
  return path;
}

NSString *TUITextRendererDidBecomeFirstResponder = @"TUITextRendererDidBecomeFirstResponder";
NSString *TUITextRendererDidResignFirstResponder = @"TUITextRendererDidResignFirstResponder";

@implementation TUITextRenderer

@synthesize attributedString;
@synthesize frame;
@synthesize view;
@synthesize hitRange;
@synthesize shadowColor;
@synthesize shadowOffset;
@synthesize shadowBlur;
@synthesize selectionColor;
@synthesize shouldRefuseFirstResponder;

- (NSAttributedString*)drawingAttributedString
{
  return attributedString;
}

- (void)_resetFramesetter
{
	if(_ct_framesetter) {
		CFRelease(_ct_framesetter);
		_ct_framesetter = NULL;
	}
	if(_ct_frame) {
		CFRelease(_ct_frame);
		_ct_frame = NULL;
	}
	if(_ct_path) {
		CGPathRelease(_ct_path);
		_ct_path = NULL;
	}
}

- (void)dealloc
{
	[self _resetFramesetter];
}

- (void)_buildFramesetter
{
	if(!_ct_framesetter) {
		_ct_framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)[self drawingAttributedString]);
		_ct_path = CGPathCreateMutable();
		CGPathAddRect((CGMutablePathRef)_ct_path, NULL, frame);
		_ct_frame = CTFramesetterCreateFrame(_ct_framesetter, CFRangeMake(0, 0), _ct_path, NULL);
	}
}

- (CTFramesetterRef)ctFramesetter
{
	[self _buildFramesetter];
	return _ct_framesetter;
}

- (CTFrameRef)ctFrame
{
	[self _buildFramesetter];
	return _ct_frame;
}

- (CGPathRef)ctPath
{
	[self _buildFramesetter];
	return _ct_path;
}

- (CFIndex)_clampToValidRange:(CFIndex)index
{
	if(index < 0) return 0;
	CFIndex max = [attributedString length] - 1;
	if(index > max) return max;
	return index;
}

- (NSRange)_wordRangeAtIndex:(CFIndex)index
{
	return [attributedString doubleClickAtIndex:[self _clampToValidRange:index]];
}

- (NSRange)_lineRangeAtIndex:(CFIndex)index
{
	return [[attributedString string] lineRangeForRange:NSMakeRange(index, 0)];
}

- (NSRange)_paragraphRangeAtIndex:(CFIndex)index
{
	return [[attributedString string] paragraphRangeForRange:NSMakeRange(index, 0)];
}

- (CFRange)_selectedRange
{
	CFIndex first, last;
	if(_selectionStart <= _selectionEnd) {
		first = _selectionStart;
		last = _selectionEnd;
	} else {
		first = _selectionEnd;
		last = _selectionStart;
	}

	if(_selectionAffinity != TUITextSelectionAffinityCharacter) {
		NSRange fr = {0,0};
		NSRange lr = {0,0};
		
		switch(_selectionAffinity) {
			case TUITextSelectionAffinityCharacter:
				// do nothing
				break;
			case TUITextSelectionAffinityWord:
				fr = [self _wordRangeAtIndex:first];
				lr = [self _wordRangeAtIndex:last];
				break;
			case TUITextSelectionAffinityLine:
				fr = [self _lineRangeAtIndex:first];
				lr = [self _lineRangeAtIndex:last];
				break;
			case TUITextSelectionAffinityParagraph:
				fr = [self _paragraphRangeAtIndex:first];
				lr = [self _paragraphRangeAtIndex:last];
				break;
		}
		
		first = fr.location;
		last = lr.location + lr.length;
	}
  
  if(first < 0)
    first = 0;
  long len = last - first;
  if(len < 0)
    len = 0;

	return CFRangeMake(first, len);
}

- (NSRange)selectedRange
{
	return ABNSRangeFromCFRange([self _selectedRange]);
}

- (void)setSelection:(NSRange)selection
{
	_selectionAffinity = TUITextSelectionAffinityCharacter;
	_selectionStart = selection.location;
	_selectionEnd = selection.location + selection.length;
	[view setNeedsDisplay];
}

- (NSString *)selectedString
{
	return [[attributedString string] substringWithRange:[self selectedRange]];
}

- (void)draw
{
	[self drawInContext:TUIGraphicsGetCurrentContext()];
}

- (void)drawInContext:(CGContextRef)context
{
	if(self.drawingAttributedString) {
		CGContextSaveGState(context);
		
		CTFrameRef f = [self ctFrame];
		
		if(_flags.preDrawBlocksEnabled && !_flags.drawMaskDragSelection) {
			[self.drawingAttributedString enumerateAttribute:TUIAttributedStringPreDrawBlockName inRange:NSMakeRange(0, [self.drawingAttributedString length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
				if(value == NULL) return;
				
				CGContextSaveGState(context);
				
				CFIndex rectCount = 100;
				CGRect rects[rectCount];
				CFRange r = {range.location, range.length};
				AB_CTFrameGetRectsForRangeWithAggregationType([self.drawingAttributedString string],f, r, (AB_CTLineRectAggregationType)[[self.drawingAttributedString attribute:TUIAttributedStringBackgroundFillStyleName atIndex:range.location effectiveRange:NULL] integerValue], rects, &rectCount);
				TUIAttributedStringPreDrawBlock block = value;
				block(self.drawingAttributedString, range, rects, rectCount);
				
				CGContextRestoreGState(context);
			}];
		}
		
		if(_flags.backgroundDrawingEnabled && !_flags.drawMaskDragSelection) {
			CGContextSaveGState(context);
			
			[self.drawingAttributedString enumerateAttribute:TUIAttributedStringBackgroundColorAttributeName inRange:NSMakeRange(0, [self.drawingAttributedString length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
				if(value == NULL) return;
				
				CGColorRef color = (__bridge CGColorRef) value;
				CGContextSetFillColorWithColor(context, color);
				
				CFIndex rectCount = 100;
				CGRect rects[rectCount];
				CFRange r = {range.location, range.length};
				AB_CTFrameGetRectsForRangeWithAggregationType([self.drawingAttributedString string],f, r, (AB_CTLineRectAggregationType)[[self.drawingAttributedString attribute:TUIAttributedStringBackgroundFillStyleName atIndex:range.location effectiveRange:NULL] integerValue], rects, &rectCount);
				for(CFIndex i = 0; i < rectCount; ++i) {
					CGRect r = rects[i];
					r = CGRectInset(r, -2, -1);
					r = CGRectIntegral(r);
					if(r.size.width > 1)
						CGContextFillRect(context, r);
				}
			}];
			
			CGContextRestoreGState(context);
		}
		
		if(hitRange && !_flags.drawMaskDragSelection) {
			// draw highlight
			CGContextSaveGState(context);
			
			NSRange _r = [hitRange rangeValue];
			CFRange r = {_r.location, _r.length};
			CFIndex nRects = 10;
			CGRect rects[nRects];
			AB_CTFrameGetRectsForRange([self.drawingAttributedString string],f, r, rects, &nRects);
			for(int i = 0; i < nRects; ++i) {
				CGRect rect = rects[i];
				rect = CGRectInset(rect, -2, -1);
				rect.size.height -= 1;
				rect = CGRectIntegral(rect);
				TUIColor *color = [TUIColor colorWithWhite:1.0 alpha:1.0];
				[color set];
				CGContextSetShadowWithColor(context, CGSizeMake(0, 0), 8, color.CGColor);
				CGContextFillRoundRect(context, rect, 10);
			}
			
			CGContextRestoreGState(context);
		}
		
		CFRange selectedRange = [self _selectedRange];
		
		if(selectedRange.length > 0) {
      if(self.selectionColor)
        [self.selectionColor set];
      else
        [[NSColor selectedTextBackgroundColor] set];
			// draw (or mask) selection
			CFIndex rectCount = 100;
			CGRect rects[rectCount];
			AB_CTFrameGetRectsForRange([self.drawingAttributedString string],f, selectedRange, rects, &rectCount);
      NSBezierPath *path = AB_NSBezierPathRoundedFromRects(rects, rectCount);
			if(_flags.drawMaskDragSelection) {
        [path addClip];
			} else {
				[path fill];
			}
		}
		
		CGContextSetTextMatrix(context, CGAffineTransformIdentity);
		
		if(shadowColor)
			CGContextSetShadowWithColor(context, shadowOffset, shadowBlur, shadowColor.CGColor);

    CFRange range = CTFrameGetVisibleStringRange(f);
    if([self.drawingAttributedString length] > range.location + range.length) 
    {
      // should have an ellipsis
      float l = range.length - 3;
      if(l < 0)
        l = 0;
      NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithAttributedString:[self.drawingAttributedString attributedSubstringFromRange:NSMakeRange(range.location, l)]];
      NSRange r;
      NSDictionary *attrs = [self.drawingAttributedString attributesAtIndex:l effectiveRange:&r];
      NSAttributedString *ellipsis = [[NSAttributedString alloc] initWithString:@"…" attributes:attrs];
      [string appendAttributedString:ellipsis];
      CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)string);
      CGPathRef path = CGPathCreateMutable();
      CGPathAddRect((CGMutablePathRef)path, NULL, frame);
      CTFrameRef frameRef = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
      CTFrameDraw(frameRef, context); // draw actual text
      CFRelease(frameRef);
      CFRelease(framesetter);
      CFRelease(path);
    }
    else
      CTFrameDraw(f, context); // draw actual text
				
		CGContextRestoreGState(context);
	}
}

- (CGSize)size
{
	if(attributedString) {
    BOOL addOneLine = NO;
    if([attributedString length] > 0)
      addOneLine = [[[attributedString string] substringFromIndex:[attributedString length] - 1] isEqualToString:@"\n"];
		return AB_CTFrameGetSize([self ctFrame], addOneLine);
	}
	return CGSizeZero;
}

- (CGSize)sizeConstrainedToWidth:(CGFloat)width
{
	if(attributedString) {
		// height needs to be something big but not CGFLOAT_MAX big
		return [attributedString ab_sizeConstrainedToSize:CGSizeMake(width, 1000000.0f)];
	}
	return CGSizeZero;
}

- (void)setAttributedString:(NSAttributedString *)a
{
	attributedString = a;
	
	[self _resetFramesetter];
}

- (void)setFrame:(CGRect)f
{
	frame = f;
	[self _resetFramesetter];
}

- (void)reset
{
	[self _resetFramesetter];
}

- (CGRect)firstRectForCharacterRange:(CFRange)range
{
	CFIndex rectCount = 1;
	CGRect rects[rectCount];
	AB_CTFrameGetRectsForRange([attributedString string],[self ctFrame], range, rects, &rectCount);
	if(rectCount > 0) {
		return rects[0];
	}
	return CGRectZero;
}

- (NSArray *)rectsForCharacterRange:(CFRange)range
{
	CFIndex rectCount = 100;
	CGRect rects[rectCount];
	AB_CTFrameGetRectsForRange([attributedString string],[self ctFrame], range, rects, &rectCount);
	
	NSMutableArray *wrappedRects = [NSMutableArray arrayWithCapacity:rectCount];
	for(CFIndex i = 0; i < rectCount; i++) {
		[wrappedRects addObject:[NSValue valueWithRect:rects[i]]];
	}
	
	return [wrappedRects copy];
}

- (BOOL)backgroundDrawingEnabled
{
	return _flags.backgroundDrawingEnabled;
}

- (void)setBackgroundDrawingEnabled:(BOOL)enabled
{
	_flags.backgroundDrawingEnabled = enabled;
}

- (BOOL)preDrawBlocksEnabled
{
	return _flags.preDrawBlocksEnabled;
}

- (void)setPreDrawBlocksEnabled:(BOOL)enabled
{
	_flags.preDrawBlocksEnabled = enabled;
}

@end
