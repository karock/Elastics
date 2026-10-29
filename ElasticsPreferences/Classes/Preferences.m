//
//  Preferences.m
//  ElasticsPreferences
//
//  Created by Dmitri Goutnik on 26/12/2010.
//  Copyright 2010 Tundra Bot. All rights reserved.
//

#import "Preferences.h"
#import "AWSConstants.h"
#import "Constants.h"

// Distributed notification sent when preferences are changed
NSString *const kPreferencesDidChangeNotification       = @"com.audiomack.Elastics.PreferencesDidChangeNotification";

// Distributed notification sent when main application terminates
NSString *const kPreferencesShouldTerminateNotification = @"com.audiomack.Elastics.PreferencesShouldTerminateNotification";

// Preference dictionary keys
static NSString *const kPreferencesAccountIdKey                             = @"accountId";
static NSString *const kPreferencesAWSRegionKey                             = @"awsRegion";
static NSString *const kPreferencesRefreshIntervalKey                       = @"refreshInterval";
static NSString *const kPreferencesRefreshOnMenuOpenKey                     = @"refreshOnMenuOpen";
static NSString *const kPreferencesSortInstancesByTitleKey                  = @"sortInstancesByTitle";
static NSString *const kPreferencesHideTerminatedInstancesKey               = @"hideTerminatedInstances";
// Per-region "active" flags. Elastics 1.x stored these under the names below for its
// original eight regions; keep using them so existing settings carry over. Regions
// added later use "regionActive-<region id>" and default to inactive.
static NSDictionary *PreferencesLegacyRegionActiveKeys(void)
{
    static NSDictionary *keys = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = [[NSDictionary alloc] initWithObjectsAndKeys:
                @"regionUSEastActive",                  @"us-east-1",
                @"regionUSWestNorthCaliforniaActive",   @"us-west-1",
                @"regionUSWestOregonActive",            @"us-west-2",
                @"regionEUActive",                      @"eu-west-1",
                @"regionAsiaPacificSingaporeActive",    @"ap-southeast-1",
                @"regionAsiaPacificJapanActive",        @"ap-northeast-1",
                @"regionSouthAmericaSaoPauloActive",    @"sa-east-1",
                @"regionUSGovCloudActive",              @"us-gov-west-1",
                nil];
    });
    return keys;
}

static NSString *PreferencesRegionActiveKey(NSString *awsRegion)
{
    NSString *legacyKey = [PreferencesLegacyRegionActiveKeys() objectForKey:awsRegion];
    return legacyKey ? legacyKey : [@"regionActive-" stringByAppendingString:awsRegion];
}

static NSString *const kPreferencesGroupingModeKey                          = @"groupingMode";
static NSString *const kPreferencesGroupingNamePrefixesKey                  = @"groupingNamePrefixes";
static NSString *const kPreferencesGroupingTagKeyKey                        = @"groupingTagKey";
static NSString *const kPreferencesGroupStoppedInstancesKey                 = @"groupStoppedInstances";
static NSString *const kPreferencesGroupTerminatedInstancesKey              = @"groupTerminatedInstances";
static NSString *const kPreferencesSshPrivateKeyFileKey                     = @"sshPrivateKeyFile";
static NSString *const kPreferencesSshUserNameKey                           = @"sshUserName";
static NSString *const kPreferencesSshPortKey                               = @"sshPort";
static NSString *const kPreferencesSshOptionsKey                            = @"sshOptions";
static NSString *const kPreferencesUsingPublicDNSKey                        = @"sshUsingPublicDNS";
static NSString *const kPreferencesTerminalApplicationKey                   = @"terminalApplication";
static NSString *const kPreferencesOpenInTerminalTabKey                     = @"openInTerminalTab";
static NSString *const kPreferencesRdpApplicationKey                        = @"rdpApplication";
static NSString *const kPreferencesFirstLaunchKey                           = @"firstLaunch";

@implementation NSUserDefaults (ElasticsPreferences)

static NSString *const kPreferencesImportedLegacyKey = @"importedLegacyPreferences";

