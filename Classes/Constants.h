//
//  Constants.h
//  Elastics
//
//  Created by Dmitri Goutnik on 10/01/2011.
//  Copyright 2011 Tundra Bot. All rights reserved.
//

// Keychain API service name
extern NSString *const kElasticsSecServiceName;

// Hardcoded bundle values
extern NSString *const kElasticsBundleShortVersionString;
extern NSString *const kElasticsBundleIdentifier;
extern NSString *const kElasticsPreferencesBundleIdentifier;

// Identifiers used by Elastics 1.6 and earlier (Tundra Bot). Settings and keychain
// items stored under them are imported once, then left alone for the old app.
extern NSString *const kElasticsLegacySecServiceName;
extern NSString *const kElasticsLegacyBundleIdentifier;
extern NSString *const kElasticsLegacyPreferencesBundleIdentifier;
