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
#import "TUITextView.h"
#import "TUITextViewEditor.h"
#import "TUITextRenderer+Event.h"

@interface TUITextView ()
- (void)_checkSpelling;
- (void)_replaceMisspelledWord:(NSMenuItem *)menuItem;

@property (nonatomic, strong) NSArray *lastCheckResults;
@property (nonatomic, strong) NSTextCheckingResult *selectedTextCheckingResult;
@end

@implementation TUITextView

@synthesize delegate;
@synthesize drawFrame;
@synthesize font;
@synthesize textColor;
@synthesize cursorColor;
@synthesize textAlignment;
@synthesize editable;
@synthesize contentInset;
@synthesize placeholder;
@synthesize placeholderColor;
@synthesize spellCheckingEnabled;
@synthesize lastCheckResults;
@synthesize selectedTextCheckingResult;
@synthesize autocorrectionEnabled;

- (void)_updateDefaultAttributes
{
	renderer.defaultAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
						 (id)[self.font ctFont], kCTFontAttributeName,
						 [self.textColor CGColor], kCTForegroundColorAttributeName,
						 ABNSParagraphStyleForTextAlignment(textAlignment), NSParagraphStyleAttributeName,
						 nil];
	renderer.markedAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
						(id)[self.font ctFont], kCTFontAttributeName,
						[self.textColor CGColor], kCTForegroundColorAttributeName,
						ABNSParagraphStyleForTextAlignment(textAlignment), NSParagraphStyleAttributeName,
						nil];
}

- (Class)textEditorClass
{
	return [TUITextViewEditor class];
}

- (id)initWithFrame:(CGRect)frame
{
	if((self = [super initWithFrame:frame])) {
		self.backgroundColor = [TUIColor clearColor];
    self.editable = YES;
		
		renderer = [[[self textEditorClass] alloc] init];
    renderer.view = self;
		self.textRenderers = [NSArray arrayWithObject:renderer];
		
		cursor = [[TUIView alloc] initWithFrame:CGRectZero];
		cursor.userInteractionEnabled = NO;
		cursorColor = cursor.backgroundColor = [TUIColor linkColor];
    if(self.windowHasFocus)
      [self addSubview:cursor];
		
		self.font = [TUIFont fontWithName:@"HelveticaNeue" size:12];
		self.textColor = [TUIColor blackColor];
		[self _updateDefaultAttributes];
    
    self.shouldDisplayWhenWindowChangesFocus = YES;
    [self addObserver:self 
           forKeyPath:@"windowHasFocus" 
              options:NSKeyValueObservingOptionNew 
              context:NULL];
	}
	return self;
}

