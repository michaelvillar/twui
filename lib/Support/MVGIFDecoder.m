// MVGIFDecoder created by Michael Villar
// Based on AnimatedGif Created by Stijn Spijker on 2009-07-03.
// Based on gifdecode written april 2009 by Martin van Spanje, P-Edge media.

#import "MVGIFDecoder.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@interface MVGIFDecoder ()

@property (strong, readwrite) NSData *data;
@property (strong, readwrite) NSMutableData *buffer;
@property (strong, readwrite) NSMutableData *screen;
@property (strong, readwrite) NSMutableData *global;
@property (strong, readwrite) NSMutableData *frameHeader;
@property (strong, readwrite) NSMutableArray *delays;
@property (strong, readwrite) NSMutableArray *framesData;
@property (readwrite) int dataPointer;
@property (readwrite) int sorted;
@property (readwrite) int colorS;
@property (readwrite) int colorC;
@property (readwrite) int colorF;

- (void)decode;
- (bool)getBytes:(long)length;
- (bool)skipBytes:(long)length;
- (void)readExtensions;
- (void)readDescriptor;

@end

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation MVGIFDecoder

@synthesize data              = data_,
            buffer            = buffer_,
            screen            = screen_,
            global            = global_,
            frameHeader       = frameHeader_,
            delays            = delays_,
            framesData        = framesData_,
            dataPointer       = dataPointer_,
            sorted            = sorted_,
            colorS            = colorS_,
            colorC            = colorC_,
            colorF            = colorF_;

