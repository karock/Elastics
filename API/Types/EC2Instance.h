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
#import "EC2BlockDevice.h"

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
	NSString			*_instanceLifecycle;
	NSString			*_stateReasonMessage;
	NSString			*_stateTransitionReason;
	NSString			*_rootDeviceType;
	NSString			*_rootDeviceName;
	NSArray				*_blockDeviceMapping;   // EC2BlockDevice
	NSString			*_vpcId;
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
@property (nonatomic, retain, readonly) NSString *vpcId;                    // nil outside a VPC
@property (nonatomic, retain, readonly) NSString *rootDeviceType;           // ebs or instance-store
@property (nonatomic, retain, readonly) NSString *rootDeviceName;           // e.g. /dev/xvda
@property (nonatomic, retain, readonly) NSArray *blockDeviceMapping;        // EC2BlockDevice
@property (nonatomic, retain, readonly) NSString *instanceLifecycle;      // spot, scheduled, capacity-block, ...; nil for On-Demand
@property (nonatomic, retain, readonly) NSString *stateReasonMessage;     // stateReason/message, e.g. "Client.UserInitiatedShutdown: User initiated shutdown"
@property (nonatomic, retain, readonly) NSString *stateTransitionReason;  // reason, e.g. "User initiated (2026-10-21 10:00:00 GMT)"

// Display helpers
- (NSString *)tagValueForKey:(NSString *)key;   // value of the tag with this key (case-insensitive), or nil
- (NSArray *)sortedTags;                        // EC2Tag, sorted by key, AWS-managed "aws:" tags last
- (BOOL)isStopped;                              // stopped or stopping
- (BOOL)isTerminated;                           // terminated or shutting down
- (NSString *)lifecycleTitle;     // "On-Demand", "Spot", ...
- (NSString *)stateReasonTitle;   // readable reason for the last state change, or nil

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
