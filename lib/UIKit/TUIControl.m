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

#import "TUIControl.h"
#import "TUIControl+Private.h"
#import "TUIView+Accessibility.h"
#import "TUIAccessibility.h"
#import "TUINSWindow.h"

#define kTUIControlHighlightedAnimationDuration 0.2

@implementation TUIControl

@synthesize highlightedStateAnimated  = _highlightedStateAnimated;

- (id)initWithFrame:(CGRect)rect
{
	self = [super initWithFrame:rect];
	if(self == nil) {
		return nil;
	}
	
  _highlightedStateAnimated = NO;
	self.accessibilityTraits |= TUIAccessibilityTraitButton;
	
	return self;
}


- (BOOL)isEnabled
{
	return !_controlFlags.disabled;
}

- (void)setEnabled:(BOOL)e
{
	_controlFlags.disabled = !e;
}

- (BOOL)isTracking
{
	return _controlFlags.tracking;
}

- (TUIControlState)state
{
  // start with the normal state, then OR in implicit state that is based on other properties
  TUIControlState actual = TUIControlStateNormal;
  
  if(_controlFlags.disabled)        actual |= TUIControlStateDisabled;
  if(_controlFlags.selected)        actual |= TUIControlStateSelected;
	if(_controlFlags.tracking)        actual |= TUIControlStateHighlighted;
	if(![self.nsWindow isKeyWindow] && !_controlFlags.tracking)  actual |= TUIControlStateNotKey;
	
	return actual;
}

/**
 * @brief Determine if this control is in a selected state
 * 
 * Not all controls have a selected state and the meaning of "selected" is left
 * to individual control implementations to define.
 * 
 * @return selected or not
 * 
 * @note This is a convenience interface to the #state property.
 * @see #state
 */
-(BOOL)selected {
  return _controlFlags.selected;
}

/**
 * @brief Specify whether this control is in a selected state
 * 
 * Not all controls have a selected state and the meaning of "selected" is left
 * to individual control implementations to define.
 * 
 * @param selected selected or not
 * 
 * @see #state
 */
-(void)setSelected:(BOOL)selected {
	[self _stateWillChange];
	_controlFlags.selected = selected;
	[self _stateDidChange];
	[self setNeedsDisplay];
}

- (BOOL)acceptsFirstMouse
{
	return _controlFlags.acceptsFirstMouse;
}

- (void)setAcceptsFirstMouse:(BOOL)s
{
	_controlFlags.acceptsFirstMouse = s;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
	return self.acceptsFirstMouse;
}

- (void)mouseDown:(NSEvent *)event
{
	[super mouseDown:event];
  
	// handle state change
	[self _stateWillChange];
	_controlFlags.tracking = 1;
	[self _stateDidChange];
	
	// handle touch down
	if([event clickCount] < 2) {
		[self sendActionsForControlEvents:TUIControlEventTouchDown];
	} else {
		[self sendActionsForControlEvents:TUIControlEventTouchDownRepeat];
	}
  
	// needs display
  if(self.highlightedStateAnimated)
    [TUIView animateWithDuration:kTUIControlHighlightedAnimationDuration animations:^{
      [self redraw];
    }];
  else
    [self setNeedsDisplay];
  
  BOOL keepTracking = YES;
  NSEvent * nextEvent = event;
  
  while(keepTracking) 
  {
    NSPoint mouseLocation = [self convertPoint:[self.nsView convertPoint:[nextEvent locationInWindow]
                                                                fromView:nil]
                                      fromView:nil];

    switch( [nextEvent type] ){
      case NSLeftMouseDragged:
        if(CGRectContainsPoint(self.bounds, mouseLocation))
        {
          if(_controlFlags.tracking != 1)
          {
            // handle state change
            [self _stateWillChange];
            _controlFlags.tracking = 1;
            [self _stateDidChange];
            
            // needs display
            if(self.highlightedStateAnimated)
              [TUIView animateWithDuration:kTUIControlHighlightedAnimationDuration animations:^{
                [self redraw];
              }];
            else
              [self setNeedsDisplay];
          }
        }
        else
        {
          if(_controlFlags.tracking != 0)
          {
            // handle state change
            [self _stateWillChange];
            _controlFlags.tracking = 0;
            [self _stateDidChange];
            
            // needs display
            if(self.highlightedStateAnimated)
              [TUIView animateWithDuration:kTUIControlHighlightedAnimationDuration animations:^{
                [self redraw];
              }];
            else
              [self setNeedsDisplay];
          }
        }
        break;
      case NSLeftMouseUp:
        [self mouseUp:nextEvent];
        return;
        break;
      default:
        break;
    }
    
    nextEvent = [self.nsWindow nextEventMatchingMask:NSLeftMouseDraggedMask | NSLeftMouseUpMask];
  }
}

- (void)mouseUp:(NSEvent *)event
{
	[super mouseUp:event];

  // handle state change
	[self _stateWillChange];
	_controlFlags.tracking = 0;
	[self _stateDidChange];
	
	if([self eventInside:event]) {
		if(![self didDrag]) {
			[self sendActionsForControlEvents:TUIControlEventTouchUpInside];
		}
	} else {
		[self sendActionsForControlEvents:TUIControlEventTouchUpOutside];
	}
	
	// needs display
	if(self.highlightedStateAnimated)
    [TUIView animateWithDuration:kTUIControlHighlightedAnimationDuration animations:^{
      [self redraw];
    }];
  else
    [self setNeedsDisplay];
}

@end
