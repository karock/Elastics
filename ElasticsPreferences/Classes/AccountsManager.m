//
//  AccountsManager.m
//  ElasticsPreferences
//
//  Created by Dmitri Goutnik on 26/07/2011.
//  Copyright 2011 Tundra Bot. All rights reserved.
//

#import "AccountsManager.h"
#import "Account.h"
#import "Constants.h"
#include <Security/Security.h>


@interface AccountsManager ()

- (Account *)findAccountWithKeychainItemRef:(SecKeychainItemRef)itemRef;
- (void)insertObject:(Account *)accont inAccountsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromAccountsAtIndex:(NSUInteger)idx;

@end


@implementation AccountsManager

@synthesize accounts = _accounts;

- (id)init
{
    self = [super init];
    if (self) {
        _accounts = [[NSMutableArray alloc] init];
		[self importLegacyAccountsIfNeeded];
		[self loadAccounts];

		// XXX >>
//		[self saveAccounts];
//		[self loadAccounts];
		// << XXX
    }
    return self;
}

- (void)dealloc
{
	TBRelease(_accounts);
	[super dealloc];
}

// Accounts stored in the keychain under the given service name, or nil if the
// keychain search itself failed.
- (NSMutableArray *)_accountsWithServiceName:(NSString *)serviceName
{
    const char *serviceNameUTF8 = [serviceName UTF8String];
	
	OSStatus status;
	SecKeychainItemRef itemRef = NULL;
    SecKeychainSearchRef searchRef = NULL;
	
    // set up the attribute vector for search (each attribute consists of {tag, length, data})
    SecKeychainAttribute attributes[] = {
        { kSecServiceItemAttr, (UInt32)strlen(serviceNameUTF8), (char *)serviceNameUTF8 },
    };
    SecKeychainAttributeList attributeList = {
        sizeof(attributes) / sizeof(attributes[0]), attributes
    };
    
    status = SecKeychainSearchCreateFromAttributes(NULL,
                                                   kSecGenericPasswordItemClass,
                                                   &attributeList,
                                                   &searchRef);
    if (status != noErr)
        return nil;

    NSMutableArray *accounts = [NSMutableArray array];

    while (1) {
        status = SecKeychainSearchCopyNext(searchRef, &itemRef);
        
        if (status == noErr) {
            // NOTE: for some reason unknown, SecKeychainSearchCopyNext sometimes returns the same item multiple times
            // HACK: to avoid adding duplicates, skip items we already have
            BOOL duplicate = NO;
            for (Account *account in accounts) {
                if (account.itemRef && CFEqual(account.itemRef, itemRef)) {
                    duplicate = YES;
                    break;
                }
            }
            if (!duplicate)
                [accounts addObject:[Account accountWithKeychainItemRef:itemRef]];
            
            TBCFRelease(itemRef);
        }
        else if (status == errSecItemNotFound) {
            break;
        }
        else {
            NSString *errorMessage = [NSMakeCollectable(SecCopyErrorMessageString(status, NULL)) autorelease];
            TBLog(@"error loading keychain item: %d, \"%@\"", status, errorMessage);
            break;
        }
    }
    
    TBCFRelease(searchRef);
    return accounts;
}

- (void)loadAccounts
{
    NSMutableArray *accounts = [self _accountsWithServiceName:kElasticsSecServiceName];
    if (accounts) {
        [_accounts removeAllObjects];
        [_accounts addObjectsFromArray:accounts];
    }
}

static NSString *const kAccountsImportedLegacyKey = @"importedLegacyAccounts";

// Elastics 1.6 and earlier stored accounts under the com.tundrabot.Elastics
// keychain service. Copy them, once, into new items under this version's service
// (whose access lists trust this app), keeping their IDs so the selected account
// carries over. The old items stay for the old app. Reading each old item makes
// macOS ask for permission, since its access list doesn't include this app.
// The "done" flag lives in the Preferences domain so both apps share it.
- (void)importLegacyAccountsIfNeeded
{
    CFStringRef domain = (CFStringRef)kElasticsPreferencesBundleIdentifier;
    Boolean flagExists = false;
    CFPreferencesGetAppBooleanValue((CFStringRef)kAccountsImportedLegacyKey, domain, &flagExists);
    if (flagExists)
        return;

    NSMutableArray *existing = [self _accountsWithServiceName:kElasticsSecServiceName];
    NSMutableArray *legacy = [self _accountsWithServiceName:kElasticsLegacySecServiceName];
    NSUInteger imported = 0;

    // only import into an empty list; if accounts were already set up here, keep them
    if (existing && [existing count] == 0) {
        for (Account *oldAccount in legacy) {
            if (![oldAccount.accessKeyID length] || ![oldAccount.secretAccessKey length])
                continue;   // access was denied or the item is incomplete

            Account *newAccount = [Account accountWithID:oldAccount.accountId
                                                    name:oldAccount.name
                                             accessKeyId:oldAccount.accessKeyID
                                         secretAccessKey:oldAccount.secretAccessKey
                                       sshPrivateKeyFile:oldAccount.sshPrivateKeyFile
                                             sshUserName:oldAccount.sshUserName
                                                 sshPort:oldAccount.sshPort
                                              sshOptions:oldAccount.sshOptions];
            newAccount.defaultRegion = oldAccount.defaultRegion;

            OSStatus status = [newAccount save];
            if (status == noErr)
                imported++;
            else
                TBLog(@"could not import account \"%@\": %d", oldAccount.title, status);
        }
        NSLog(@"Elastics: imported %lu of %lu accounts from the %@ keychain items",
              (unsigned long)imported, (unsigned long)[legacy count], kElasticsLegacySecServiceName);
    }

    // don't ask again on the next launch if some items couldn't be read (e.g. the
    // keychain prompt was denied): the accounts can be re-added in Preferences
    if (existing) {
        CFPreferencesSetAppValue((CFStringRef)kAccountsImportedLegacyKey, kCFBooleanTrue, domain);
        CFPreferencesAppSynchronize(domain);
    }
}

