//
//  EC2Vpc.h
//  Elastics
//
//  One vpcSet item from DescribeVpcs.
//

#import <Foundation/Foundation.h>
#import "AWSType.h"

@interface EC2Vpc : AWSType {
@private
	NSString	*_vpcId;
	NSString	*_cidrBlock;
	BOOL		_isDefault;
	NSArray		*_tagSet;	// EC2Tag
}

@property (nonatomic, retain, readonly) NSString *vpcId;
@property (nonatomic, retain, readonly) NSString *cidrBlock;
@property (nonatomic, assign, readonly) BOOL isDefault;
@property (nonatomic, retain, readonly) NSArray *tagSet;

// Name tag; "Default VPC" for an unnamed default VPC; otherwise the VPC ID
- (NSString *)title;

@end
