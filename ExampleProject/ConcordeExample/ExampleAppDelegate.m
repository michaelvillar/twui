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

#import "ExampleAppDelegate.h"
#import "ExampleView.h"
#import "ExampleScrollView.h"

@implementation ExampleAppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	CGRect b = CGRectMake(0, 0, 500, 450);
	
	/** Table View */
	tableViewWindow = [[NSWindow alloc] initWithContentRect:b styleMask:NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask backing:NSBackingStoreBuffered defer:NO];
	[tableViewWindow setReleasedWhenClosed:FALSE];
	[tableViewWindow setMinSize:NSMakeSize(300, 250)];
	[tableViewWindow center];
	
	/* TUINSView is the bridge between the standard AppKit NSView-based heirarchy and the TUIView-based heirarchy */
	TUINSView *tuiTableViewContainer = [[TUINSView alloc] initWithFrame:b];
	[tableViewWindow setContentView:tuiTableViewContainer];
	
	TUIView *view = [[TUIView alloc] initWithFrame:b];
  view.backgroundColor = [TUIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
	tuiTableViewContainer.rootView = view;
  
  CGRect rect = CGRectMake(10, 10, 400, 100);
  TUIScrollView* scrollView_ = [[TUIScrollView alloc] initWithFrame:rect];
  TUITextView* textView_ = [[TUITextView alloc] initWithFrame:CGRectMake(0, 0, 
                                                            rect.size.width, 
                                                            150)];
  textView_.backgroundColor = [TUIColor clearColor];
  textView_.drawFrame = ^(TUIView * view, CGRect rect) {
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect:CGRectMake(0, 0, view.bounds.size.width, view.bounds.size.height)];
  };
  textView_.subpixelTextRenderingEnabled = YES;
  textView_.font = [TUIFont systemFontOfSize:12];
  textView_.autoresizingMask = TUIViewAutoresizingFlexibleWidth;
  
  scrollView_.autoresizingMask = TUIViewAutoresizingFlexibleWidth;
  scrollView_.horizontalScrollIndicatorVisibility = TUIScrollViewIndicatorVisibleNever;
  scrollView_.scrollEnabled = YES;
  scrollView_.clipsToBounds = YES;
  [scrollView_ setContentSize:textView_.bounds.size];
  [scrollView_ addSubview:textView_];

  [view addSubview:scrollView_];

	[self showTableViewExampleWindow:nil];
	
}

/**
 * @brief Show the table view example
 */
-(IBAction)showTableViewExampleWindow:(id)sender {
	[tableViewWindow makeKeyAndOrderFront:sender];
}

/**
 * @brief Show the scroll view example
 */
-(IBAction)showScrollViewExampleWindow:(id)sender {
	[scrollViewWindow makeKeyAndOrderFront:sender];
}

@end
