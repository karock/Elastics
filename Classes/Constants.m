//
//  Constants.m
//  Elastics
//
//  Created by Dmitri Goutnik on 10/01/2011.
//  Copyright 2011 Tundra Bot. All rights reserved.
//

#import "Constants.h"

NSString *const kElasticsSecServiceName				= @"com.audiomack.Elastics";

NSString *const kElasticsBundleShortVersionString	= @"1.8";
NSString *const kElasticsBundleIdentifier			= @"com.audiomack.Elastics";
NSString *const kElasticsPreferencesBundleIdentifier	= @"com.audiomack.Elastics-Preferences";

NSString *const kElasticsLegacySecServiceName				= @"com.tundrabot.Elastics";
NSString *const kElasticsLegacyBundleIdentifier				= @"com.tundrabot.Elastics";
NSString *const kElasticsLegacyPreferencesBundleIdentifier	= @"com.tundrabot.Elastics-Preferences";

BOOL ElasticsIsDemoMode(void)
{
	static BOOL demoMode = NO;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		Boolean exists = false;
		Boolean value = CFPreferencesGetAppBooleanValue(CFSTR("demoMode"), (CFStringRef)kElasticsPreferencesBundleIdentifier, &exists);
		demoMode = exists && value;
		if (demoMode)
			NSLog(@"Elastics: demo mode - showing made-up data, not your AWS account or keychain");
	});
	return demoMode;
}
