//
//  AWSConstants.h
//  Elastics
//
//  Created by Dmitri Goutnik on 29/11/2010.
//  Copyright 2010 Tundra Bot. All rights reserved.
//

// AWS domain
extern NSString *const kAWSDomain;

// Default region
extern NSString *const kAWSUSEastRegion;

// Known regions (commercial "aws" partition plus AWS GovCloud (US)), in display order.
// Each region also has a stable preference index: the number Elastics stores as the
// selected region. Indices 0-7 are the values Elastics 1.x used and must not change;
// newer regions are appended with new indices.
NSArray *AWSRegions(void);                                  // region ids, e.g. @"us-east-1"
NSString *AWSRegionTitle(NSString *region);                 // e.g. @"US East (N. Virginia)", nil if unknown
NSInteger AWSRegionPreferenceIndex(NSString *region);       // NSNotFound if unknown
NSString *AWSRegionForPreferenceIndex(NSInteger index);     // nil if unknown

// Services
extern NSString *const kAWSEC2Service;
extern NSString *const kAWSMonitoringService;

// Parameters
extern NSString *const kAWSInstanceIdParameter;
extern NSString *const kAWSMetricNameParameter;
extern NSString *const kAWSStatisticsParameter;
extern NSString *const kAWSNamespaceParameter;
extern NSString *const kAWSStartTimeParameter;
extern NSString *const kAWSEndTimeParameter;
extern NSString *const kAWSPeriodParameter;

// Metrics
extern NSString *const kAWSCPUUtilizationMetric;
extern NSString *const kAWSDiskReadBytesMetric;
extern NSString *const kAWSDiskReadOpsMetric;
extern NSString *const kAWSDiskWriteBytesMetric;
extern NSString *const kAWSDiskWriteOpsMetric;
extern NSString *const kAWSNetworkInMetric;
extern NSString *const kAWSNetworkOutMetric;

// Supported metric statistics ranges
#define kAWSLastHourRange		3600U
#define kAWSLast3HoursRange		10800U
#define kAWSLast6HoursRange		21600U
#define kAWSLast12HoursRange	43200U
#define kAWSLast24HoursRange	86400U

// Errors
extern NSString *const kAWSErrorDomain;
