//
//  EC2DescribeInstanceTypesRequest.m
//  Elastics
//

#import "EC2DescribeInstanceTypesRequest.h"

@implementation EC2DescribeInstanceTypesRequest

@synthesize instanceType = _instanceType;

- (void)dealloc
{
	[_instanceType release];
	[super dealloc];
}

- (BOOL)start
{
	NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
								_instanceType, @"InstanceType.1",
								nil];
	return [self startRequestWithAction:@"DescribeInstanceTypes" parameters:parameters];
}

- (EC2DescribeInstanceTypesResponse *)response
{
	return (EC2DescribeInstanceTypesResponse *)[super response];
}

- (EC2InstanceTypeInfo *)instanceTypeInfo
{
	for (EC2InstanceTypeInfo *info in self.response.instanceTypeSet) {
		if ([info.instanceType isEqualToString:_instanceType])
			return info;
	}
	return nil;
}

- (AWSResponse *)parseResponse
{
	return [EC2DescribeInstanceTypesResponse responseWithRootXMLElement:self.responseParser.rootXMLElement];
}

@end
