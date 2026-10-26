//
//  Preferences.h
//  ElasticsPreferences
//
//  Created by Dmitri Goutnik on 26/12/2010.
//  Copyright 2010 Tundra Bot. All rights reserved.
//

// Distributed notification sent when preferences are changed
extern NSString *const kPreferencesDidChangeNotification;

// Distributed notification sent when main application terminates
extern NSString *const kPreferencesShouldTerminateNotification;

// Terminal application types
enum {
	kPreferencesTerminalApplicationTerminal,
	kPreferencesTerminalApplicationiTerm,
};

// RDP application types
enum {
	kPreferencesRdpApplicationCoRD,
};

@interface NSUserDefaults (ElasticsPreferences)

- (NSDictionary *)defaultElasticsPreferences;

// Copies settings saved by Elastics 1.6 and earlier (com.tundrabot.Elastics and
// com.tundrabot.Elastics-Preferences) into this version's domains, once per domain,
// without overwriting anything already set. Safe to call from both apps.
+ (void)importLegacyElasticsPreferences;

// Selected account ID
@property (nonatomic, assign) NSInteger accountId;

// Selected region
@property (nonatomic, assign) NSInteger region;				// region preference index, see AWSRegionPreferenceIndex()
@property (nonatomic, readonly) NSString *awsRegion;		// translated as expected by AWS API

@property (nonatomic, assign) NSInteger refreshInterval;
@property (nonatomic, assign, getter=isRefreshOnMenuOpen) BOOL refreshOnMenuOpen;

@property (nonatomic, assign, getter=isSortInstancesByTitle) BOOL sortInstancesByTitle;
@property (nonatomic, assign, getter=isHideTerminatedInstances) BOOL hideTerminatedInstances;

@property (nonatomic, readonly) NSArray *activeRegions;       // active regions as preference indices (NSNumber), display order
@property (nonatomic, readonly) NSArray *activeAWSRegions;    // active regions as AWS region ids, display order
- (BOOL)isAWSRegionActive:(NSString *)awsRegion;
- (void)setAWSRegion:(NSString *)awsRegion active:(BOOL)active;

@property (nonatomic, assign) NSString *sshPrivateKeyFile;
@property (nonatomic, assign) NSString *sshUserName;
@property (nonatomic, assign) NSUInteger sshPort;
@property (nonatomic, assign) NSString *sshOptions;
@property (nonatomic, assign, getter=isUsingPublicDNS) BOOL usingPublicDNS;

@property (nonatomic, assign) NSInteger terminalApplication;
@property (nonatomic, assign, getter=isOpenInTerminalTab) BOOL openInTerminalTab;

@property (nonatomic, assign) NSInteger rdpApplication;

@property (nonatomic, assign, getter=isFirstLaunch) BOOL firstLaunch;

@end
