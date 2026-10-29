//
//  DataSource.m
//  Elastic
//
//  Created by Dmitri Goutnik on 21/12/2010.
//  Copyright 2010 Tundra Bot. All rights reserved.
//

#import "DataSource.h"
#import "TBMacros.h"
#import "Preferences.h"

const NSTimeInterval kMaxRefreshAge                 = 5.;
const NSTimeInterval kMaxStatisticsAge              = 60.;
const NSTimeInterval kMaxOtherRegionsRefreshAge     = 35.;
const NSTimeInterval kMaxVpcsRefreshAge             = 300.;

NSString *const kDataSourceRefreshCompletedNotification	= @"kDataSourceRefreshCompletedNotification";

NSString *const kDataSourceRefreshTypeInfoKey   = @"kDataSourceRefreshTypeInfoKey";
NSString *const kDataSourceErrorInfoKey         = @"kDataSourceErrorInfoKey";

NSString *const kDataSourceCurrentRegionRefreshType = @"kDataSourceCurrentRegionRefreshType";
NSString *const kDataSourceAllRegionsRefreshType    = @"kDataSourceAllRegionsRefreshType";
NSString *const kDataSourceVpcsRefreshType          = @"kDataSourceVpcsRefreshType";

static NSString *const kRefreshInfoStartedAtKey     = @"kRefreshInfoStartedAtKey";
static NSString *const kRefreshInfoFinishedAtKey    = @"kRefreshInfoFinishedAtKey";
static NSString *const kRefreshInfoRequestSetKey    = @"kRefreshInfoRequestSetKey";

@implementation DataSource

@synthesize instanceMonitoringMetrics = _instanceMonitoringMetrics;

#pragma mark - Initialization

TB_SINGLETON(DataSource);

- (id)init
{
	self = [super init];
	if (self) {
        [self reset];
	}
	return self;
}

- (void)dealloc
{
	TBRelease(_runningRefreshes);
	TBRelease(_instanceRequests);
	TBRelease(_instanceMonitoringRequests);
	TBRelease(_instanceVolumeRequests);
	TBRelease(_instanceTypeRequests);
	TBRelease(_vpcRequests);
	TBRelease(_instanceMonitoringMetrics);

	[super dealloc];
}

#pragma mark - Request handling

+ (NSDictionary *)defaultRequestOptions
{
	return [AWSRequest defaultOptions];
}

+ (void)setDefaultRequestOptions:(NSDictionary *)options
{
	[AWSRequest setDefaultOptions:options];
}

- (void)reset
{
    // as there's no way to cancel running requests, set their delegate to nil
	@synchronized(self) {
		NSArray *keys = [_runningRefreshes allKeys];
		for (NSString *key in keys) {
            
			NSMutableDictionary *refreshInfo = [_runningRefreshes objectForKey:key];
			NSMutableSet *requestSet = [refreshInfo objectForKey:kRefreshInfoRequestSetKey];
            
            for (AWSRequest *request in requestSet) {
                request.delegate = nil;
            }
        }
    }
    
	TBRelease(_runningRefreshes);
	TBRelease(_instanceRequests);
	TBRelease(_instanceMonitoringRequests);
	TBRelease(_instanceVolumeRequests);
	TBRelease(_instanceTypeRequests);
	TBRelease(_vpcRequests);
	TBRelease(_instanceMonitoringMetrics);

    _instanceMonitoringMetrics = [[NSSet alloc] initWithObjects:kAWSCPUUtilizationMetric, nil];
    _runningRefreshes = [[NSMutableDictionary alloc] init];
    _instanceRequests = [[NSMutableDictionary alloc] init];
    _instanceMonitoringRequests = [[NSMutableDictionary alloc] init];
    _instanceVolumeRequests = [[NSMutableDictionary alloc] init];
    _instanceTypeRequests = [[NSMutableDictionary alloc] init];
    _vpcRequests = [[NSMutableDictionary alloc] init];
}