///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithData:(NSData*)data
{
  self = [super init];
  if(self) {
    data_ = data;
    buffer_ = [[NSMutableData alloc] init];
    global_ = [[NSMutableData alloc] init];
    screen_ = [[NSMutableData alloc] init];
    frameHeader_ = nil;
    
    delays_ = [[NSMutableArray alloc] init];
    framesData_ = [[NSMutableArray alloc] init];
    
    dataPointer_ = 0;

    [self decode];
  }
  return self;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSData*)dataFrameAtIndex:(NSUInteger)index
{
  if (index < self.frameCount)
	{
		return [self.framesData objectAtIndex:index];
	}
  return nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSUInteger)frameCount
{
  return self.framesData.count;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private Methods

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)decode
{
	[self skipBytes:6]; // GIF89a, throw away
	[self getBytes:7]; // Logical Screen Descriptor
	
  // Deep copy
	[self.screen setData:self.buffer];
	
  // Copy the read bytes into a local buffer on the stack
  // For easy byte access in the following lines.
  NSUInteger length = [self.buffer length];
	unsigned char aBuffer[length];
	[self.buffer getBytes:aBuffer length:length];
	
	if (aBuffer[4] & 0x80)
    self.colorF = 1;
  else
    self.colorF = 0;
  
	if (aBuffer[4] & 0x08)
    self.sorted = 1;
  else
    self.sorted = 0;
  
	self.colorC = (aBuffer[4] & 0x07);
	self.colorS = 2 << self.colorC;
	
	if (self.colorF == 1)
  {
		[self getBytes:(3 * self.colorS)];
    
    // Deep copy
		[self.global setData:self.buffer];
	}
	
	unsigned char bBuffer[1];
	while ([self getBytes:1] == YES)
  {
    [self.buffer getBytes:bBuffer length:1];
    
    if (bBuffer[0] == 0x3B)
    { // This is the end
      break;
    }
    
    switch (bBuffer[0])
    {
      case 0x21:
        // Graphic Control Extension (#n of n)
        [self readExtensions];
        break;
      case 0x2C:
        // Image Descriptor (#n of n)
        [self readDescriptor];
        break;
    }
	}
	
  self.buffer = nil;
  self.screen = nil;
  self.global = nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (bool)getBytes:(long)length
{
  if (self.buffer != nil)
  {
    self.buffer = nil;
  }
  
	if ([self.data length] >= self.dataPointer + length) // Don't read across the edge of the file..
  {
		self.buffer = [self.data subdataWithRange:NSMakeRange(self.dataPointer, length)].mutableCopy;
    self.dataPointer += length;
		return YES;
	}
  else
  {
    return NO;
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (bool)skipBytes:(long)length
{
  if ([self.data length] >= self.dataPointer + length)
  {
    self.dataPointer += length;
    return YES;
  }
  else
  {
    return NO;
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)readExtensions
{
	// 21! But we still could have an Application Extension,
	// so we want to check for the full signature.
	unsigned char cur[1], prev[1];
  [self getBytes:1];
  [self.buffer getBytes:cur length:1];
  
	while (cur[0] != 0x00)
  {
		// TODO: Known bug, the sequence F9 04 could occur in the Application Extension, we
		//       should check whether this combo follows directly after the 21.
		if (cur[0] == 0x04 && prev[0] == 0xF9)
		{
			[self getBytes:5];
      
			unsigned char buffer[5];
			[self.buffer getBytes:buffer length:5];
			
			// We save the delays for easy access.
			[self.delays addObject:[NSNumber numberWithInt:(buffer[1] | buffer[2] << 8)]];
      
			if (self.frameHeader == nil)
			{
        unsigned char board[8];
				board[0] = 0x21;
				board[1] = 0xF9;
				board[2] = 0x04;
				
				for(int i = 3, a = 0; a < 5; i++, a++)
				{
					board[i] = buffer[a];
				}
        
				self.frameHeader = [NSMutableData dataWithBytes:board length:8];
			}
      
			break;
		}
		
		prev[0] = cur[0];
    [self getBytes:1];
		[self.buffer getBytes:cur length:1];
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)readDescriptor
{
	[self getBytes:9];
  
  // Deep copy
	NSMutableData *GIF_screenTmp = [NSMutableData dataWithData:self.buffer];
	
	unsigned char aBuffer[9];
	[self.buffer getBytes:aBuffer length:9];
	
	if (aBuffer[8] & 0x80) self.colorF = 1; else self.colorF = 0;
	
	unsigned char GIF_code = self.colorC, GIF_sort = self.sorted;
	
	if (self.colorF == 1)
  {
		GIF_code = (aBuffer[8] & 0x07);
    
		if (aBuffer[8] & 0x20)
    {
      GIF_sort = 1;
    }
    else
    {
      GIF_sort = 0;
    }
	}
	
	int GIF_size = (2 << GIF_code);
	
	size_t blength = [self.screen length];
	unsigned char bBuffer[blength];
	[self.screen getBytes:bBuffer length:blength];
	
	bBuffer[4] = (bBuffer[4] & 0x70);
	bBuffer[4] = (bBuffer[4] | 0x80);
	bBuffer[4] = (bBuffer[4] | GIF_code);
	
	if (GIF_sort)
  {
		bBuffer[4] |= 0x08;
	}
	
  NSMutableData *GIF_string = [NSMutableData dataWithData:
                               [@"GIF89a" dataUsingEncoding:NSUTF8StringEncoding]];
	[self.screen setData:[NSData dataWithBytes:bBuffer length:blength]];
  [GIF_string appendData:self.screen];
	
	if (self.colorF == 1)
  {
		[self getBytes:(3 * GIF_size)];
    [GIF_string appendData:self.buffer];
	}
  else
  {
		[GIF_string appendData:self.global];
	}
	
	// Add Graphic Control Extension Frame (for transparancy)
	[GIF_string appendData:self.frameHeader];
	
	char endC = 0x2c;
	[GIF_string appendBytes:&endC length:sizeof(endC)];
	
	size_t clength = [GIF_screenTmp length];
	unsigned char cBuffer[clength];
	[GIF_screenTmp getBytes:cBuffer length:clength];
	
	cBuffer[8] &= 0x40;
	
	[GIF_screenTmp setData:[NSData dataWithBytes:cBuffer length:clength]];
	
	[GIF_string appendData: GIF_screenTmp];
	[self getBytes:1];
	[GIF_string appendData:self.buffer];
	
	while (true)
  {
		[self getBytes:1];
		[GIF_string appendData:self.buffer];
		
		unsigned char dBuffer[1];
		[self.buffer getBytes:dBuffer length:1];
		
		long u = (long) dBuffer[0];
    
		if (u != 0x00)
    {
			[self getBytes:u];
			[GIF_string appendData:self.buffer];
    }
    else
    {
      break;
    }
    
	}
	
	endC = 0x3b;
	[GIF_string appendBytes:&endC length:sizeof(endC)];
	
	// save the frame into the array of frames
	[self.framesData addObject:[GIF_string copy]];
}

@end
