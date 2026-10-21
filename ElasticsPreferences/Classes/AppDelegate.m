//
//  AppDelegate.m
//  ElasticsPreferences
//
//  Created by Dmitri Goutnik on 26/12/2010.
//  Copyright 2010 Tundra Bot. All rights reserved.
//

#import "AppDelegate.h"
#import "Preferences.h"
#import "RefreshIntervalValueTransformer.h"
#import "RefreshIntervalLabelValueTransformer.h"
#import "SshPortValueTransformer.h"
#import "Account.h"
#import "AWSConstants.h"

enum {
    kGeneralPaneIndex,
    kRegionsPaneIndex,
    kConnectionsPaneIndex,
};

#define PANE_SWITCH_ANIMATION_DURATION	0.25

// The original author's site (tundrabot.com) is gone; link to the original repository,
// and send feedback about this unofficial build to its fork, not to the original author.
static NSString *const kElasticsWebsiteURL      = @"https://github.com/tundrabot/Elastics";
static NSString *const kElasticsSendFeedbackURL = @"https://github.com/karock/Elastics/issues";

@interface AppDelegate ()

@property (nonatomic, copy) NSString *lastValidSshPortValue;

- (void)schedulePreferenceChangeNotification;
- (void)postPreferenceChangeNotification;
- (void)userDefaultsDidChange:(NSNotification *)notification;
- (void)accountDidChange:(NSNotification *)notification;
- (void)showPreferencePane:(NSUInteger)paneIndex animated:(BOOL)animated;
- (void)addContentSubview:(NSView *)view;
- (void)preferencesShouldTerminate:(NSNotification *)notification;
- (void)buildRegionsPane;
- (void)updateRegionCheckboxes;
- (void)regionCheckboxAction:(id)sender;

- (NSString *)_accountPanelNameValue;
- (NSString *)_accountPanelAccessKeyIDValue;
- (NSString *)_accountPanelSecretAccessKeyValue;
- (NSString *)_accountPanelSshPrivateKeyFileValue;
- (NSString *)_accountPanelSshUserNameValue;
- (NSUInteger)_accountPanelSshPortValue;
- (NSString *)_accountPanelSshOptionsValue;

@end


@implementation AppDelegate {
    NSMutableArray *_regionCheckboxes;
}

@synthesize window = _window;
@synthesize generalPane = _generalPane;
@synthesize regionsPane = _regionsPane;
@synthesize connectionsPane = _connectionsPane;
@synthesize accountsManager = _accountsManager;
@synthesize accountsController = _accountsController;
@synthesize accountsTableView = _accountsTableView;
@synthesize sshPortField = _sshPortField;
@synthesize aboutPanel = _aboutPanel;
@synthesize aboutVersionLabel = _aboutVersionLabel;
@synthesize aboutCopyrightLabel = _aboutCopyrightLabel;
@synthesize accountPanel = _accountPanel;
@synthesize accountPanelSaveButton = _accountPanelSaveButton;
@synthesize accountPanelNameField = _accountPanelNameField;
@synthesize accountPanelAccessKeyIdField = _accountPanelAccessKeyIdField;
@synthesize accountPanelSecretAccessKeyField = _accountPanelSecretAccessKeyField;
@synthesize accountPanelSshPrivateKeyFileField = _accountPanelSshPrivateKeyFileField;
@synthesize accountPanelSshUserNameField = _accountPanelSshUserNameField;
@synthesize accountPanelSshPortField = _accountPanelSshPortField;
@synthesize accountPanelSshOptionsField = _accountPanelSshOptionsField;
@synthesize lastValidSshPortValue = _lastValidSshPortValue;

@synthesize regionUSEastEnabled = _regionUSEastEnabled;
@synthesize regionUSWestNorthCaliforniaEnabled = _regionUSWestNorthCaliforniaEnabled;
@synthesize regionUSWestOregonEnabled = _regionUSWestOregonEnabled;
@synthesize regionEUEnabled = _regionEUEnabled;
@synthesize regionAsiaPacificSingaporeEnabled = _regionAsiaPacificSingaporeEnabled;
@synthesize regionAsiaPacificJapanEnabled = _regionAsiaPacificJapanEnabled;
@synthesize regionSouthAmericaSaoPauloEnabled = _regionSouthAmericaSaoPauloEnabled;
@synthesize regionUSGovCloudEnabled = _regionUSGovCloudEnabled;