- (BOOL)refreshCurrentRegionIgnoringAge:(BOOL)ignoreAge
{
	@synchronized(self) {

		NSMutableDictionary *refreshInfo = [_runningRefreshes objectForKey:kDataSourceCurrentRegionRefreshType];
		if (refreshInfo) {
			TBTrace(@"current region refresh is already in progress");
			return NO;
		}
		refreshInfo = [NSMutableDictionary dictionary];

		[refreshInfo setObject:kDataSourceCurrentRegionRefreshType forKey:kDataSourceRefreshTypeInfoKey];
		[refreshInfo setObject:[NSDate date] forKey:kRefreshInfoStartedAtKey];

		NSMutableSet *requestSet = [NSMutableSet set];
		[refreshInfo setObject:requestSet forKey:kRefreshInfoRequestSetKey];

        NSString *currentRegion = [[NSUserDefaults standardUserDefaults] awsRegion];
        EC2DescribeInstancesRequest *instanceRequest = [_instanceRequests objectForKey:currentRegion];
		if (!instanceRequest) {
			instanceRequest = [[EC2DescribeInstancesRequest alloc] initWithOptions:nil delegate:self];
            instanceRequest.region = currentRegion;
            [_instanceRequests setObject:instanceRequest forKey:currentRegion];
            [instanceRequest release];
		}
	
        // only schedule refresh request when it is not already running and it is older than kMaxRefreshAge
        if (![instanceRequest isRunning] && (ignoreAge || [instanceRequest age] > kMaxRefreshAge))
            [requestSet addObject:instanceRequest];
//        else
//            TBTrace(@"skipping request with age %.2f", [instanceRequest age]);

		// do we have anything scheduled?
		if (![requestSet count])
            return NO;
        
        // add refreshInfo to running requests and start requests
        [_runningRefreshes setObject:refreshInfo forKey:kDataSourceCurrentRegionRefreshType];
        for (AWSRequest *request in requestSet) {
            [request start];
        }

        return YES;
    }
}

- (BOOL)refreshAllRegionsIgnoringAge:(BOOL)ignoreAge
{
	@synchronized(self) {
		
        NSMutableDictionary *refreshInfo = [_runningRefreshes objectForKey:kDataSourceAllRegionsRefreshType];
		if (refreshInfo) {
			TBTrace(@"other regions refresh is already in progress");
			return NO;
		}
		refreshInfo = [NSMutableDictionary dictionary];
        
		[refreshInfo setObject:kDataSourceAllRegionsRefreshType forKey:kDataSourceRefreshTypeInfoKey];
		[refreshInfo setObject:[NSDate date] forKey:kRefreshInfoStartedAtKey];
        
		NSMutableSet *requestSet = [NSMutableSet set];
		[refreshInfo setObject:requestSet forKey:kRefreshInfoRequestSetKey];
        
        for (NSString *awsRegion in [[NSUserDefaults standardUserDefaults] activeAWSRegions]) {
            EC2DescribeInstancesRequest *instanceRequest = [_instanceRequests objectForKey:awsRegion];
            if (!instanceRequest) {
                instanceRequest = [[EC2DescribeInstancesRequest alloc] initWithOptions:nil delegate:self];
                instanceRequest.region = awsRegion;
                [_instanceRequests setObject:instanceRequest forKey:awsRegion];
                [instanceRequest release];
            }

            // only schedule request when it is not already running and when it is older than kMaxOtherRegionsRefreshAge
            if (![instanceRequest isRunning] && (ignoreAge || [instanceRequest age] > kMaxOtherRegionsRefreshAge))
                [requestSet addObject:instanceRequest];
//            else
//                TBTrace(@"skipping %@ request with age %.2f", awsRegion, [instanceRequest age]);
        }
        
		// do we have anything scheduled?
		if (![requestSet count])
            return NO;
        
        // add refreshInfo to running requests and start requests
        [_runningRefreshes setObject:refreshInfo forKey:kDataSourceAllRegionsRefreshType];
        for (AWSRequest *request in requestSet) {
            [request start];
        }
        
        return YES;
    }
}

