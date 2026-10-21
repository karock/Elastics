//
//  EC2DescribeVolumesResponse.h
//  Elastics
//

#import "EC2Response.h"

@interface EC2DescribeVolumesResponse : EC2Response {
@private
	NSArray		*_volumeSet;	// EC2Volume
}

@property (nonatomic, retain, readonly) NSArray *volumeSet;

@end