#pragma mark - Initialization

+ (void)initialize
{
    // register value transformers
	RefreshIntervalValueTransformer *valueTransformer = [[[RefreshIntervalValueTransformer alloc] init] autorelease];
	RefreshIntervalLabelValueTransformer *labelValueTransformer = [[[RefreshIntervalLabelValueTransformer alloc] init] autorelease];
    SshPortValueTransformer *sshPortTransformer = [[[SshPortValueTransformer alloc] init] autorelease];
	
	[NSValueTransformer setValueTransformer:valueTransformer
									forName:@"RefreshIntervalValueTransformer"];
	[NSValueTransformer setValueTransformer:labelValueTransformer
									forName:@"RefreshIntervalLabelValueTransformer"];
	[NSValueTransformer setValueTransformer:sshPortTransformer
									forName:@"SshPortValueTransformer"];
	
	// register default preference values
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults registerDefaults:[userDefaults defaultElasticsPreferences]];
}

- (void)dealloc
{
    [_lastValidSshPortValue release];
    [_regionCheckboxes release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	// center window on the first launch
	if (userDefaults.isFirstLaunch)
		[_window center];
	
	// show General pane on launch
	[_accountsTableView setTarget:self];
	[_accountsTableView	setDoubleAction:@selector(editAccountAction:)];
	[self buildRegionsPane];
	[self showPreferencePane:kGeneralPaneIndex animated:NO];
	
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

	// observe user defaults change notifications
	[notificationCenter addObserver:self
						   selector:@selector(userDefaultsDidChange:)
							   name:NSUserDefaultsDidChangeNotification
							 object:nil];

	// observe accounts change notifications
	[notificationCenter addObserver:self
						   selector:@selector(accountDidChange:)
							   name:kAccountDidChangeNotification
							 object:nil];
	
	// observe termination notification from main app
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
														selector:@selector(preferencesShouldTerminate:)
															name:kPreferencesShouldTerminateNotification
														  object:nil];

	userDefaults.firstLaunch = NO;
    
	// show main window
	[_window makeKeyAndOrderFront:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	// unsubscribe from notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self
															   name:kPreferencesShouldTerminateNotification
															 object:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}

- (void)showPreferencePane:(NSUInteger)paneIndex animated:(BOOL)animated
{
	NSView *pane = nil;

	switch (paneIndex) {
		case kGeneralPaneIndex:
			pane = _generalPane;
			break;
		case kRegionsPaneIndex:
			pane = _regionsPane;
			break;
		case kConnectionsPaneIndex:
			pane = _connectionsPane;
			break;
	}
	
	if (pane) {
		NSView *contentView = [_window contentView];
		NSView *currentPane = [[contentView subviews] count] ? [[contentView subviews] objectAtIndex:0] : nil;
	
		if (pane != currentPane) {
			// cancel all pending 'show pane' requests
			[NSObject cancelPreviousPerformRequestsWithTarget:self];
			
			// make toolbar button selected
			NSToolbar *toolbar = [_window toolbar];
			NSToolbarItem *toolbarItem = [[toolbar items] objectAtIndex:paneIndex];
			[toolbar setSelectedItemIdentifier:[toolbarItem itemIdentifier]];
			
			// calculate new window frame
			NSRect contentBounds = [contentView bounds];
			NSRect paneBounds = [pane bounds];
			NSRect currentWindowFrame = [_window frame];
			NSRect newWindowFrame = NSMakeRect(currentWindowFrame.origin.x,
											   currentWindowFrame.origin.y - (paneBounds.size.height - contentBounds.size.height),
											   currentWindowFrame.size.width + (paneBounds.size.width - contentBounds.size.width),
											   currentWindowFrame.size.height + (paneBounds.size.height - contentBounds.size.height));
			
			// resize window and replace panes
			[currentPane removeFromSuperview];
			if (animated) {
				[NSAnimationContext beginGrouping]; {
					[[NSAnimationContext currentContext] setDuration:PANE_SWITCH_ANIMATION_DURATION];
					[[_window animator] setFrame:newWindowFrame display:YES];
				} [NSAnimationContext endGrouping];
				[self performSelector:@selector(addContentSubview:) withObject:pane afterDelay:PANE_SWITCH_ANIMATION_DURATION + 0.05];
			}
			else {
				[_window setFrame:newWindowFrame display:YES];
				[self addContentSubview:pane];
			}
		}
	}
}

- (void)addContentSubview:(NSView *)view
{
	NSView *contentView = [_window contentView];
	[view setFrameOrigin:NSMakePoint(0.f, 0.f)];
	[contentView addSubview:view];
}


#pragma mark -
#pragma mark Toolbar delegate

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	NSMutableArray *selectableItemIdentifiers = [NSMutableArray array];
	
	for (NSToolbarItem *item in [toolbar items]) {
		[selectableItemIdentifiers addObject:[item itemIdentifier]];
	}
	
	return selectableItemIdentifiers;
}


