//
//  EC2DescribeVpcsResponse.h
//  Elastics
//

#import "EC2Response.h"

@interface EC2DescribeVpcsResponse : EC2Response {
@private
	NSArray		*_vpcSet;	// EC2Vpc
}

@property (nonatomic, retain, readonly) NSArray *vpcSet;

@end