- (void)saveAccounts
{
	for (Account *account in _accounts) {
		[account save];
	}
}

- (OSStatus)addAccountWithName:(NSString *)name
                   accessKeyId:(NSString *)accessKeyId
               secretAccessKey:(NSString *)secretAccessKey
             sshPrivateKeyFile:(NSString *)sshPrivateKeyFile
                   sshUserName:(NSString *)sshUserName
                       sshPort:(NSUInteger)sshPort
                    sshOptions:(NSString *)sshOptions
{
	// make new account id to be max(existing IDs) + 1
	NSInteger __block maxAccountId = -1;
	[_accounts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		Account *account = (Account *)obj;
		maxAccountId = MAX(account.accountId, maxAccountId);
	}];
	NSInteger newAccountId = maxAccountId + 1;
	
	Account *newAccount = [Account accountWithID:newAccountId
											name:name
									 accessKeyId:accessKeyId
								 secretAccessKey:secretAccessKey
							   sshPrivateKeyFile:sshPrivateKeyFile
									 sshUserName:sshUserName
                                         sshPort:sshPort
                                      sshOptions:sshOptions];
    
    OSStatus status = [newAccount save];

    if (status == noErr)
        [self insertObject:newAccount inAccountsAtIndex:[_accounts count]];
    
    return status;
}

- (OSStatus)updateAccountAtIndex:(NSUInteger)idx
                        withName:(NSString *)name
                     accessKeyId:(NSString *)accessKeyId
                 secretAccessKey:(NSString *)secretAccessKey
               sshPrivateKeyFile:(NSString *)sshPrivateKeyFile
                     sshUserName:(NSString *)sshUserName
                         sshPort:(NSUInteger)sshPort
                      sshOptions:(NSString *)sshOptions
{
    Account *account = [_accounts objectAtIndex:idx];
    
    // keep old values for undo (TODO: is there a better way?)
    NSString *nameCopy = [account.name copy];
    NSString *accessKeyIDCopy = [account.accessKeyID copy];
    NSString *secretAccessKeyCopy = [account.secretAccessKey copy];
    NSString *sshPrivateKeyFileCopy = [account.sshPrivateKeyFile copy];
    NSString *sshUserNameCopy = [account.sshUserName copy];
    NSUInteger sshPortCopy = account.sshPort;
    NSString *sshOptionsCopy = [account.sshOptions copy];

    account.name = name;
    account.accessKeyID = accessKeyId;
    account.secretAccessKey = secretAccessKey;
    account.sshPrivateKeyFile = sshPrivateKeyFile;
    account.sshUserName = sshUserName;
    account.sshPort = sshPort;
    account.sshOptions = sshOptions;

    OSStatus status = [account save];
    
    if (status != noErr) {
        // save failed, restore old values
        account.name = nameCopy;
        account.accessKeyID = accessKeyIDCopy;
        account.secretAccessKey = secretAccessKeyCopy;
        account.sshPrivateKeyFile = sshPrivateKeyFileCopy;
        account.sshUserName = sshUserNameCopy;
        account.sshPort = sshPortCopy;
        account.sshOptions = sshOptionsCopy;
    }
    
    [nameCopy release];
    [accessKeyIDCopy release];
    [secretAccessKeyCopy release];
    [sshPrivateKeyFileCopy release];
    [sshUserNameCopy release];
    [sshOptionsCopy release];

    return status;
}

- (void)removeAccountAtIndex:(NSUInteger)idx
{
	[self removeObjectFromAccountsAtIndex:idx];
}

- (Account *)accountWithId:(NSInteger)anId
{
	__block Account *result = nil;
	
	[_accounts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		Account *account = (Account *)obj;
		if (account.accountId == anId) {
			result = account;
			*stop = YES;
		}
	}];
	
	return result;
}


- (Account *)findAccountWithKeychainItemRef:(SecKeychainItemRef)itemRef
{
	__block Account *result = nil;
	
	[_accounts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		Account *account = (Account *)obj;
		if (account.itemRef == itemRef) {
			result = account;
			*stop = YES;
		}
	}];
	
	return result;
}

#pragma mark -
#pragma mark KVC magic methods

- (void)insertObject:(Account *)accont inAccountsAtIndex:(NSUInteger)idx
{
	[_accounts insertObject:accont atIndex:idx];
}

- (void)removeObjectFromAccountsAtIndex:(NSUInteger)idx
{
	Account *account = [_accounts objectAtIndex:idx];
	[account remove];
	
	[_accounts removeObjectAtIndex:idx];
}

@end
