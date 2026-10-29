//
//  EC2DescribeVpcsRequest.m
//  Elastics
//

#import "EC2DescribeVpcsRequest.h"

@implementation EC2DescribeVpcsRequest

- (BOOL)start
{
	return [self startRequestWithAction:@"DescribeVpcs" parameters:nil];
}

- (EC2DescribeVpcsResponse *)response
{
	return (EC2DescribeVpcsResponse *)[super response];
}

- (EC2Vpc *)vpcWithId:(NSString *)vpcId
{
	for (EC2Vpc *vpc in self.response.vpcSet) {
		if ([vpc.vpcId isEqualToString:vpcId])
			return vpc;
	}
	return nil;
}

- (AWSResponse *)parseResponse
{
	return [EC2DescribeVpcsResponse responseWithRootXMLElement:self.responseParser.rootXMLElement];
}

@end