- (void)dealloc
{
  [self removeObserver:self forKeyPath:@"windowHasFocus"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context
{
  if([keyPath isEqualToString:@"windowHasFocus"])
  {
    if(self.windowHasFocus)
      [self addSubview:cursor];
    else
      [cursor removeFromSuperview];
  }
  else
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)setSecure:(BOOL)secured
{
  [renderer setSecure:secured];
}

- (id)forwardingTargetForSelector:(SEL)sel
{
	if([renderer respondsToSelector:sel])
		return renderer;
	return nil;
}

- (void)mouseEntered:(NSEvent *)event
{
	[super mouseEntered:event];
	[[NSCursor IBeamCursor] push];
}

- (void)mouseExited:(NSEvent *)event
{
	[super mouseExited:event];
	[NSCursor pop];
}

- (void)setDelegate:(id <TUITextViewDelegate>)d
{
	delegate = d;
	_textViewFlags.delegateTextViewDidChange = [delegate respondsToSelector:@selector(textViewDidChange:)];
	_textViewFlags.delegateDoCommandBySelector = [delegate respondsToSelector:@selector(textView:doCommandBySelector:)];
}

- (TUIResponder *)initialFirstResponder
{
	return renderer.initialFirstResponder;
}

- (void)setFont:(TUIFont *)f
{
	font = f;
	[self _updateDefaultAttributes];
}

- (void)setTextColor:(TUIColor *)c
{
	textColor = c;
	[self _updateDefaultAttributes];
}	

- (void)setCursorColor:(TUIColor *)c
{
  cursorColor = c;
  cursor.backgroundColor = c;
}

- (void)setTextAlignment:(TUITextAlignment)t
{
	textAlignment = t;
	[self _updateDefaultAttributes];
}

- (BOOL)hasText
{
	return [[self text] length] > 0;
}

static CAAnimation *ThrobAnimation()
{
	CAKeyframeAnimation *a = [CAKeyframeAnimation animation];
	a.keyPath = @"opacity";
	a.values = [NSArray arrayWithObjects:
				[NSNumber numberWithFloat:1.0],
				[NSNumber numberWithFloat:1.0],
				[NSNumber numberWithFloat:1.0],
				[NSNumber numberWithFloat:1.0],
				[NSNumber numberWithFloat:1.0],
				[NSNumber numberWithFloat:0.5],
				[NSNumber numberWithFloat:0.0],
				[NSNumber numberWithFloat:0.0],
				[NSNumber numberWithFloat:0.0],
				[NSNumber numberWithFloat:1.0],
				nil];
	a.duration = 1.0;
	a.repeatCount = INT_MAX;
	return a;
}

- (BOOL)singleLine
{
	return NO; // text field returns yes
}

- (CGRect)textRect
{
	CGRect b = self.bounds;
	b.origin.x += contentInset.left;
	b.origin.y += contentInset.bottom;
	b.size.width -= contentInset.left + contentInset.right;
	b.size.height -= contentInset.bottom + contentInset.top;
	return b;
}

- (CGRect)_cursorRect
{
 	NSRange selection = [renderer selectedRange];
  BOOL fakeMetrics = ([[renderer backingStore] length] == 0);
  
  BOOL secure = renderer.isSecure;
  if(fakeMetrics) {
    // setup fake stuff - fake character with font
    TUIAttributedString *fake = [TUIAttributedString stringWithString:@"M"];
    fake.font = self.font;
    [renderer setSecure:NO];
    renderer.attributedString = fake;
    selection = NSMakeRange(0, 0);
  }
  
  // Ugh. So this seems to be a decent approximation for the height of the cursor. It doesn't always match the native cursor but what ev.
  CGRect r = CGRectIntegral([renderer firstRectForCharacterRange:ABCFRangeFromNSRange(selection)]);
  r.size.width = 2.0f;
  CGRect fontBoundingBox = CTFontGetBoundingBox(self.font.ctFont);
  r.size.height = round(fontBoundingBox.origin.y + fontBoundingBox.size.height);
  r.origin.y += floor(self.font.leading);
  
  // Sigh. So if the string ends with a return, CTFrameGetLines doesn't consider that a new line. So we have to fudge it.
  if(selection.location > 0 && [[self.text substringWithRange:NSMakeRange(selection.location - 1, 1)] isEqualToString:@"\n"])
  {
    CGRect firstCharacterRect = [renderer firstRectForCharacterRange:CFRangeMake(0, 0)];
    r.origin.y -= firstCharacterRect.size.height;
    r.origin.x = firstCharacterRect.origin.x;
  }
  
  [renderer setSecure:secure];
  
	if(fakeMetrics) {
		// restore
		renderer.attributedString = [renderer backingStore];
	}
  
	return r;
}

- (BOOL)_isKey // will fix
{
	NSResponder *firstResponder = [self.nsWindow firstResponder];
	if(firstResponder == self) {
		// responder should be on the renderer
		[self.nsWindow tui_makeFirstResponder:renderer];
		firstResponder = renderer;
	}
	return (firstResponder == renderer);
}

- (void)drawRect:(CGRect)rect
{
  static const CGFloat singleLineWidth = 20000.0f;
  
	if(drawFrame)
		drawFrame(self, rect);
	
  BOOL singleLine = [self singleLine];
	CGRect textRect = [self textRect];
  CGRect rendererFrame = textRect;
  if(singleLine) {
		rendererFrame.size.width = singleLineWidth;
	}

  renderer.frame = rendererFrame;
  
  // Single-line text views scroll horizontally with the cursor.
	CGRect cursorFrame = [self _cursorRect];
	CGFloat offset = 0.0f;
	if(singleLine)
  {
		if(CGRectGetMaxX(cursorFrame) > CGRectGetWidth(textRect))
    {
			offset = CGRectGetMinX(cursorFrame) - CGRectGetWidth(textRect);
			rendererFrame = CGRectMake(-offset, rendererFrame.origin.y, CGRectGetWidth(rendererFrame), CGRectGetHeight(rendererFrame));
			cursorFrame = CGRectOffset(cursorFrame, -offset - CGRectGetWidth(cursorFrame), 0.0f);
      renderer.frame = rendererFrame;
		}
	}
	
  BOOL resetAttributedString = NO;
  if(renderer.backingStore.length == 0 && self.placeholder && self.placeholder.length > 0)
  {
    TUIAttributedString *fake = [TUIAttributedString stringWithString:self.placeholder];
    fake.font = self.font;
    if(self.placeholderColor)
      fake.color = self.placeholderColor;
    renderer.attributedString = fake;
    resetAttributedString = YES;
  }
	[renderer draw];
  if(resetAttributedString)
  {
    renderer.attributedString = [renderer backingStore];
  }
	
	BOOL key = [self _isKey];
	NSRange selection = [renderer selectedRange];
	if(key && selection.length == 0) {
		cursor.hidden = NO;

		[TUIView setAnimationsEnabled:NO block:^{
			cursor.frame = cursorFrame;
		}];
		
		[cursor.layer removeAnimationForKey:@"opacity"];
		[cursor.layer addAnimation:ThrobAnimation() forKey:@"opacity"];
		
	} else {
		cursor.hidden = YES;
	}
}

- (void)_textDidChange
{
	if(_textViewFlags.delegateTextViewDidChange)
		[delegate textViewDidChange:self];
	
	if(spellCheckingEnabled) {
		[self _checkSpelling];
	}
}

- (void)_checkSpelling
{	
	lastCheckToken = [[NSSpellChecker sharedSpellChecker] requestCheckingOfString:self.text range:NSMakeRange(0, [self.text length]) types:NSTextCheckingTypeSpelling options:nil inSpellDocumentWithTag:0 completionHandler:^(NSInteger sequenceNumber, NSArray *results, NSOrthography *orthography, NSInteger wordCount) {
		// This needs to happen on the main thread so that the user doesn't enter more text while we're changing the attributed string.
		dispatch_async(dispatch_get_main_queue(), ^{
			// we only care about the most recent results, ignore anything older
			if(sequenceNumber != lastCheckToken) return;
						
			[[renderer backingStore] beginEditing];
			
			NSRange wholeStringRange = NSMakeRange(0, [self.text length]);
			[[renderer backingStore] removeAttribute:(id)kCTUnderlineColorAttributeName range:wholeStringRange];
			[[renderer backingStore] removeAttribute:(id)kCTUnderlineStyleAttributeName range:wholeStringRange];
			
			NSRange selectionRange = [self selectedRange];
			for(NSTextCheckingResult *result in results) {
				// Don't spell check the word they're typing, otherwise we're constantly marking it as misspelled and that's lame.
				BOOL isActiveWord = (result.range.location + result.range.length == selectionRange.location) && selectionRange.length == 0;
				if(isActiveWord) continue;
				
				[[renderer backingStore] addAttribute:(id)kCTUnderlineColorAttributeName value:(id)[TUIColor redColor].CGColor range:result.range];
				[[renderer backingStore] addAttribute:(id)kCTUnderlineStyleAttributeName value:[NSNumber numberWithInteger:kCTUnderlineStyleThick | kCTUnderlinePatternDot] range:result.range];
			}
			
			[[renderer backingStore] endEditing];
			[renderer reset]; // make sure we reset so that the renderer uses our new attributes

			[self setNeedsDisplay];
			
			self.lastCheckResults = results;
		});
	}];
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
	CFIndex stringIndex = [renderer stringIndexForEvent:event];
	for(NSTextCheckingResult *result in lastCheckResults) {
		if(stringIndex >= result.range.location && stringIndex <= result.range.location + result.range.length) {
			self.selectedTextCheckingResult = result;
			break;
		}
	}
	
	if(selectedTextCheckingResult == nil) 
    return [[self.textRenderers objectAtIndex:0] menuForEvent:event];
		
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	NSArray *guesses = [[NSSpellChecker sharedSpellChecker] guessesForWordRange:selectedTextCheckingResult.range inString:[self text] language:nil inSpellDocumentWithTag:0];
	if(guesses.count > 0) {
		for(NSString *guess in guesses) {
			NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:guess action:@selector(_replaceMisspelledWord:) keyEquivalent:@""];
			[menuItem setTarget:self];
			[menuItem setRepresentedObject:guess];
			[menu addItem:menuItem];
		}
	} else {
		NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"No guesses" action:NULL keyEquivalent:@""];
		[menu addItem:menuItem];
	}
	
	return menu;
}

