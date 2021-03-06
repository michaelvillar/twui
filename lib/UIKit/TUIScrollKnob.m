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

#import "TUIKit.h"

#import "TUIScrollKnob.h"
#import "TUIScrollView.h"

@interface TUIScrollKnob ()
- (void)_hideKnob;
- (void)_updateKnob;
- (void)_updateKnobColor:(CGFloat)duration;
@end

@implementation TUIScrollKnob

@synthesize scrollView;
@synthesize knob;
@synthesize touchesInsideScrollView = touchesInsideScrollView_;

- (id)initWithFrame:(CGRect)frame
{
	if((self = [super initWithFrame:frame]))
	{
    touchesInsideScrollView_ = 0;
		knob = [[TUIView alloc] initWithFrame:CGRectMake(0, 0, 12, 12)];
		knob.layer.cornerRadius = 3.5;
		knob.userInteractionEnabled = NO;
		knob.backgroundColor = [TUIColor blackColor];
		[self addSubview:knob];
		[self _updateKnob];
		[self _updateKnobColor:0.0];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(preferredScrollerStyleChanged) 
                                                 name:NSPreferredScrollerStyleDidChangeNotification 
                                               object:nil];

	}
	return self;
}

- (void)preferredScrollerStyleChanged
{
  if(_hideKnobTimer) {
    [_hideKnobTimer invalidate], _hideKnobTimer = nil;
  }
  if([NSScroller preferredScrollerStyle] == NSScrollerStyleOverlay)
  {
    [self _hideKnob];
  }
  else
  {
    _knobHidden = NO;
    [self _updateKnobColor:0.2];
  }
}

- (BOOL)isVertical
{
	CGRect b = self.bounds;
	return b.size.height > b.size.width;
}

- (void)setTouchesInsideScrollView:(int)touchesInsideScrollView
{
  if(touchesInsideScrollView == touchesInsideScrollView_)
    return;
  touchesInsideScrollView_ = touchesInsideScrollView;
  if(self.touchesInsideScrollView >= 2)
  {
    if(_hideKnobTimer) {
      [_hideKnobTimer invalidate], _hideKnobTimer = nil;
    }
    _knobHidden = NO;
    [self _updateKnobColor:0.01];
  }
  else
  {
    if(!_hideKnobTimer)
    {
      _hideKnobTimer = [NSTimer scheduledTimerWithTimeInterval:0.8
                                                        target:self
                                                      selector:@selector(_hideKnob)
                                                      userInfo:nil
                                                       repeats:NO];
    }
  }
}

#define KNOB_CALCULATIONS(OFFSET, LENGTH, MIN_KNOB_SIZE) \
  float proportion = visible.size.LENGTH / contentSize.LENGTH; \
  float knobLength = trackBounds.size.LENGTH * proportion; \
  if(knobLength < MIN_KNOB_SIZE) knobLength = MIN_KNOB_SIZE; \
  float rangeOfMotion = trackBounds.size.LENGTH - knobLength; \
  float maxOffset = contentSize.LENGTH - visible.size.LENGTH; \
  float currentOffset = visible.origin.OFFSET; \
  float offsetProportion = 1.0 - (maxOffset - currentOffset) / maxOffset; \
  float knobOffset = offsetProportion * rangeOfMotion; \
  if(isnan(knobOffset)) knobOffset = 0.0; \
  if(isnan(knobLength)) knobLength = 0.0;

#define DEFAULT_MIN_KNOB_SIZE 25

- (void)_updateKnob
{
	CGRect trackBounds = self.bounds;
	CGRect visible = scrollView.visibleRect;
	CGSize contentSize = scrollView.contentSize;
	
	if([self isVertical]) {
		KNOB_CALCULATIONS(y, height, DEFAULT_MIN_KNOB_SIZE)
    
		CGRect frame;
		frame.origin.x = 0.0;
		frame.origin.y = knobOffset;
		frame.size.height = MIN(2000, knobLength);
		frame.size.width = 11;//trackBounds.size.width;
		frame = ABRectRoundOrigin(CGRectInset(frame, 2, 4));
    if(!CGRectEqualToRect(frame, knob.frame) && [NSScroller preferredScrollerStyle] == NSScrollerStyleOverlay) {
      if(scrollView.scrollIndicatorStyle != TUIScrollViewIndicatorVisibleNever)
      {
        if(_hideKnobTimer) {
          [_hideKnobTimer invalidate], _hideKnobTimer = nil;
        }
        if(self.touchesInsideScrollView < 2)
        {
          _hideKnobTimer = [NSTimer scheduledTimerWithTimeInterval:0.8
                                                            target:self 
                                                          selector:@selector(_hideKnob) 
                                                          userInfo:nil 
                                                           repeats:NO];
        }
        _knobHidden = NO;
        [self _updateKnobColor:0.01];
      }
      else
      {
        _knobHidden = YES;
        [self _updateKnobColor:0.01];
      }
    }
    knob.frame = frame;
	} else {
		KNOB_CALCULATIONS(x, width, DEFAULT_MIN_KNOB_SIZE)
		CGRect frame;
		frame.origin.x = knobOffset;
		frame.origin.y = 0.0;
		frame.size.width = MIN(2000, knobLength);
		frame.size.height = trackBounds.size.height;
		knob.frame = ABRectRoundOrigin(CGRectInset(frame, 4, 2));
	}
	
}

