//
//  EC2BlockDevice.h
//  Elastics
//
//  One blockDeviceMapping item of an instance (DescribeInstances).
//

#import <Foundation/Foundation.h>
#import "AWSType.h"

@interface EC2BlockDevice : AWSType {
@private
	NSString	*_deviceName;
	NSString	*_volumeId;
	NSString	*_status;
	NSDate		*_attachTime;
	BOOL		_deleteOnTermination;
}

@property (nonatomic, retain, readonly) NSString *deviceName;     // e.g. /dev/xvda
@property (nonatomic, retain, readonly) NSString *volumeId;       // EBS volume, e.g. vol-0123...
@property (nonatomic, retain, readonly) NSString *status;         // attaching, attached, detaching, detached
@property (nonatomic, retain, readonly) NSDate *attachTime;
@property (nonatomic, assign, readonly) BOOL deleteOnTermination;

@end
