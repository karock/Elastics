//
//  AWSConstants.m
//  Elastics
//
//  Created by Dmitri Goutnik on 29/11/2010.
//  Copyright 2010 Tundra Bot. All rights reserved.
//

#import "AWSConstants.h"

// AWS domain
NSString *const kAWSDomain  = @"amazonaws.com";

// Default region
NSString *const kAWSUSEastRegion = @"us-east-1";

// Region table, in display order. See AWSConstants.h about preference indices.
// Source: https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html
// China (amazonaws.com.cn) and the European Sovereign Cloud are separate partitions
// with separate endpoints and accounts, and are not included.
typedef struct {
	NSInteger preferenceIndex;
	NSString *region;
	NSString *title;
} AWSRegionInfo;

static const AWSRegionInfo kAWSRegionTable[] = {
	{  0, @"us-east-1",       @"US East (N. Virginia)" },
	{  8, @"us-east-2",       @"US East (Ohio)" },
	{  1, @"us-west-1",       @"US West (N. California)" },
	{  2, @"us-west-2",       @"US West (Oregon)" },
	{  9, @"af-south-1",      @"Africa (Cape Town)" },
	{ 10, @"ap-east-1",       @"Asia Pacific (Hong Kong)" },
	{ 11, @"ap-south-2",      @"Asia Pacific (Hyderabad)" },
	{ 12, @"ap-southeast-3",  @"Asia Pacific (Jakarta)" },
	{ 13, @"ap-southeast-5",  @"Asia Pacific (Malaysia)" },
	{ 14, @"ap-southeast-4",  @"Asia Pacific (Melbourne)" },
	{ 15, @"ap-south-1",      @"Asia Pacific (Mumbai)" },
	{ 16, @"ap-southeast-6",  @"Asia Pacific (New Zealand)" },
	{ 17, @"ap-northeast-3",  @"Asia Pacific (Osaka)" },
	{ 18, @"ap-northeast-2",  @"Asia Pacific (Seoul)" },
	{  4, @"ap-southeast-1",  @"Asia Pacific (Singapore)" },
	{ 19, @"ap-southeast-2",  @"Asia Pacific (Sydney)" },
	{ 20, @"ap-east-2",       @"Asia Pacific (Taipei)" },
	{ 21, @"ap-southeast-7",  @"Asia Pacific (Thailand)" },
	{  5, @"ap-northeast-1",  @"Asia Pacific (Tokyo)" },
	{ 22, @"ca-central-1",    @"Canada (Central)" },
	{ 23, @"ca-west-1",       @"Canada West (Calgary)" },
	{ 24, @"eu-central-1",    @"Europe (Frankfurt)" },
	{  3, @"eu-west-1",       @"Europe (Ireland)" },
	{ 25, @"eu-west-2",       @"Europe (London)" },
	{ 26, @"eu-south-1",      @"Europe (Milan)" },
	{ 27, @"eu-west-3",       @"Europe (Paris)" },
	{ 28, @"eu-south-2",      @"Europe (Spain)" },
	{ 29, @"eu-north-1",      @"Europe (Stockholm)" },
	{ 30, @"eu-central-2",    @"Europe (Zurich)" },
	{ 31, @"il-central-1",    @"Israel (Tel Aviv)" },
	{ 32, @"mx-central-1",    @"Mexico (Central)" },
	{ 33, @"me-south-1",      @"Middle East (Bahrain)" },
	{ 34, @"me-central-1",    @"Middle East (UAE)" },
	{  6, @"sa-east-1",       @"South America (São Paulo)" },
	{ 35, @"us-gov-east-1",   @"AWS GovCloud (US-East)" },
	{  7, @"us-gov-west-1",   @"AWS GovCloud (US-West)" },
};

static const NSUInteger kAWSRegionCount = sizeof(kAWSRegionTable) / sizeof(kAWSRegionTable[0]);

static const AWSRegionInfo *AWSRegionInfoForRegion(NSString *region)
{
	for (NSUInteger i = 0; i < kAWSRegionCount; i++) {
		if ([kAWSRegionTable[i].region isEqualToString:region])
			return &kAWSRegionTable[i];
	}
	return NULL;
}

NSArray *AWSRegions(void)
{
	static NSArray *regions = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:kAWSRegionCount];
		for (NSUInteger i = 0; i < kAWSRegionCount; i++)
			[result addObject:kAWSRegionTable[i].region];
		regions = result;
	});
	return regions;
}

NSString *AWSRegionTitle(NSString *region)
{
	const AWSRegionInfo *info = AWSRegionInfoForRegion(region);
	return info ? info->title : nil;
}

NSInteger AWSRegionPreferenceIndex(NSString *region)
{
	const AWSRegionInfo *info = AWSRegionInfoForRegion(region);
	return info ? info->preferenceIndex : NSNotFound;
}

NSString *AWSRegionForPreferenceIndex(NSInteger index)
{
	for (NSUInteger i = 0; i < kAWSRegionCount; i++) {
		if (kAWSRegionTable[i].preferenceIndex == index)
			return kAWSRegionTable[i].region;
	}
	return nil;
}

// Services
NSString *const kAWSEC2Service          = @"ec2";
NSString *const kAWSMonitoringService   = @"monitoring";

// Parameters
NSString *const kAWSInstanceIdParameter     = @"InstanceId";
NSString *const kAWSMetricNameParameter     = @"MetricName";
NSString *const kAWSStatisticsParameter     = @"Statistics";
NSString *const kAWSNamespaceParameter      = @"Namespace";
NSString *const kAWSStartTimeParameter      = @"StartTime";
NSString *const kAWSEndTimeParameter        = @"EndTime";
NSString *const kAWSPeriodParameter         = @"Period";

// Metrics
NSString *const kAWSCPUUtilizationMetric    = @"CPUUtilization";
NSString *const kAWSDiskReadBytesMetric     = @"DiskReadBytes";
NSString *const kAWSDiskReadOpsMetric       = @"DiskReadOps";
NSString *const kAWSDiskWriteBytesMetric    = @"DiskWriteBytes";
NSString *const kAWSDiskWriteOpsMetric      = @"DiskWriteOps";
NSString *const kAWSNetworkInMetric         = @"NetworkIn";
NSString *const kAWSNetworkOutMetric        = @"NetworkOut";

// Errors
NSString *const kAWSErrorDomain     = @"AWSError";
