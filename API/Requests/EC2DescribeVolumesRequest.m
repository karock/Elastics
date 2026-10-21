//
//  EC2DescribeVolumesRequest.m
//  Elastics
//

#import "EC2DescribeVolumesRequest.h"

@implementation EC2DescribeVolumesRequest

@synthesize instanceId = _instanceId;

- (void)dealloc
{
	[_instanceId release];
	[super dealloc];
}

- (BOOL)start
{
	NSDictionary *filter = [NSDictionary dictionaryWithObjectsAndKeys:
							[NSArray arrayWithObject:_instanceId], @"attachment.instance-id",
							nil];
	return [self startRequestWithAction:@"DescribeVolumes" parameters:[self filterListFromDictionary:filter]];
}

- (EC2DescribeVolumesResponse *)response
{
	return (EC2DescribeVolumesResponse *)[super response];
}

- (AWSResponse *)parseResponse
{
	return [EC2DescribeVolumesResponse responseWithRootXMLElement:self.responseParser.rootXMLElement];
}

@end
