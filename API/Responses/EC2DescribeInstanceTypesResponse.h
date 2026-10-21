//
//  EC2DescribeInstanceTypesResponse.h
//  Elastics
//

#import "EC2Response.h"

@interface EC2DescribeInstanceTypesResponse : EC2Response {
@private
	NSArray		*_instanceTypeSet;	// EC2InstanceTypeInfo
}

@property (nonatomic, retain, readonly) NSArray *instanceTypeSet;

@end
