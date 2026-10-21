//
//  EC2Volume.h
//  Elastics
//
//  One volumeSet item from DescribeVolumes.
//

#import <Foundation/Foundation.h>
#import "AWSType.h"

@interface EC2Volume : AWSType {
@private
	NSString	*_volumeId;
	NSInteger	_size;
	NSString	*_volumeType;
	NSInteger	_iops;
	NSInteger	_throughput;
	BOOL		_encrypted;
	NSString	*_state;
}

@property (nonatomic, retain, readonly) NSString *volumeId;
@property (nonatomic, assign, readonly) NSInteger size;           // GiB
@property (nonatomic, retain, readonly) NSString *volumeType;     // gp3, gp2, io2, st1, ...
@property (nonatomic, assign, readonly) NSInteger iops;           // 0 if not reported
@property (nonatomic, assign, readonly) NSInteger throughput;     // MiB/s, gp3 only; 0 if not reported
@property (nonatomic, assign, readonly) BOOL encrypted;
@property (nonatomic, retain, readonly) NSString *state;          // creating, available, in-use, ...

@end