- (void)_replaceMisspelledWord:(NSMenuItem *)menuItem
{	
	NSString *replacement = [menuItem representedObject];
	[[renderer backingStore] beginEditing];
	[[renderer backingStore] removeAttribute:(id)kCTUnderlineColorAttributeName range:selectedTextCheckingResult.range];
	[[renderer backingStore] removeAttribute:(id)kCTUnderlineStyleAttributeName range:selectedTextCheckingResult.range];
	[[renderer backingStore] replaceCharactersInRange:self.selectedTextCheckingResult.range withString:replacement];
	[[renderer backingStore] endEditing];
	[renderer reset];
	
	[self _textDidChange];
	
	self.selectedTextCheckingResult = nil;
}

- (NSRange)selectedRange
{
	return [renderer selectedRange];
}

- (void)setSelectedRange:(NSRange)r
{
	[renderer setSelectedRange:r];
}

- (NSString *)text
{
	return renderer.text;
}

- (void)setText:(NSString *)t
{
	[renderer setText:t];
}

- (void)selectAll:(id)sender
{
	[self setSelectedRange:NSMakeRange(0, [self.text length])];
}

- (BOOL)acceptsFirstResponder
{
  return self.editable;
}

- (BOOL)doCommandBySelector:(SEL)selector
{
	if(_textViewFlags.delegateDoCommandBySelector) {
		return [delegate textView:self doCommandBySelector:selector];
	}
	
	return NO;
}

