//
//  EC2DescribeVpcsResponse.m
//  Elastics
//

#import "EC2DescribeVpcsResponse.h"
#import "EC2Vpc.h"

@interface EC2DescribeVpcsResponse ()
@property (nonatomic, retain) NSArray *vpcSet;
@end

@implementation EC2DescribeVpcsResponse

@synthesize vpcSet = _vpcSet;

- (void)dealloc
{
	TBRelease(_vpcSet);
	[super dealloc];
}

- (void)parseElement:(TBXMLElement *)element
{
	NSString *elementName = [TBXML elementName:element];

	if ([elementName isEqualToString:@"DescribeVpcsResponse"]) {
		element = element->firstChild;

		while (element) {
			elementName = [TBXML elementName:element];

			if ([elementName isEqualToString:@"vpcSet"])
				self.vpcSet = [self parseElement:element asArrayOf:[EC2Vpc class]];
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
