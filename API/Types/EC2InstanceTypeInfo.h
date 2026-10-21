//
//  EC2InstanceTypeInfo.h
//  Elastics
//
//  The instance store part of one instanceTypeSet item from DescribeInstanceTypes.
//

#import <Foundation/Foundation.h>
#import "AWSType.h"

// One DiskInfo entry: `count` identical disks of `sizeInGB` each
@interface EC2InstanceStoreDisk : AWSType {
@private
	NSInteger	_count;
	long long	_sizeInGB;
	NSString	*_type;
}

@property (nonatomic, assign, readonly) NSInteger count;
@property (nonatomic, assign, readonly) long long sizeInGB;   // decimal GB, as AWS reports it
@property (nonatomic, retain, readonly) NSString *type;       // ssd or hdd

@end

@interface EC2InstanceTypeInfo : AWSType {
@private
	NSString	*_instanceType;
	BOOL		_instanceStorageSupported;
	long long	_totalSizeInGB;
	NSString	*_nvmeSupport;
	NSString	*_encryptionSupport;
	NSArray		*_disks;
}

@property (nonatomic, retain, readonly) NSString *instanceType;
@property (nonatomic, assign, readonly) BOOL instanceStorageSupported;
@property (nonatomic, assign, readonly) long long totalSizeInGB;
@property (nonatomic, retain, readonly) NSString *nvmeSupport;        // unsupported, supported, required
@property (nonatomic, retain, readonly) NSString *encryptionSupport;  // unsupported, required
@property (nonatomic, retain, readonly) NSArray *disks;               // EC2InstanceStoreDisk

@end
