//
//  EC2DescribeVpcsRequest.h
//  Elastics
//
//  DescribeVpcs for all VPCs in a region, used to show VPC names when grouping
//  instances by VPC. Needs the ec2:DescribeVpcs permission; without it, groups
//  are labelled with VPC IDs.
//

#import "EC2Request.h"
#import "EC2DescribeVpcsResponse.h"
#import "EC2Vpc.h"

@interface EC2DescribeVpcsRequest : EC2Request

- (BOOL)start;
- (EC2DescribeVpcsResponse *)response;
- (EC2Vpc *)vpcWithId:(NSString *)vpcId;   // nil until loaded or if unknown

@end