// VPC names for grouping by VPC. A separate refresh type, so that a failure here
// (e.g. no ec2:DescribeVpcs permission) never turns the instance list into an error.
- (BOOL)refreshVpcsIgnoringAge:(BOOL)ignoreAge
{
	@synchronized(self) {
		if ([_runningRefreshes objectForKey:kDataSourceVpcsRefreshType])
			return NO;

		NSString *currentRegion = [[NSUserDefaults standardUserDefaults] awsRegion];
		EC2DescribeVpcsRequest *vpcRequest = [_vpcRequests objectForKey:currentRegion];
		if (!vpcRequest) {
			vpcRequest = [[EC2DescribeVpcsRequest alloc] initWithOptions:nil delegate:self];
			vpcRequest.region = currentRegion;
			[_vpcRequests setObject:vpcRequest forKey:currentRegion];
			[vpcRequest release];
		}

		if ([vpcRequest isRunning] || (!ignoreAge && [vpcRequest age] <= kMaxVpcsRefreshAge))
			return NO;

		NSMutableDictionary *refreshInfo = [NSMutableDictionary dictionary];
		[refreshInfo setObject:kDataSourceVpcsRefreshType forKey:kDataSourceRefreshTypeInfoKey];
		[refreshInfo setObject:[NSDate date] forKey:kRefreshInfoStartedAtKey];
		[refreshInfo setObject:[NSMutableSet setWithObject:vpcRequest] forKey:kRefreshInfoRequestSetKey];

		[_runningRefreshes setObject:refreshInfo forKey:kDataSourceVpcsRefreshType];
		[vpcRequest start];

		return YES;
	}
}

- (EC2Vpc *)vpcWithId:(NSString *)vpcId
{
	if (![vpcId length])
		return nil;
	NSString *currentRegion = [[NSUserDefaults standardUserDefaults] awsRegion];
	return [[_vpcRequests objectForKey:currentRegion] vpcWithId:vpcId];
}

- (BOOL)refreshInstance:(NSString *)instanceId ignoringAge:(BOOL)ignoreAge
{
	@synchronized(self) {
		
		NSMutableDictionary *refreshInfo = [_runningRefreshes objectForKey:instanceId];
		if (refreshInfo) {
			TBTrace(@"instance refresh for %@ is already in progress", instanceId);
			return NO;
		}
		refreshInfo = [NSMutableDictionary dictionary];
		
		[refreshInfo setObject:instanceId forKey:kDataSourceRefreshTypeInfoKey];
		[refreshInfo setObject:[NSDate date] forKey:kRefreshInfoStartedAtKey];
		
		NSMutableSet *requestSet = [NSMutableSet set];
		[refreshInfo setObject:requestSet forKey:kRefreshInfoRequestSetKey];

		NSMutableDictionary *instanceMonitoringRequests = [_instanceMonitoringRequests objectForKey:instanceId];
		if (!instanceMonitoringRequests) {
			instanceMonitoringRequests = [NSMutableDictionary dictionary];
			[_instanceMonitoringRequests setObject:instanceMonitoringRequests forKey:instanceId];
		}

        NSString *currentRegion = [[NSUserDefaults standardUserDefaults] awsRegion];
		for (NSString *metric in _instanceMonitoringMetrics) {
			MonitoringGetMetricStatisticsRequest *monitoringRequest = [instanceMonitoringRequests objectForKey:metric];
			if (!monitoringRequest) {
				monitoringRequest = [[MonitoringGetMetricStatisticsRequest alloc] initWithOptions:nil delegate:self];
                monitoringRequest.region = currentRegion;
				monitoringRequest.instanceId = instanceId;
				monitoringRequest.metric = metric;
				[instanceMonitoringRequests setObject:monitoringRequest forKey:metric];
				[monitoringRequest release];
			}

			// only schedule monitoring data refresh when it is not running, or when it is older than kMaxStatisticsAge, or when it has no datapoints
			if (![monitoringRequest isRunning] && (ignoreAge || [monitoringRequest age] > kMaxStatisticsAge || ![monitoringRequest.response.result.datapoints count]))
				[requestSet addObject:monitoringRequest];
//			else
//				TBTrace(@"skipping instance %@ stats request with age %.2f", instanceId, [monitoringRequest age]);
		}
	
		// volume details (size, type) for the Storage section; refreshed at most every
		// kMaxStatisticsAge, so a denied DescribeVolumes is not retried on every menu open
		EC2DescribeVolumesRequest *volumeRequest = [_instanceVolumeRequests objectForKey:instanceId];
		if (!volumeRequest) {
			volumeRequest = [[EC2DescribeVolumesRequest alloc] initWithOptions:nil delegate:self];
			volumeRequest.region = currentRegion;
			volumeRequest.instanceId = instanceId;
			[_instanceVolumeRequests setObject:volumeRequest forKey:instanceId];
			[volumeRequest release];
		}
		if (![volumeRequest isRunning] && (ignoreAge || [volumeRequest age] > kMaxStatisticsAge))
			[requestSet addObject:volumeRequest];

		// instance type details (instance store disks) never change: load once per type,
		// retrying a failed load at most every kMaxStatisticsAge
		NSString *instanceType = [[self instance:instanceId] instanceType];
		if ([instanceType length]) {
			EC2DescribeInstanceTypesRequest *typeRequest = [_instanceTypeRequests objectForKey:instanceType];
			if (!typeRequest) {
				typeRequest = [[EC2DescribeInstanceTypesRequest alloc] initWithOptions:nil delegate:self];
				typeRequest.region = currentRegion;
				typeRequest.instanceType = instanceType;
				[_instanceTypeRequests setObject:typeRequest forKey:instanceType];
				[typeRequest release];
			}
			if (![typeRequest isRunning] && ![typeRequest instanceTypeInfo] && [typeRequest age] > kMaxStatisticsAge)
				[requestSet addObject:typeRequest];
		}

		// do we have anything scheduled?
		if (![requestSet count])
            return NO;
        
        // add refreshInfo to running requests and start requests
        [_runningRefreshes setObject:refreshInfo forKey:instanceId];
        for (AWSRequest *request in requestSet) {
            [request start];
        }
        
        return YES;
	}
}

