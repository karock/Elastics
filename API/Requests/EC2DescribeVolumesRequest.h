//
//  EC2DescribeVolumesRequest.h
//  Elastics
//
//  DescribeVolumes for the volumes attached to one instance. Needs the
//  ec2:DescribeVolumes permission; without it the request fails and callers
//  fall back to what DescribeInstances reports.
//

#import "EC2Request.h"
#import "EC2DescribeVolumesResponse.h"

@interface EC2DescribeVolumesRequest : EC2Request {
@private
	NSString	*_instanceId;
}

@property (nonatomic, copy) NSString *instanceId;

- (BOOL)start;
- (EC2DescribeVolumesResponse *)response;

@end