- (void)_hideKnob {
  _hideKnobTimer = nil;
  _knobHidden = YES;
  [self _updateKnobColor:0.2];
}

- (void)layoutSubviews
{
	[self _updateKnob];
}

- (void)flash
{
	CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
	animation.values = [NSArray arrayWithObjects:
						[NSNumber numberWithDouble:0.5],
						[NSNumber numberWithDouble:0.2],
						[NSNumber numberWithDouble:0.5],
						[NSNumber numberWithDouble:0.2],
						[NSNumber numberWithDouble:0.5],
						nil];
	[knob.layer addAnimation:animation forKey:@"opacity"];
}

-(unsigned int)scrollIndicatorStyle {
  return _scrollKnobFlags.scrollIndicatorStyle;
}

-(void)setScrollIndicatorStyle:(unsigned int)style {
  _scrollKnobFlags.scrollIndicatorStyle = style;
  switch(style){
    case TUIScrollViewIndicatorStyleLight:
      knob.backgroundColor = [TUIColor whiteColor];
      break;
    case TUIScrollViewIndicatorStyleDark:
    default:
      knob.backgroundColor = [TUIColor blackColor];
      break;
  }
}

- (void)_updateKnobColor:(CGFloat)duration
{
	[TUIView beginAnimations:nil context:NULL];
	[TUIView setAnimationDuration:duration];
  if(_knobHidden)
    knob.alpha = 0.0;
  else
    knob.alpha = 0.5;
	[TUIView commitAnimations];
}

- (void)mouseEntered:(NSEvent *)event
{
	_scrollKnobFlags.hover = 1;
	[self _updateKnobColor:0.08];
	// make sure we propagate mouse events
	[super mouseEntered:event];
}

- (void)mouseExited:(NSEvent *)event
{
	_scrollKnobFlags.hover = 0;
	[self _updateKnobColor:0.25];
	// make sure we propagate mouse events
	[super mouseExited:event];
}

- (void)mouseDown:(NSEvent *)event
{
	_mouseDown = [self localPointForEvent:event];
	_knobStartFrame = knob.frame;
  
  if(!_knobHidden)
  {
    _scrollKnobFlags.active = 1;
    [self _updateKnobColor:0.08];

    if([knob pointInside:[self convertPoint:_mouseDown toView:knob] withEvent:event]) { // can't use hitTest because userInteractionEnabled is NO
      // normal drag-knob-scroll
      _scrollKnobFlags.trackingInsideKnob = 1;
    } else {
      // page-scroll
      _scrollKnobFlags.trackingInsideKnob = 0;

      CGRect visible = scrollView.visibleRect;
      CGPoint contentOffset = scrollView.contentOffset;

      if([self isVertical]) {
        if(_mouseDown.y < _knobStartFrame.origin.y) {
          contentOffset.y += visible.size.height;
        } else {
          contentOffset.y -= visible.size.height;
        }
      } else {
        if(_mouseDown.x < _knobStartFrame.origin.x) {
          contentOffset.x += visible.size.width;
        } else {
          contentOffset.x -= visible.size.width;
        }
      }

      [scrollView setContentOffset:contentOffset animated:YES];
    }
  }
  else
    _scrollKnobFlags.trackingInsideKnob = 0;
  
	[super mouseDown:event];
}

- (void)mouseUp:(NSEvent *)event
{
	_scrollKnobFlags.active = 0;
	[self _updateKnobColor:0.08];
	[super mouseUp:event];
}

#define KNOB_CALCULATIONS_REVERSE(OFFSET, LENGTH) \
  CGRect knobFrame = _knobStartFrame; \
  knobFrame.origin.OFFSET += diff.LENGTH; \
  CGFloat knobOffset = knobFrame.origin.OFFSET; \
  CGFloat minKnobOffset = 0.0; \
  CGFloat maxKnobOffset = trackBounds.size.LENGTH - knobFrame.size.LENGTH; \
  CGFloat proportion = (knobOffset - 1.0) / (maxKnobOffset - minKnobOffset); \
  CGFloat maxContentOffset = contentSize.LENGTH - visible.size.LENGTH;

- (void)mouseDragged:(NSEvent *)event
{
	if(_scrollKnobFlags.trackingInsideKnob) { // normal knob drag
		CGPoint p = [self localPointForEvent:event];
		CGSize diff = CGSizeMake(p.x - _mouseDown.x, p.y - _mouseDown.y);
		
		CGRect trackBounds = self.bounds;
		CGRect visible = scrollView.visibleRect;
		CGSize contentSize = scrollView.contentSize;
		
		if([self isVertical]) {
			KNOB_CALCULATIONS_REVERSE(y, height)
			CGPoint scrollOffset = scrollView.contentOffset;
			scrollOffset.y = roundf(-proportion * maxContentOffset);
			scrollView.contentOffset = scrollOffset;
		} else {
			KNOB_CALCULATIONS_REVERSE(x, width)
			CGPoint scrollOffset = scrollView.contentOffset;
			scrollOffset.x = roundf(-proportion * maxContentOffset);
			scrollView.contentOffset = scrollOffset;
		}
	} else { // dragging in knob-track area
		// ignore
	}
}

@end