static void PreferencesImportLegacyDomain(NSString *legacyDomain, NSString *domain)
{
    CFStringRef domainRef = (CFStringRef)domain;

    // already done (or nothing to do) for this domain
    Boolean flagExists = false;
    CFPreferencesGetAppBooleanValue((CFStringRef)kPreferencesImportedLegacyKey, domainRef, &flagExists);
    if (flagExists)
        return;

    CFArrayRef keys = CFPreferencesCopyKeyList((CFStringRef)legacyDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (keys) {
        CFDictionaryRef values = CFPreferencesCopyMultiple(keys, (CFStringRef)legacyDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (values) {
            NSUInteger imported = 0;
            for (NSString *key in (NSDictionary *)values) {
                CFPropertyListRef existing = CFPreferencesCopyAppValue((CFStringRef)key, domainRef);
                if (existing) {
                    CFRelease(existing);   // never overwrite a setting made in this version
                    continue;
                }
                CFPreferencesSetAppValue((CFStringRef)key, CFDictionaryGetValue(values, key), domainRef);
                imported++;
            }
            NSLog(@"Elastics: imported %lu settings from %@ into %@", (unsigned long)imported, legacyDomain, domain);
            CFRelease(values);
        }
        CFRelease(keys);
    }

    CFPreferencesSetAppValue((CFStringRef)kPreferencesImportedLegacyKey, kCFBooleanTrue, domainRef);
    CFPreferencesAppSynchronize(domainRef);
}

+ (void)importLegacyElasticsPreferences
{
    PreferencesImportLegacyDomain(kElasticsLegacyBundleIdentifier, kElasticsBundleIdentifier);
    PreferencesImportLegacyDomain(kElasticsLegacyPreferencesBundleIdentifier, kElasticsPreferencesBundleIdentifier);
}

- (NSDictionary *)defaultElasticsPreferences
{
    static NSDictionary *s_defaults;
    
	if (!s_defaults) {
		NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      [NSNumber numberWithInteger:AWSRegionPreferenceIndex(kAWSUSEastRegion)], kPreferencesAWSRegionKey,
                      [NSNumber numberWithFloat:180], kPreferencesRefreshIntervalKey,
                      [NSNumber numberWithBool:YES], kPreferencesRefreshOnMenuOpenKey,
                      [NSNumber numberWithBool:NO], kPreferencesSortInstancesByTitleKey,
                      [NSNumber numberWithBool:NO], kPreferencesHideTerminatedInstancesKey,
                      [NSNumber numberWithBool:NO], kPreferencesUsingPublicDNSKey,
                      [NSNumber numberWithBool:YES], kPreferencesFirstLaunchKey,
                      [NSNumber numberWithInteger:kPreferencesGroupingNone], kPreferencesGroupingModeKey,
                      [NSNumber numberWithBool:NO], kPreferencesGroupStoppedInstancesKey,
                      [NSNumber numberWithBool:NO], kPreferencesGroupTerminatedInstancesKey,
                      nil];

        // the original eight regions default to active (as in Elastics 1.x), newer ones to inactive
        for (NSString *awsRegion in AWSRegions()) {
            BOOL isLegacyRegion = [PreferencesLegacyRegionActiveKeys() objectForKey:awsRegion] != nil;
            [defaults setObject:[NSNumber numberWithBool:isLegacyRegion] forKey:PreferencesRegionActiveKey(awsRegion)];
        }

        s_defaults = [defaults copy];
	}
	return s_defaults;
}

- (NSInteger)accountId
{
	return [self integerForKey:kPreferencesAccountIdKey];
}

- (void)setAccountId:(NSInteger)value
{
	[self setInteger:value forKey:kPreferencesAccountIdKey];
}

- (NSInteger)region
{
	NSInteger region = [self integerForKey:kPreferencesAWSRegionKey];
    NSArray *activeRegions = self.activeRegions;
    
    // if currently selected default region was turned off, choose first active region as default
    if (![activeRegions containsObject:[NSNumber numberWithInteger:region]]) {
        region = [activeRegions count] > 0 ? [[activeRegions objectAtIndex:0] integerValue] : AWSRegionPreferenceIndex(kAWSUSEastRegion);
        self.region = region;
    }
    
    return region;
}

- (void)setRegion:(NSInteger)region
{
	[self setInteger:region forKey:kPreferencesAWSRegionKey];
}

- (NSString *)awsRegion
{
	return AWSRegionForPreferenceIndex(self.region);
}

//- (void)setAwsRegion:(NSString *)value
//{
//	NSInteger region = kPreferencesAWSUSEastRegion;
//	
//	if ([value isEqualToString:kAWSUSEastRegion])
//		region = kPreferencesAWSUSEastRegion;
//	else if ([value isEqualToString:kAWSUSWestRegion])
//		region = kPreferencesAWSUSWestRegion;
//	else if ([value isEqualToString:kAWSEURegion])
//		region = kPreferencesAWSEURegion;
//	else if ([value isEqualToString:kAWSAsiaPacificSingaporeRegion])
//		region = kPreferencesAWSAsiaPacificSingaporeRegion;
//	
//	[self setInteger:region forKey:kPreferencesAWSRegionKey];
//}

- (NSInteger)refreshInterval
{
	return [self integerForKey:kPreferencesRefreshIntervalKey];
}

- (void)setRefreshInterval:(NSInteger)value
{
	[self setInteger:value forKey:kPreferencesRefreshIntervalKey];
}

- (BOOL)isRefreshOnMenuOpen
{
	return [self boolForKey:kPreferencesRefreshOnMenuOpenKey];
}

- (void)setRefreshOnMenuOpen:(BOOL)value
{
	[self setBool:value forKey:kPreferencesRefreshOnMenuOpenKey];
}

- (BOOL)isSortInstancesByTitle
{
	return [self boolForKey:kPreferencesSortInstancesByTitleKey];
}

- (void)setSortInstancesByTitle:(BOOL)value
{
	[self setBool:value forKey:kPreferencesSortInstancesByTitleKey];
}

- (BOOL)isHideTerminatedInstances
{
	return [self boolForKey:kPreferencesHideTerminatedInstancesKey];
}

- (void)setHideTerminatedInstances:(BOOL)value
{
	[self setBool:value forKey:kPreferencesHideTerminatedInstancesKey];
}

- (BOOL)isAWSRegionActive:(NSString *)awsRegion
{
    return [self boolForKey:PreferencesRegionActiveKey(awsRegion)];
}

- (void)setAWSRegion:(NSString *)awsRegion active:(BOOL)active
{
    [self setBool:active forKey:PreferencesRegionActiveKey(awsRegion)];
}

- (NSArray *)activeAWSRegions
{
    NSMutableArray *result = [NSMutableArray array];

    for (NSString *awsRegion in AWSRegions()) {
        if ([self isAWSRegionActive:awsRegion])
            [result addObject:awsRegion];
    }

    return result;
}

- (NSArray *)activeRegions
{
    NSMutableArray *result = [NSMutableArray array];

    for (NSString *awsRegion in self.activeAWSRegions) {
        [result addObject:[NSNumber numberWithInteger:AWSRegionPreferenceIndex(awsRegion)]];
    }

    return result;
}

- (NSInteger)groupingMode
{
	return [self integerForKey:kPreferencesGroupingModeKey];
}

- (void)setGroupingMode:(NSInteger)value
{
	[self setInteger:value forKey:kPreferencesGroupingModeKey];
}

- (NSString *)groupingNamePrefixes
{
	return [self stringForKey:kPreferencesGroupingNamePrefixesKey];
}

- (void)setGroupingNamePrefixes:(NSString *)value
{
	[self setObject:value forKey:kPreferencesGroupingNamePrefixesKey];
}

- (NSString *)groupingTagKey
{
	return [self stringForKey:kPreferencesGroupingTagKeyKey];
}

- (void)setGroupingTagKey:(NSString *)value
{
	[self setObject:value forKey:kPreferencesGroupingTagKeyKey];
}

- (BOOL)isGroupStoppedInstances
{
	return [self boolForKey:kPreferencesGroupStoppedInstancesKey];
}

- (void)setGroupStoppedInstances:(BOOL)value
{
	[self setBool:value forKey:kPreferencesGroupStoppedInstancesKey];
}

- (BOOL)isGroupTerminatedInstances
{
	return [self boolForKey:kPreferencesGroupTerminatedInstancesKey];
}

- (void)setGroupTerminatedInstances:(BOOL)value
{
	[self setBool:value forKey:kPreferencesGroupTerminatedInstancesKey];
}

- (NSString *)sshPrivateKeyFile
{
	return [self stringForKey:kPreferencesSshPrivateKeyFileKey];
}

- (void)setSshPrivateKeyFile:(NSString *)value
{
	[self setObject:value forKey:kPreferencesSshPrivateKeyFileKey];
}

- (NSString *)sshUserName
{
	return [self stringForKey:kPreferencesSshUserNameKey];
}

- (void)setSshUserName:(NSString *)value
{
	[self setObject:value forKey:kPreferencesSshUserNameKey];
}

- (NSUInteger)sshPort
{
    return [self integerForKey:kPreferencesSshPortKey];
}

- (void)setSshPort:(NSUInteger)value
{
    [self setInteger:value forKey:kPreferencesSshPortKey];
}

- (NSString *)sshOptions
{
    return [self stringForKey:kPreferencesSshOptionsKey];
}

- (void)setSshOptions:(NSString *)value
{
    if (![self.sshOptions isEqualToString:value])
        [self setObject:value forKey:kPreferencesSshOptionsKey];
}

- (BOOL)isUsingPublicDNS
{
	return [self boolForKey:kPreferencesUsingPublicDNSKey];
}

- (void)setUsingPublicDNS:(BOOL)value
{
	[self setBool:value forKey:kPreferencesUsingPublicDNSKey];
}

- (NSInteger)terminalApplication
{
	return [self integerForKey:kPreferencesTerminalApplicationKey];
}

- (void)setTerminalApplication:(NSInteger)value
{
	[self setInteger:value forKey:kPreferencesTerminalApplicationKey];
}

- (BOOL)isOpenInTerminalTab
{
	return [self boolForKey:kPreferencesOpenInTerminalTabKey];
}

- (void)setOpenInTerminalTab:(BOOL)value
{
	[self setBool:value forKey:kPreferencesOpenInTerminalTabKey];
}

- (NSInteger)rdpApplication
{
	return [self integerForKey:kPreferencesRdpApplicationKey];
}

- (void)setRdpApplication:(NSInteger)value
{
	[self setInteger:value forKey:kPreferencesRdpApplicationKey];
}

- (BOOL)isFirstLaunch
{
	return [self boolForKey:kPreferencesFirstLaunchKey];
}

- (void)setFirstLaunch:(BOOL)value
{
	[self setBool:value forKey:kPreferencesFirstLaunchKey];
}

@end
