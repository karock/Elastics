//
//  EC2DescribeInstanceTypesResponse.m
//  Elastics
//

#import "EC2DescribeInstanceTypesResponse.h"
#import "EC2InstanceTypeInfo.h"

@interface EC2DescribeInstanceTypesResponse ()
@property (nonatomic, retain) NSArray *instanceTypeSet;
@end

@implementation EC2DescribeInstanceTypesResponse

@synthesize instanceTypeSet = _instanceTypeSet;

- (void)dealloc
{
	TBRelease(_instanceTypeSet);
	[super dealloc];
}

- (void)parseElement:(TBXMLElement *)element
{
	NSString *elementName = [TBXML elementName:element];

	if ([elementName isEqualToString:@"DescribeInstanceTypesResponse"]) {
		element = element->firstChild;

		while (element) {
			elementName = [TBXML elementName:element];

			if ([elementName isEqualToString:@"instanceTypeSet"])
				self.instanceTypeSet = [self parseElement:element asArrayOf:[EC2InstanceTypeInfo class]];
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