#pragma mark - Request delegate

- (void)requestDidStartLoading:(AWSRequest *)request
{
//	TBTrace(@"");
}

- (void)requestDidFinishLoading:(AWSRequest *)request
{
//	TBTrace(@"");
	
	NSMutableDictionary *finishedRefreshInfo = nil;
	
	@synchronized(self) {
		NSArray *keys = [_runningRefreshes allKeys];
		for (NSString *key in keys) {
            
			NSMutableDictionary *refreshInfo = [_runningRefreshes objectForKey:key];
			NSMutableSet *requestSet = [refreshInfo objectForKey:kRefreshInfoRequestSetKey];
			
            if ([requestSet containsObject:request]) {
                [requestSet removeObject:request];
			
                if ([requestSet count] == 0) {
                    [refreshInfo setObject:[NSDate date] forKey:kRefreshInfoFinishedAtKey];
                    finishedRefreshInfo = [refreshInfo retain];
                    [_runningRefreshes removeObjectForKey:key];
                    break;
                }
            }
		}
	}
	
	if (finishedRefreshInfo) {
        
#ifdef TB_DEBUG
        NSDate *startedAt = [finishedRefreshInfo objectForKey:kRefreshInfoStartedAtKey];
        NSDate *finishedAt = [finishedRefreshInfo objectForKey:kRefreshInfoFinishedAtKey];
        NSString *refreshType = [finishedRefreshInfo objectForKey:kDataSourceRefreshTypeInfoKey];
        TBTrace(@"%.2fs, %@", [finishedAt timeIntervalSinceDate:startedAt], refreshType);
#endif
		
        [[NSNotificationCenter defaultCenter] postNotificationName:kDataSourceRefreshCompletedNotification
                                                            object:self
                                                          userInfo:finishedRefreshInfo];
	
        [finishedRefreshInfo release];
    }
}

- (void)request:(AWSRequest *)request didFailWithError:(NSError *)error
{
	//	TBTrace(@"");
	
	NSMutableDictionary *finishedRefreshInfo = nil;
	
	@synchronized(self) {
		NSArray *keys = [_runningRefreshes allKeys];
		for (NSString *key in keys) {
            
			NSMutableDictionary *refreshInfo = [_runningRefreshes objectForKey:key];
			NSMutableSet *requestSet = [refreshInfo objectForKey:kRefreshInfoRequestSetKey];
			
            if ([requestSet containsObject:request]) {
                [requestSet removeObject:request];
			
                if ([requestSet count] == 0) {
                    [refreshInfo setObject:[NSDate date] forKey:kRefreshInfoFinishedAtKey];
                    finishedRefreshInfo = [refreshInfo retain];
                    [_runningRefreshes removeObjectForKey:key];
                    
                    break;
                }
            }
		}
	}
	
	if (finishedRefreshInfo) {
	
#ifdef TB_DEBUG
        NSDate *startedAt = [finishedRefreshInfo objectForKey:kRefreshInfoStartedAtKey];
        NSDate *finishedAt = [finishedRefreshInfo objectForKey:kRefreshInfoFinishedAtKey];
        NSString *refreshType = [finishedRefreshInfo objectForKey:kDataSourceRefreshTypeInfoKey];
        TBTrace(@"%.2fs, %@, error: %@", [finishedAt timeIntervalSinceDate:startedAt], refreshType, error);
#endif
	
        [finishedRefreshInfo setObject:error forKey:kDataSourceErrorInfoKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:kDataSourceRefreshCompletedNotification
                                                            object:self
                                                          userInfo:finishedRefreshInfo];
	
        [finishedRefreshInfo release];
    }
}

