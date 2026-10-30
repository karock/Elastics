//
//  DemoData.h
//  Elastics
//
//  Made-up AWS responses for demo mode (screenshots without real account data).
//  Turn on with:   defaults write com.audiomack.Elastics-Preferences demoMode -bool YES
//  and off with:   defaults delete com.audiomack.Elastics-Preferences demoMode
//  then restart Elastics. See ElasticsIsDemoMode() in Constants.h.
//

#import <Foundation/Foundation.h>

// XML body AWS would return for this request, or nil if demo mode has nothing for it
// (the request then fails like a network error would).
NSData *ElasticsDemoResponseData(NSString *service, NSString *action, NSString *region, NSDictionary *parameters);