#pragma mark -
#pragma mark Window delegate

- (void)windowWillClose:(NSNotification *)notification
{
	[_window makeFirstResponder:[_window contentView]];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - NSTextField notifications

- (void)controlTextDidBeginEditing:(NSNotification *)notification
{
    if ([[notification object] isKindOfClass:[NSTextField class]]) {
        NSTextField *obj = [notification object];
        
        if (obj == _sshPortField || obj == _accountPanelSshPortField) {
            self.lastValidSshPortValue = [obj stringValue];
        }
    }
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if ([[notification object] isKindOfClass:[NSTextField class]]) {
        NSTextField *obj = [notification object];
        
        if (obj == _accountPanelAccessKeyIdField || obj == _accountPanelSecretAccessKeyField) {
            BOOL canSave = [[self _accountPanelAccessKeyIDValue] length] > 0 && [[self _accountPanelSecretAccessKeyValue] length] > 0;
            [_accountPanelSaveButton setEnabled:canSave];
        }
        else if (obj == _sshPortField || obj == _accountPanelSshPortField) {
            NSString *value = obj.stringValue;
            NSPredicate *portPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"[\\d]{0,5}"];
            if (![portPredicate evaluateWithObject:value]) {
                [obj setStringValue:_lastValidSshPortValue ? _lastValidSshPortValue : @""];
                NSBeep();
            }
            else {
                self.lastValidSshPortValue = obj.stringValue;
            }
        }
    }
}


#pragma mark -
#pragma mark Preference data changes notifications

const NSTimeInterval kPreferenceChangeNotificationDelay = .5;

- (void)schedulePreferenceChangeNotification
{
	[[self class] cancelPreviousPerformRequestsWithTarget:self
												 selector:@selector(postPreferenceChangeNotification)
												   object:nil];
	[self performSelector:@selector(postPreferenceChangeNotification)
			   withObject:nil
			   afterDelay:kPreferenceChangeNotificationDelay];
}

- (void)postPreferenceChangeNotification
{
	[[NSUserDefaults standardUserDefaults] synchronize];
//	[_keychainController saveAccounts];
	
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:kPreferencesDidChangeNotification
                                                                   object:nil
                                                                 userInfo:nil
                                                       deliverImmediately:YES];
}

- (void)userDefaultsDidChange:(NSNotification *)notification
{
	[self schedulePreferenceChangeNotification];
}

- (void)accountDidChange:(NSNotification *)notification
{
	[self schedulePreferenceChangeNotification];
}


#pragma mark -
#pragma mark Main app notifications

- (void)preferencesShouldTerminate:(NSNotification *)notification
{
	[NSApp terminate:nil];
}


#pragma mark -
#pragma mark Accounts sheet

#define ACCOUNT_SHEET_RETURNCODE_SAVE		1
#define ACCOUNT_SHEET_RETURNCODE_CANCEL		0

