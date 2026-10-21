//
//  EC2Volume.m
//  Elastics
//

#import "EC2Volume.h"

@interface EC2Volume ()
@property (nonatomic, retain) NSString *volumeId;
@property (nonatomic, assign) NSInteger size;
@property (nonatomic, retain) NSString *volumeType;
@property (nonatomic, assign) NSInteger iops;
@property (nonatomic, assign) NSInteger throughput;
@property (nonatomic, assign) BOOL encrypted;
@property (nonatomic, retain) NSString *state;
@end

@implementation EC2Volume

@synthesize volumeId = _volumeId;
@synthesize size = _size;
@synthesize volumeType = _volumeType;
@synthesize iops = _iops;
@synthesize throughput = _throughput;
@synthesize encrypted = _encrypted;
@synthesize state = _state;

- (id)initFromXMLElement:(TBXMLElement *)element parent:(AWSType *)parent
{
	self = [super initFromXMLElement:element parent:parent];

	if (self) {
		element = element->firstChild;

		while (element) {
			NSString *elementName = [TBXML elementName:element];

			if ([elementName isEqualToString:@"volumeId"])
				self.volumeId = [TBXML textForElement:element];
			else if ([elementName isEqualToString:@"size"])
				self.size = [[TBXML textForElement:element] integerValue];
			else if ([elementName isEqualToString:@"volumeType"])
				self.volumeType = [TBXML textForElement:element];
			else if ([elementName isEqualToString:@"iops"])
				self.iops = [[TBXML textForElement:element] integerValue];
			else if ([elementName isEqualToString:@"throughput"])
				self.throughput = [[TBXML textForElement:element] integerValue];
			else if ([elementName isEqualToString:@"encrypted"])
				self.encrypted = [[TBXML textForElement:element] isEqualToString:@"true"];
			else if ([elementName isEqualToString:@"status"])
				self.state = [TBXML textForElement:element];

			element = element->nextSibling;
		}
	}

	return self;
}

- (void)dealloc
{
	TBRelease(_volumeId);
	TBRelease(_volumeType);
	TBRelease(_state);
	[super dealloc];
}

@end
