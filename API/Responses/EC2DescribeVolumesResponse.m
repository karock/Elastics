//
//  EC2DescribeVolumesResponse.m
//  Elastics
//

#import "EC2DescribeVolumesResponse.h"
#import "EC2Volume.h"

@interface EC2DescribeVolumesResponse ()
@property (nonatomic, retain) NSArray *volumeSet;
@end

@implementation EC2DescribeVolumesResponse

@synthesize volumeSet = _volumeSet;

- (void)dealloc
{
	TBRelease(_volumeSet);
	[super dealloc];
}

- (void)parseElement:(TBXMLElement *)element
{
	NSString *elementName = [TBXML elementName:element];

	if ([elementName isEqualToString:@"DescribeVolumesResponse"]) {
		element = element->firstChild;

		while (element) {
			elementName = [TBXML elementName:element];

			if ([elementName isEqualToString:@"volumeSet"])
				self.volumeSet = [self parseElement:element asArrayOf:[EC2Volume class]];
			else
				[super parseElement:element];

			element = element->nextSibling;
		}
	}
	else {
		[super parseElement:element];
	}
}

@end
