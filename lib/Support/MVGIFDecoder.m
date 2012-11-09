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
@property (readwrite) int colorF;
@property (readwrite, strong) NSMutableArray *shouldDispose;

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
            colorF            = colorF_,
            shouldDispose     = shouldDispose_;

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
    shouldDispose_ = [[NSMutableArray alloc] init];;

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
	
  // colorF (Global Color Table Flag       1 Bit)
  // Color Resolution                      3 Bits)
  // sorted (Sort Flag                     1 Bit)
  // colorS (Size of Global Color Table    3 Bits)
  
	if (aBuffer[4] & 0x80)
    self.colorF = 1;
  else
    self.colorF = 0;
  
	if (aBuffer[4] & 0x08)
    self.sorted = 1;
  else
    self.sorted = 0;
  
	self.colorS = (aBuffer[4] & 0x07);
  
	if (self.colorF == 1)
  {
    NSUInteger tableLength = (3 * pow(2, self.colorS + 1));
		[self getBytes:tableLength];
    
    unsigned char tableBuffer[tableLength];
    [self.buffer getBytes:tableBuffer length:tableLength];
    
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
			
      // Get disposal method
      int disposalMethod = (buffer[0] >> 2) & 0x07;
      [self.shouldDispose addObject:[NSNumber numberWithInt:disposalMethod]];
      
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
  
	NSMutableData *imageDescriptor = [NSMutableData dataWithData:self.buffer];
	
	unsigned char aBuffer[9];
	[self.buffer getBytes:aBuffer length:9];
	
	if (aBuffer[8] & 0x80) self.colorF = 1; else self.colorF = 0;
	
	unsigned char GIF_code = self.colorS, GIF_sort = self.sorted;
	
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
	
	int GIF_size = pow(2, GIF_code + 1);
	
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
	
  // Header
  NSMutableData *GIF_string = [NSMutableData dataWithData:
                               [@"GIF89a" dataUsingEncoding:NSUTF8StringEncoding]];
  
  // Logical Screen Descriptor
	[self.screen setData:[NSData dataWithBytes:bBuffer length:blength]];
  [GIF_string appendData:self.screen];
	
  // Global Color Table
	if (self.colorF == 1)
  {
		[self getBytes:(3 * GIF_size)];
    [GIF_string appendData:self.buffer];
	}
  else
  {
		[GIF_string appendData:self.global];
	}
	
	// Graphic Control Extension
	[GIF_string appendData:self.frameHeader];
	
  // Image Descriptor
	char endC = 0x2c;
	[GIF_string appendBytes:&endC length:sizeof(endC)];
  size_t clength = [imageDescriptor length];
	unsigned char cBuffer[clength];
	[imageDescriptor getBytes:cBuffer length:clength];
	
	cBuffer[8] &= 0x40;
	
	[imageDescriptor setData:[NSData dataWithBytes:cBuffer length:clength]];
	[GIF_string appendData:imageDescriptor];
  
  // Start of image
	[self getBytes:1];
	[GIF_string appendData:self.buffer];
	
  // Length of data
  while (YES)
  {
    [self getBytes:1];
    unsigned char cBuffer[1];
    [self.buffer getBytes:cBuffer length:1];
    NSUInteger dataLength = cBuffer[0];
    [GIF_string appendData:self.buffer];
    
    if (dataLength > 0)
    {
      [self getBytes:dataLength];
      [GIF_string appendData:self.buffer];
    }
    else
      break;
  }
	
  // GIF file terminator
	endC = 0x3b;
	[GIF_string appendBytes:&endC length:sizeof(endC)];
	
	// save the frame into the array of frames
	[self.framesData addObject:[GIF_string copy]];
}

@end