#pragma mark - Data accessors and helpers

- (EC2InstanceTypeInfo *)instanceTypeInfoForInstanceType:(NSString *)instanceType
{
	return instanceType ? [[_instanceTypeRequests objectForKey:instanceType] instanceTypeInfo] : nil;
}

- (NSDictionary *)volumesForInstance:(NSString *)instanceId
{
	EC2DescribeVolumesRequest *request = [_instanceVolumeRequests objectForKey:instanceId];
	NSMutableDictionary *result = [NSMutableDictionary dictionary];

	for (EC2Volume *volume in request.response.volumeSet) {
		if (volume.volumeId)
			[result setObject:volume forKey:volume.volumeId];
	}

	return result;
}

- (NSArray *)instances
{
    NSString *currentRegion = [[NSUserDefaults standardUserDefaults] awsRegion];
    EC2DescribeInstancesRequest *request = [_instanceRequests objectForKey:currentRegion];
	return request.response.instancesSet;
}

- (NSArray *)sortedInstances
{
    NSString *currentRegion = [[NSUserDefaults standardUserDefaults] awsRegion];
    EC2DescribeInstancesRequest *request = [_instanceRequests objectForKey:currentRegion];
	return [request.response.instancesSet sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)runningInstances
{
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        EC2Instance *instance = (EC2Instance *)evaluatedObject;
        return (instance.instanceState.code != EC2_INSTANCE_STATE_TERMINATED && instance.instanceState.code != EC2_INSTANCE_STATE_STOPPED);
    }];
    return [[self instances] filteredArrayUsingPredicate:predicate];
}

- (NSArray *)sortedRunningInstances
{
    return [[self runningInstances] sortedArrayUsingSelector:@selector(compare:)];
}

- (EC2Instance *)instance:(NSString *)instanceId
{
	NSUInteger instanceIdx = [self.instances indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
		*stop = [[obj instanceId] isEqualToString:instanceId];
		return *stop;
	}];
	
	return instanceIdx != NSNotFound ? [self.instances objectAtIndex:instanceIdx] : nil;
}

- (NSUInteger)instanceCountInRegion:(NSString *)awsRegion hideTerminatedInstances:(BOOL)hideTerminated
{
    EC2DescribeInstancesRequest *request = [_instanceRequests objectForKey:awsRegion];
    
    if (!request)
        return NSNotFound;
    
    if (hideTerminated) {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            EC2Instance *instance = (EC2Instance *)evaluatedObject;
            return (instance.instanceState.code != EC2_INSTANCE_STATE_TERMINATED && instance.instanceState.code != EC2_INSTANCE_STATE_STOPPED);
        }];
        return [[request.response.instancesSet filteredArrayUsingPredicate:predicate] count];
    }
    else
        return [request.response.instancesSet count];
}

- (NSString *)instanceCountInRegionStringRepresentation:(NSString *)awsRegion hideTerminatedInstances:(BOOL)hideTerminated
{
    NSUInteger count = [self instanceCountInRegion:awsRegion hideTerminatedInstances:hideTerminated];
    
    if (count != NSNotFound)
        return count > 0 ? [NSString stringWithFormat:@"%zd", count] : @"";
    else
        return @"";
}

//- (NSArray *)statisticsForMetric:(NSString *)metric
//{
//	MonitoringGetMetricStatisticsRequest *monitoringRequest = [_compositeMonitoringRequests objectForKey:metric];
//	return monitoringRequest.response.result.datapoints;
//}

- (NSArray *)statisticsForMetric:(NSString *)metric forInstance:(NSString *)instanceId
{
	NSDictionary *instanceMonitoringRequests = [_instanceMonitoringRequests objectForKey:instanceId];
	MonitoringGetMetricStatisticsRequest *monitoringRequest = [instanceMonitoringRequests objectForKey:metric];
	return monitoringRequest.response.result.datapoints;
}

