//
//  EC2Instance.h
//  Elastics
//
//  Created by Dmitri Goutnik on 21/12/2010.
//  Copyright 2010 Tundra Bot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AWSType.h"
#import "EC2InstanceState.h"
#import "EC2Placement.h"
#import "EC2Group.h"
#import "EC2Monitoring.h"

@interface EC2Instance : AWSType {
@private
	NSString			*_instanceId;
	NSString			*_imageId;
	EC2InstanceState	*_instanceState;
	NSString			*_instanceType;
	NSString			*_dnsName;
	NSDate				*_launchTime;
	EC2Placement		*_placement;
	NSString			*_platform;
	EC2Monitoring		*_monitoring;
	NSString			*_privateIpAddress;
	NSString			*_ipAddress;
	NSArray				*_tagSet;   // EC2Tag
	NSArray				*_instanceGroupSet;   // EC2Group, security groups of the instance itself
}

@property (nonatomic, retain, readonly) NSString *instanceId;
@property (nonatomic, retain, readonly) NSString *imageId;
@property (nonatomic, retain, readonly) EC2InstanceState *instanceState;
@property (nonatomic, retain, readonly) NSString *instanceType;
@property (nonatomic, retain, readonly) NSString *dnsName;
@property (nonatomic, retain, readonly) NSDate *launchTime;
@property (nonatomic, retain, readonly) EC2Placement *placement;
@property (nonatomic, retain, readonly) NSString *platform;
@property (nonatomic, retain, readonly) EC2Monitoring *monitoring;
@property (nonatomic, retain, readonly) NSString *privateIpAddress;
@property (nonatomic, retain, readonly) NSString *ipAddress;
@property (nonatomic, retain, readonly) NSArray *tagSet;

// List of Security Groups from owning reservation
// Security groups: the instance's own groupSet (the only one filled in for VPC
// instances in current API versions), falling back to its reservation's groupSet.
- (NSArray *)groupSet;

// Security group names (IDs where a group has no name), comma-separated
- (NSString *)securityGroup;

// Returns value of "Name" tag if present, nil otherwise
- (NSString *)nameTag;

// Returns value of "aws:autoscaling:groupName" tag if present, nil otherwise
- (NSString *)autoscalingGroupName;

// Return value of "Name" tag if present, instanceId otherwise
- (NSString *)title;

@end