enum {
	kAccountActionAddAccount = 1000,
	kAccountActionEditAccount,
};

- (NSString *)_accountPanelNameValue
{
	return [[_accountPanelNameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)_accountPanelAccessKeyIDValue
{
	return [[_accountPanelAccessKeyIdField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)_accountPanelSecretAccessKeyValue
{
	return [[_accountPanelSecretAccessKeyField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)_accountPanelSshPrivateKeyFileValue
{
	return [[_accountPanelSshPrivateKeyFileField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)_accountPanelSshUserNameValue
{
	return [[_accountPanelSshUserNameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSUInteger)_accountPanelSshPortValue
{
    return [_accountPanelSshPortField integerValue];
}

- (NSString *)_accountPanelSshOptionsValue
{
	return [[_accountPanelSshOptionsField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (IBAction)accountSheetSaveAction:(id)sender
{
	[NSApp endSheet:_accountPanel returnCode:ACCOUNT_SHEET_RETURNCODE_SAVE];
}

- (IBAction)accountSheetCancelAction:(id)sender
{
	[NSApp endSheet:_accountPanel returnCode:ACCOUNT_SHEET_RETURNCODE_CANCEL];
}

- (void)accountSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[_accountPanel orderOut:self];
    
	if (returnCode == ACCOUNT_SHEET_RETURNCODE_SAVE) {

        OSStatus status = noErr;
        
		switch (_accountActionType) {
			case kAccountActionAddAccount: {
				status = [_accountsManager addAccountWithName:[self _accountPanelNameValue]
                                                  accessKeyId:[self _accountPanelAccessKeyIDValue]
                                              secretAccessKey:[self _accountPanelSecretAccessKeyValue]
                                            sshPrivateKeyFile:[self _accountPanelSshPrivateKeyFileValue]
                                                  sshUserName:[self _accountPanelSshUserNameValue]
                                                      sshPort:[self _accountPanelSshPortValue]
                                                   sshOptions:[self _accountPanelSshOptionsValue]];
				break;
			}
				
			case kAccountActionEditAccount: {
				NSUInteger selectionIndex = [_accountsController selectionIndex];

				if (selectionIndex != NSNotFound) {
                    status = [_accountsManager updateAccountAtIndex:selectionIndex
                                                           withName:[self _accountPanelNameValue]
                                                        accessKeyId:[self _accountPanelAccessKeyIDValue]
                                                    secretAccessKey:[self _accountPanelSecretAccessKeyValue]
                                                  sshPrivateKeyFile:[self _accountPanelSshPrivateKeyFileValue]
                                                        sshUserName:[self _accountPanelSshUserNameValue]
                                                            sshPort:[self _accountPanelSshPortValue]
                                                         sshOptions:[self _accountPanelSshOptionsValue]];
				}
				break;
			}
		}
        
        if (status != noErr) {
            NSString *errorTitle = nil;
            NSString *errorText = nil;
            
            switch (_accountActionType) {
                case kAccountActionAddAccount:
                    errorTitle = @"Error adding account";
                    break;
                case kAccountActionEditAccount:
                    errorTitle = @"Error editing account";
                    break;
            }
            
            errorText = [NSMakeCollectable(SecCopyErrorMessageString(status, NULL)) autorelease];

            NSAlert *alert = [NSAlert alertWithMessageText:errorTitle
                                             defaultButton:@"Dismiss"
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:errorText];
            
            [alert beginSheetModalForWindow:[NSApp mainWindow]
                              modalDelegate:nil
                             didEndSelector:nil
                                contextInfo:NULL];
        }
	}
}

- (IBAction)addAccountAction:(id)sender
{
	_accountActionType = kAccountActionAddAccount;
	
	NSString *defaultSshPrivateKeyFile = [[NSUserDefaults standardUserDefaults] sshPrivateKeyFile];
	NSString *defaultSshUserName = [[NSUserDefaults standardUserDefaults] sshUserName];
    NSUInteger defaultSshPort = [[NSUserDefaults standardUserDefaults] sshPort];
	NSString *defaultSshOptions = [[NSUserDefaults standardUserDefaults] sshOptions];

	[_accountPanelNameField setStringValue:@""];
	[_accountPanelAccessKeyIdField setStringValue:@""];
	[_accountPanelSecretAccessKeyField setStringValue:@""];
	[_accountPanelSshPrivateKeyFileField setStringValue:@""];
	[_accountPanelSshUserNameField setStringValue:@""];
	[_accountPanelSshPortField setStringValue:@""];
    [_accountPanelSshOptionsField setStringValue:@""];

	[_accountPanelSshPrivateKeyFileField.cell setPlaceholderString:defaultSshPrivateKeyFile ? defaultSshPrivateKeyFile : @""];
	[_accountPanelSshUserNameField.cell setPlaceholderString:defaultSshUserName ? defaultSshUserName : @"root"];
    [_accountPanelSshPortField.cell setPlaceholderString:defaultSshPort > 0 ? [NSString stringWithFormat:@"%zd", defaultSshPort] : @"22"];
    [_accountPanelSshOptionsField.cell setPlaceholderString:defaultSshOptions ? defaultSshOptions : @""];

	[_accountPanelSaveButton setEnabled:NO];
	[_accountPanel makeFirstResponder:_accountPanelAccessKeyIdField];
    
	[NSApp beginSheet:_accountPanel
	   modalForWindow:[NSApp mainWindow]
		modalDelegate:self
	   didEndSelector:@selector(accountSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}

- (IBAction)editAccountAction:(id)sender
{
	if ([sender isKindOfClass:[NSTableView class]] && [_accountsTableView clickedRow] < 0)
		return;		// clicked on a header row
		
	Account *account = [[_accountsController selectedObjects] objectAtIndex:0];
	if (account) {
	
		_accountActionType = kAccountActionEditAccount;
		
		NSString *defaultSshPrivateKeyFile = [[NSUserDefaults standardUserDefaults] sshPrivateKeyFile];
		NSString *defaultSshUserName = [[NSUserDefaults standardUserDefaults] sshUserName];
		NSUInteger defaultSshPort = [[NSUserDefaults standardUserDefaults] sshPort];
        NSString *defaultSshOptions = [[NSUserDefaults standardUserDefaults] sshOptions];

		[_accountPanelNameField setStringValue:account.name ? account.name : @""];
		[_accountPanelAccessKeyIdField setStringValue:account.accessKeyID ? account.accessKeyID : @""];
		[_accountPanelSecretAccessKeyField setStringValue:account.secretAccessKey ? account.secretAccessKey : @""];
		[_accountPanelSshPrivateKeyFileField setStringValue:account.sshPrivateKeyFile ? account.sshPrivateKeyFile : @""];
		[_accountPanelSshUserNameField setStringValue:account.sshUserName ? account.sshUserName : @""];
		[_accountPanelSshPortField setStringValue:account.sshPort > 0 ? [NSString stringWithFormat:@"%zd", account.sshPort] : @""];
		[_accountPanelSshOptionsField setStringValue:account.sshOptions ? account.sshOptions : @""];

		[_accountPanelSshPrivateKeyFileField.cell setPlaceholderString:defaultSshPrivateKeyFile ? defaultSshPrivateKeyFile : @""];
		[_accountPanelSshUserNameField.cell setPlaceholderString:defaultSshUserName ? defaultSshUserName : @"root"];
		[_accountPanelSshPortField.cell setPlaceholderString:defaultSshPort > 0 ? [NSString stringWithFormat:@"%zd", defaultSshPort] : @"22"];
        [_accountPanelSshOptionsField.cell setPlaceholderString:defaultSshOptions ? defaultSshOptions : @""];

		[_accountPanelSaveButton setEnabled:YES];
		[_accountPanel makeFirstResponder:_accountPanelAccessKeyIdField];
		
		[NSApp beginSheet:_accountPanel
		   modalForWindow:[NSApp mainWindow]
			modalDelegate:self
		   didEndSelector:@selector(accountSheetDidEnd:returnCode:contextInfo:)
			  contextInfo:NULL];
	}
}

- (void)removeAccountAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[[alert window] orderOut:nil];
	
	if (returnCode == 0) {
		[_accountsManager removeAccountAtIndex:[_accountsController selectionIndex]];
	}
}

- (IBAction)removeAccountAction:(id)sender
{
	Account *account = [[_accountsController selectedObjects] objectAtIndex:0];
	
	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"Remove account \"%@\"?", account.title]
									 defaultButton:@"Cancel"
								   alternateButton:@"Remove"
									   otherButton:nil
						 informativeTextWithFormat:@""];
	
	[alert beginSheetModalForWindow:[NSApp mainWindow]
					  modalDelegate:self
					 didEndSelector:@selector(removeAccountAlertDidEnd:returnCode:contextInfo:)
						contextInfo:NULL];
}

#pragma mark - Regions pane

// Elastics 1.x had eight hard-wired region checkboxes (bound to the regionXxxEnabled
// properties) in MainMenu.xib. Replace them at launch with one checkbox per region in
// AWSRegions(), laid out in two columns, so the list can grow without editing the nib.
- (void)buildRegionsPane
{
    NSTextField *label = nil;
    for (NSView *view in [[[_regionsPane subviews] copy] autorelease]) {
        if ([view isKindOfClass:[NSButton class]]) {
            [view unbind:NSValueBinding];
            [view unbind:NSEnabledBinding];
            [view removeFromSuperview];
        }
        else if ([view isKindOfClass:[NSTextField class]]) {
            label = (NSTextField *)view;
        }
    }

    NSArray *regions = AWSRegions();
    NSUInteger rows = ([regions count] + 1) / 2;
    const CGFloat margin = 20.f, labelGap = 8.f, rowHeight = 20.f, columnWidth = 225.f;
    CGFloat labelHeight = label ? NSHeight([label frame]) : 0.f;
    CGFloat paneHeight = margin + labelHeight + labelGap + rows * rowHeight + margin;

    [_regionsPane setFrameSize:NSMakeSize(NSWidth([_regionsPane frame]), paneHeight)];
    if (label)
        [label setFrameOrigin:NSMakePoint(NSMinX([label frame]), paneHeight - margin - labelHeight)];

    [_regionCheckboxes release];
    _regionCheckboxes = [[NSMutableArray alloc] initWithCapacity:[regions count]];

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [regions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *awsRegion = (NSString *)obj;
        NSUInteger column = idx / rows, row = idx % rows;

        NSButton *checkbox = [NSButton checkboxWithTitle:AWSRegionTitle(awsRegion)
                                                  target:self
                                                  action:@selector(regionCheckboxAction:)];
        [checkbox setIdentifier:awsRegion];
        [checkbox setToolTip:awsRegion];
        [checkbox setState:[userDefaults isAWSRegionActive:awsRegion] ? NSControlStateValueOn : NSControlStateValueOff];
        [checkbox setFrame:NSMakeRect(margin + column * columnWidth,
                                      paneHeight - margin - labelHeight - labelGap - (row + 1) * rowHeight,
                                      columnWidth - 5.f,
                                      rowHeight)];
        [_regionsPane addSubview:checkbox];
        [_regionCheckboxes addObject:checkbox];
    }];

    [self updateRegionCheckboxes];
}

// At least one region must stay active: disable the last checked box.
- (void)updateRegionCheckboxes
{
    BOOL moreThanOneActiveRegion = [[[NSUserDefaults standardUserDefaults] activeAWSRegions] count] > 1;

    for (NSButton *checkbox in _regionCheckboxes) {
        [checkbox setEnabled:[checkbox state] == NSControlStateValueOff || moreThanOneActiveRegion];
    }
}

- (void)regionCheckboxAction:(id)sender
{
    NSButton *checkbox = (NSButton *)sender;
    [[NSUserDefaults standardUserDefaults] setAWSRegion:[checkbox identifier]
                                                 active:[checkbox state] == NSControlStateValueOn];
    [self updateRegionCheckboxes];
}

#pragma mark - Actions

- (IBAction)showGeneralPaneAction:(id)sender
{
	[self showPreferencePane:kGeneralPaneIndex animated:YES];
}

- (IBAction)showRegionsPaneAction:(id)sender
{
	[self showPreferencePane:kRegionsPaneIndex animated:YES];
}

- (IBAction)showConnectionsPaneAction:(id)sender
{
	[self showPreferencePane:kConnectionsPaneIndex animated:YES];
}

- (IBAction)chooseDefaultKeypairAction:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setShowsHiddenFiles:YES];

//	[panel beginSheetModalForWindow:_window
//				  completionHandler:^(NSInteger result) {
//					  if (result == NSOKButton) {
//                          NSString *filename = [[[panel URLs] objectAtIndex:0] path];
//                          [[NSUserDefaults standardUserDefaults] setSshPrivateKeyFile:filename];
//					  }
//				  }];
	
	if ([panel runModal] == NSFileHandlingPanelOKButton) {
		NSString *filename = [[[panel URLs] objectAtIndex:0] path];
		[[NSUserDefaults standardUserDefaults] setSshPrivateKeyFile:filename];
	}
}

// Target of the original nib checkboxes, which buildRegionsPane removes; kept so the nib loads.
- (IBAction)toggleRegionEnabledAction:(id)sender
{
}

- (IBAction)chooseAccountKeypairAction:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setShowsHiddenFiles:YES];
	
	if ([panel runModal] == NSFileHandlingPanelOKButton) {
		NSString *filename = [[[panel URLs] objectAtIndex:0] path];
		[_accountPanelSshPrivateKeyFileField setStringValue:filename];
	}
}

- (void)aboutAction:(id)sender
{
	[_aboutPanel center];
	
	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
	NSString *bundleShortVersionString = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
	NSString *version = [NSString stringWithFormat:NSLocalizedString(@"Version %@", nil), bundleShortVersionString];
	
	NSData *copyrightData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"html"]];
	NSAttributedString *copyright = [[NSAttributedString alloc] initWithHTML:copyrightData documentAttributes:nil];
	
	[_aboutVersionLabel setStringValue:version];

	// HTML import hard-codes black text; use the label color (readable in Dark Mode),
	// except on links, which keep their link styling
	NSMutableAttributedString *credits = [[copyright mutableCopy] autorelease];
	[copyright release];
	[credits enumerateAttribute:NSLinkAttributeName
						inRange:NSMakeRange(0, [credits length])
						options:0
					 usingBlock:^(id link, NSRange range, BOOL *stop) {
		if (!link)
			[credits addAttribute:NSForegroundColorAttributeName value:[NSColor labelColor] range:range];
	}];

	// links are only clickable in a selectable label with text attributes enabled
	[_aboutCopyrightLabel setSelectable:YES];
	[_aboutCopyrightLabel setAllowsEditingTextAttributes:YES];
	[[_aboutCopyrightLabel cell] setWraps:YES];
	[[_aboutCopyrightLabel cell] setLineBreakMode:NSLineBreakByWordWrapping];
	[_aboutCopyrightLabel setAttributedStringValue:credits];

	// the nib sized this label for one line: grow the panel (its other views keep
	// their distance from the top) and the label to fit the credits, once
	NSRect labelFrame = [_aboutCopyrightLabel frame];
	CGFloat neededHeight = ceil([[_aboutCopyrightLabel cell] cellSizeForBounds:NSMakeRect(0, 0, NSWidth(labelFrame), CGFLOAT_MAX)].height);
	CGFloat delta = neededHeight - NSHeight(labelFrame);
	if (delta > 0) {
		NSRect panelFrame = [_aboutPanel frame];
		panelFrame.size.height += delta;
		[_aboutPanel setFrame:panelFrame display:NO];
		[_aboutCopyrightLabel setFrame:NSMakeRect(NSMinX(labelFrame), NSMinY(labelFrame), NSWidth(labelFrame), neededHeight)];
	}

	[_aboutPanel center];
	[_aboutPanel makeKeyAndOrderFront:self];
}

- (IBAction)elasticsWebsiteAction:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kElasticsWebsiteURL]];
}

- (IBAction)sendFeeedbackAction:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kElasticsSendFeedbackURL]];
}

@end