//- (CGFloat)maximumValueForMetric:(NSString *)metric forRange:(NSUInteger)range
//{
//	NSArray *stats = [self statisticsForMetric:metric];
//
//	if ([stats count] > 0) {
//		NSTimeInterval startTimestamp = [[NSDate date] timeIntervalSinceReferenceDate] - (NSTimeInterval)range;
//		__block CGFloat result = 0;
//
//		[stats enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//			MonitoringDatapoint *datapoint = (MonitoringDatapoint *)obj;
//			if (datapoint.timestamp > startTimestamp && datapoint.maximum > result) {
//				result = datapoint.maximum;
//			}
//		}];
//
//		return result;
//	}
//	else
//		return 0;
//}

//- (CGFloat)minimumValueForMetric:(NSString *)metric forRange:(NSUInteger)range
//{
//	NSArray *stats = [self statisticsForMetric:metric];
//
//	if ([stats count] > 0) {
//		NSTimeInterval startTimestamp = [[NSDate date] timeIntervalSinceReferenceDate] - (NSTimeInterval)range;
//		__block CGFloat result = MAXFLOAT;
//
//		[stats enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//			MonitoringDatapoint *datapoint = (MonitoringDatapoint *)obj;
//			if (datapoint.timestamp > startTimestamp && datapoint.minimum < result) {
//				result = datapoint.minimum;
//			}
//		}];
//
//		return result;
//	}
//	else
//		return 0;
//}

//- (CGFloat)averageValueForMetric:(NSString *)metric forRange:(NSUInteger)range
//{
//	NSArray *stats = [self statisticsForMetric:metric];
//
//	if ([stats count] > 0) {
//		NSTimeInterval startTimestamp = [[NSDate date] timeIntervalSinceReferenceDate] - (NSTimeInterval)range;
//		__block CGFloat sum = 0;
//		__block NSUInteger count = 0;
//
//		[stats enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//			MonitoringDatapoint *datapoint = (MonitoringDatapoint *)obj;
//			if (datapoint.timestamp > startTimestamp) {
//				sum += datapoint.average;
//				count++;
//			}
//		}];
//
//		return sum/count;
//	}
//	else
//		return 0;
//}

- (CGFloat)maximumValueForMetric:(NSString *)metric forInstance:(NSString *)instanceId forRange:(NSUInteger)range
{
	NSArray *stats = [self statisticsForMetric:metric forInstance:instanceId];

	if ([stats count] > 0) {
		NSTimeInterval startTimestamp = [[NSDate date] timeIntervalSinceReferenceDate] - (NSTimeInterval)range;
		__block CGFloat result = 0;

		[stats enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			MonitoringDatapoint *datapoint = (MonitoringDatapoint *)obj;
			if (datapoint.timestamp > startTimestamp && datapoint.maximum > result) {
				result = datapoint.maximum;
			}
		}];

		return result;
	}
	else
		return 0;
}

- (CGFloat)minimumValueForMetric:(NSString *)metric forInstance:(NSString *)instanceId forRange:(NSUInteger)range
{
	NSArray *stats = [self statisticsForMetric:metric forInstance:instanceId];

	if ([stats count] > 0) {
		NSTimeInterval startTimestamp = [[NSDate date] timeIntervalSinceReferenceDate] - (NSTimeInterval)range;
		// start above any real value; starting at 0 (as before) meant no datapoint could
		// ever be lower, so the minimum always came out as 0
		__block CGFloat result = CGFLOAT_MAX;

		[stats enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			MonitoringDatapoint *datapoint = (MonitoringDatapoint *)obj;
			if (datapoint.timestamp > startTimestamp && datapoint.minimum < result) {
				result = datapoint.minimum;
			}
		}];

		return result != CGFLOAT_MAX ? result : 0;   // 0 if no datapoint is in range
	}
	else
		return 0;
}

- (CGFloat)averageValueForMetric:(NSString *)metric forInstance:(NSString *)instanceId forRange:(NSUInteger)range
{
	NSArray *stats = [self statisticsForMetric:metric forInstance:instanceId];

	if ([stats count] > 0) {
		NSTimeInterval startTimestamp = [[NSDate date] timeIntervalSinceReferenceDate] - (NSTimeInterval)range;
		__block CGFloat sum = 0;
		__block NSUInteger count = 0;

		[stats enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			MonitoringDatapoint *datapoint = (MonitoringDatapoint *)obj;
			if (datapoint.timestamp > startTimestamp) {
				sum += datapoint.average;
				count++;
			}
		}];

		return count != 0 ? sum/count : 0;
	}
	else
		return 0;
}

@end
