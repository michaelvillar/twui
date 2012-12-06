// MVGIFDecoder created by Michael Villar
// Based on AnimatedGif Created by Stijn Spijker on 2009-07-03.
// Based on gifdecode written april 2009 by Martin van Spanje, P-Edge media.

#define MVGIFDisposalMethodNone 0
#define MVGIFDisposalMethodDoNotDispose 1
#define MVGIFDisposalMethodRestoreToBackgroundColor 2
#define MVGIFDisposalMethodRestoreToPrevious 3

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@interface MVGIFDecoder : NSObject

@property (readonly, nonatomic) NSUInteger frameCount;
@property (strong, readonly) NSMutableArray *delays;
@property (strong, readonly) NSMutableArray *shouldDispose;
@property (strong, readonly) NSMutableArray *frameRects;

- (id)initWithData:(NSData*)data;
- (NSData*)dataFrameAtIndex:(NSUInteger)index;

@end