@end

static void TUITextViewDrawRoundedFrame(TUIView *view, CGFloat radius, BOOL overDark)
{
	CGRect rect = view.bounds;
	CGContextRef ctx = TUIGraphicsGetCurrentContext();
	CGContextSaveGState(ctx);
	
	if(overDark) {
		rect.size.height -= 1;
		
		CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.4);
		CGContextFillRoundRect(ctx, rect, radius);
		
		rect.origin.y += 1;
		
		CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.65);
		CGContextFillRoundRect(ctx, rect, radius);
	} else {
		rect.size.height -= 1;
		
		CGContextSetRGBFillColor(ctx, 1, 1, 1, 0.5);
		CGContextFillRoundRect(ctx, rect, radius);
		
		rect.origin.y += 1;
		
		CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.35);
		CGContextFillRoundRect(ctx, rect, radius);
	}
	
	rect = CGRectInset(rect, 1, 1);
	CGContextClipToRoundRect(ctx, rect, radius);
	CGFloat a = 0.9;
	CGFloat b = 1.0;
	CGFloat colorA[] = {a, a, a, 1.0};
	CGFloat colorB[] = {b, b, b, 1.0};
	CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
	CGContextFillRect(ctx, rect);
	CGContextDrawLinearGradientBetweenPoints(ctx, CGPointMake(0, rect.size.height+5), colorA, CGPointMake(0, 5), colorB);
	
	CGContextRestoreGState(ctx);
}

TUIViewDrawRect TUITextViewSearchFrame(void)
{
	return [^(TUIView *view, CGRect rect) {
		TUITextViewDrawRoundedFrame(view, 	floor(view.bounds.size.height / 2), NO);
	} copy];
}

TUIViewDrawRect TUITextViewSearchFrameOverDark(void)
{
	return [^(TUIView *view, CGRect rect) {
		TUITextViewDrawRoundedFrame(view, 	floor(view.bounds.size.height / 2), YES);
	} copy];
}
