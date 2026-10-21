//
//  EC2DescribeInstanceTypesRequest.h
//  Elastics
//
//  DescribeInstanceTypes for one instance type, used for its instance store
//  (ephemeral) disks, which DescribeInstances does not report. Needs the
//  ec2:DescribeInstanceTypes permission.
//

#import "EC2Request.h"
#import "EC2DescribeInstanceTypesResponse.h"
#import "EC2InstanceTypeInfo.h"

@interface EC2DescribeInstanceTypesRequest : EC2Request {
@private
	NSString	*_instanceType;
}

@property (nonatomic, copy) NSString *instanceType;

- (BOOL)start;
- (EC2DescribeInstanceTypesResponse *)response;
- (EC2InstanceTypeInfo *)instanceTypeInfo;   // nil until loaded

@end
