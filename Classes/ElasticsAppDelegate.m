//
//  ElasticsAppDelegate.m
//  Elastics
//
//  Created by Dmitri Goutnik on 21/12/2010.
//  Copyright 2010 Tundra Bot. All rights reserved.
//

#import "ElasticsAppDelegate.h"
#import "DataSource.h"
#import "EC2Tag.h"
#import "ChartView.h"
#import "Preferences.h"
#import "AccountsManager.h"
#import "Constants.h"

//const CGFloat kActionItemTableWidth             = 180.;
const CGFloat kActionItemLabelColumnWidth       = 170.;

const CGFloat kInstanceInfoTableWidth           = 230.;
const CGFloat kInstanceInfoLabelColumnWidth     = 100.;

const CGFloat kMessageTableWidth                = 180.;

static NSString *const kElasticsPreferencesApplicationPath	= @"Contents/Helpers/Elastics Preferences.app";

// Instance menu items carry this tag (and the instance ID as represented object)
static const NSInteger kInstanceMenuItemTag = -100;
// Group menu items (a submenu of instance items) carry this tag
static const NSInteger kInstanceGroupMenuItemTag = -101;

// Quote a value as one POSIX shell word: 'it'\''s' -> it's
static NSString *ElasticsShellQuote(NSString *value)
{
	return [NSString stringWithFormat:@"'%@'", [value stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]];
}

// Escape a value for use inside an AppleScript "..." string literal
static NSString *ElasticsAppleScriptEscape(NSString *value)
{
	NSString *escaped = [value stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
	return [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
}

@interface ElasticsAppDelegate () <NSSearchFieldDelegate>

- (void)setUpSearchItem;
- (BOOL)isSearching;
- (void)showInstances:(NSArray *)instances afterItem:(NSMenuItem *)titleItem;
- (void)rebuildInstanceSection;
- (NSArray *)groupedInstanceItems;
- (NSDictionary *)groupTitlesByInstanceId:(NSArray *)instances;
- (NSMenuItem *)groupItemWithTitle:(NSString *)title instances:(NSArray *)instances;
- (NSArray *)allInstanceMenuItems;
- (void)filterInstanceItems;
- (void)removeMenuItemsBelowSearch;
- (void)applySearchFilter;
- (BOOL)instance:(EC2Instance *)instance matchesSearchTerms:(NSArray *)terms;
- (void)focusSearchField;

- (void)resetMenu;
- (void)addMenuActionItems;
- (void)refreshMenu:(NSNotification *)notification;

- (NSMenuItem *)titleItemWithTitle:(NSString *)title;
- (NSMenuItem *)messageItemWithTitle:(NSString *)title image:(NSImage *)image;
- (NSMenuItem *)progressMessageItemWithTitle:(NSString *)title;
- (NSMenuItem *)errorMessageItemWithTitle:(NSString *)title;
- (NSMenuItem *)notificationMessageItemWithTitle:(NSString *)title;
- (NSMenuItem *)instanceItemWithInstance:(EC2Instance *)instance;
- (NSImage *)imageForRegion:(NSString *)awsRegion;
- (NSMenuItem *)regionItemWithRegion:(NSString *)awsRegion info:(NSString *)info;
- (NSMenuItem *)chartItemWithRange:(NSUInteger)range datapoints:(NSArray *)datapoints;
- (NSMenuItem *)infoItemWithLabel:(NSString *)label info:(NSString *)info action:(SEL)action tooltip:(NSString *)tooltip;
- (NSMenuItem *)infoItemWithLabel:(NSString *)label info:(NSString *)info action:(SEL)action tooltip:(NSString *)tooltip
					   tableWidth:(CGFloat)tableWidth labelWidth:(CGFloat)labelWidth;
- (NSMenuItem *)tagsItemForInstance:(EC2Instance *)instance;
- (NSMenuItem *)actionItemWithLabel:(NSString *)label info:(NSString *)info action:(SEL)action;
- (NSMenuItem *)dummyItem;

- (NSMenu *)submenuForInstance:(EC2Instance *)instance;
- (void)refreshSubmenu:(NSMenu *)menu forInstance:(EC2Instance *)instance;
- (NSArray *)storageItemsForInstance:(EC2Instance *)instance;

- (BOOL)refresh;
- (BOOL)refreshIgnoringAge;
- (BOOL)refresh:(NSString *)instanceId;
- (void)refreshCompleted:(NSNotification *)notification;

- (void)loadPreferences;
- (void)setupDataSource;
- (void)preferencesDidChange:(NSNotification *)notification;

- (void)enableRefreshTimer;
- (void)disableRefreshTimer;
- (void)timerRefresh:(NSTimer *)timer;

- (void)workspaceSessionDidBecomeActive:(NSNotification *)notification;
- (void)workspaceSessionDidResignActive:(NSNotification *)notification;
- (void)workspaceDidWake:(NSNotification *)notification;

- (void)nopAction:(id)sender;
- (void)selectAccountAction:(id)sender;
- (void)selectRegionAction:(id)sender;
- (void)refreshAction:(id)sender;
- (void)quitAction:(id)sender;
- (void)editPreferencesAction:(id)sender;
- (void)copyToPasteboardAction:(id)sender;
- (NSString *)connectAddressForInstance:(EC2Instance *)instance;
- (void)connectToInstanceWithSshAction:(id)sender;
- (void)connectToInstanceWithRdpAction:(id)sender;
- (void)aboutAction:(id)sender;
- (void)openAWSManagementConsoleAction:(id)sender;

@end

@implementation ElasticsAppDelegate {
	NSMenuItem		*_searchItem;       // always the first item of the status menu
	NSSearchField	*_searchField;
	NSMenuItem		*_noMatchesItem;    // shown when the search hides every instance
	NSMenuItem		*_instancesTitleItem;   // "INSTANCES"; the instance section follows it
	NSArray			*_displayedInstances;   // EC2Instance, in display order
	NSMutableArray	*_instanceSectionItems; // top-level items currently in the instance section
	BOOL			_instanceSectionIsFlat; // YES while searching: no groups, every instance listed
}

@synthesize aboutPanel = _aboutPanel;
@synthesize aboutVersionLabel = _aboutVersionLabel;
@synthesize aboutCopyrightLabel = _aboutCopyrightLabel;

static NSColor *_titleColor;
static NSColor *_taggedInstanceColor;
static NSColor *_untaggedInstanceColor;
static NSColor *_actionItemColor;
static NSColor *_messageItemColor;
static NSColor *_labelColumnColor;
static NSColor *_infoColumnColor;

static NSFont *_statusItemFont;

static NSFont *_titleFont;
static NSFont *_taggedInstanceFont;
static NSFont *_untaggedInstanceFont;
static NSFont *_actionItemFont;
static NSFont *_messageItemFont;
static NSFont *_labelColumnFont;
static NSFont *_infoColumnFont;


static NSDictionary *_titleAttributes;
static NSDictionary *_taggedInstanceAttributes;
static NSDictionary *_untaggedInstanceAttributes;
static NSDictionary *_actionItemAttributes;
static NSDictionary *_messageItemAttributes;
static NSDictionary *_labelColumnAttributes;
static NSDictionary *_infoColumnAttributes;

static NSImage *_statusItemImage;
static NSImage *_statusItemAlertImage;

static NSImage *_usImage;
static NSImage *_euImage;
static NSImage *_sgImage;
static NSImage *_jpImage;
static NSImage *_brImage;

#pragma mark - Initialization

+ (void)initialize
{
	TB_VALIDATE_EXPIRATION_DATE();
	
	if (!_titleColor)               _titleColor = [[NSColor colorWithDeviceRed:(0.f/255.f) green:(112.f/255.f) blue:(180.f/255.f) alpha:1.f] retain];
	if (!_taggedInstanceColor)      _taggedInstanceColor = [[NSColor labelColor] retain];
	if (!_untaggedInstanceColor)	_untaggedInstanceColor = [[NSColor labelColor] retain];
	if (!_actionItemColor)			_actionItemColor = [[NSColor labelColor] retain];
	if (!_messageItemColor)			_messageItemColor = [[NSColor secondaryLabelColor] retain];
	if (!_labelColumnColor)			_labelColumnColor = [[NSColor labelColor] retain];
	if (!_infoColumnColor)			_infoColumnColor = [[NSColor labelColor] retain];

	if (!_statusItemFont)			_statusItemFont = [[NSFont systemFontOfSize:13.0f] retain];
	
	if (!_titleFont)				_titleFont = [[NSFont boldSystemFontOfSize:10.0f] retain];
	if (!_taggedInstanceFont)		_taggedInstanceFont = [[NSFont boldSystemFontOfSize:13.0f] retain];
	if (!_untaggedInstanceFont)		_untaggedInstanceFont = [[NSFont systemFontOfSize:13.0f] retain];
	if (!_actionItemFont)			_actionItemFont = [[NSFont boldSystemFontOfSize:11.0f] retain];
	if (!_messageItemFont)			_messageItemFont = [[NSFont boldSystemFontOfSize:11.0f] retain];
	if (!_labelColumnFont)			_labelColumnFont = [[NSFont systemFontOfSize:11.0f] retain];
	if (!_infoColumnFont)			_infoColumnFont = [[NSFont boldSystemFontOfSize:11.0f] retain];

	if (!_titleAttributes)
		_titleAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
							 _titleColor, NSForegroundColorAttributeName,
							 _titleFont, NSFontAttributeName,
							 [NSNumber numberWithFloat:8.f], NSBaselineOffsetAttributeName,
							 nil] retain];

	if (!_taggedInstanceAttributes)
		_taggedInstanceAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
									  _taggedInstanceColor, NSForegroundColorAttributeName,
									  _taggedInstanceFont, NSFontAttributeName,
									  nil] retain];

	if (!_taggedInstanceAttributes)
		_untaggedInstanceAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
										_untaggedInstanceColor, NSForegroundColorAttributeName,
										_untaggedInstanceFont, NSFontAttributeName,
										nil] retain];

	if (!_actionItemAttributes)
		_actionItemAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
								  _actionItemColor, NSForegroundColorAttributeName,
								  _actionItemFont, NSFontAttributeName,
								  nil] retain];

	if (!_messageItemAttributes)
		_messageItemAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
								   _messageItemColor, NSForegroundColorAttributeName,
								   _messageItemFont, NSFontAttributeName,
								   nil] retain];

	if (!_labelColumnAttributes)
		_labelColumnAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
								   _labelColumnColor, NSForegroundColorAttributeName,
								   _labelColumnFont, NSFontAttributeName,
								   //labelParagraphStyle, NSParagraphStyleAttributeName,
								   nil] retain];
	if (!_infoColumnAttributes)
		_infoColumnAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
								  _infoColumnColor, NSForegroundColorAttributeName,
								  _infoColumnFont, NSFontAttributeName,
								  //infoParagraphStyle, NSParagraphStyleAttributeName,
								  nil] retain];
	
	if (!_statusItemImage) {
		// template image: the menu bar tints it for light/dark appearance and highlighting
		_statusItemImage = [NSImage imageNamed:@"StatusItem"];
		[_statusItemImage setTemplate:YES];
	}
	if (!_statusItemAlertImage)	    _statusItemAlertImage = [NSImage imageNamed:@"StatusItemAlert"];
	
	if (!_usImage)	                _usImage = [NSImage imageNamed:@"US"];
	if (!_euImage)	                _euImage = [NSImage imageNamed:@"EU"];
	if (!_sgImage)	                _sgImage = [NSImage imageNamed:@"SG"];
	if (!_jpImage)	                _jpImage = [NSImage imageNamed:@"JP"];
	if (!_brImage)	                _brImage = [NSImage imageNamed:@"BR"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	// bring over settings saved under the old com.tundrabot identifiers (once)
	[NSUserDefaults importLegacyElasticsPreferences];

	// register preferences set through Preferences helper app and defaults
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults addSuiteNamed:kElasticsPreferencesBundleIdentifier];
	[userDefaults registerDefaults:[userDefaults defaultElasticsPreferences]];

	// load accounts
	_accountsManager = [[AccountsManager alloc] init];
	
	// load current preferences
	[self loadPreferences];

	// set up status item menu
	_statusMenu = [[NSMenu alloc] initWithTitle:@""];
	[_statusMenu setAutoenablesItems:NO];
//	[_statusMenu setShowsStateColumn:NO];
	[_statusMenu setDelegate:self];
	[self setUpSearchItem];
	[self resetMenu];

	// set up status item
	_statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	NSStatusBarButton *statusButton = [_statusItem button];
	[statusButton setImage:_statusItemImage];
	[statusButton setImagePosition:NSImageLeft];
	[statusButton setFont:_statusItemFont];
	[statusButton setToolTip:@"Elastics"];
	[_statusItem setMenu:_statusMenu];

	// set up pasteboard
	NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
	[pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];

	// subscribe to data source notifications
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(refreshCompleted:)
												 name:kDataSourceRefreshCompletedNotification
											   object:[DataSource sharedDataSource]];

	// subscribe to notifications from Preferences app
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
														selector:@selector(preferencesDidChange:)
															name:kPreferencesDidChangeNotification
														  object:nil];
	
	// subscribe to workspace notifications
	NSNotificationCenter *workspaceNotificationCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
	
	// fast user switching
	[workspaceNotificationCenter addObserver:self
									selector:@selector(workspaceSessionDidBecomeActive:)
										name:NSWorkspaceSessionDidBecomeActiveNotification
									  object:nil];
	[workspaceNotificationCenter addObserver:self
									selector:@selector(workspaceSessionDidResignActive:)
										name:NSWorkspaceSessionDidResignActiveNotification
									  object:nil];
	
	// sleep
	[workspaceNotificationCenter addObserver:self
									selector:@selector(workspaceDidWake:)
										name:NSWorkspaceDidWakeNotification
									  object:nil];
	
	// perform initial refresh
	[self refresh];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	// unsubscribe from notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self
															   name:kPreferencesDidChangeNotification
															 object:nil];
	
	// post app termination notification so Preferences will terminate too
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:kPreferencesShouldTerminateNotification
																   object:nil
                                                                 userInfo:nil
                                                       deliverImmediately:YES];
}

- (void)dealloc
{
	[_statusItem release];
	[_statusMenu release];
	[_refreshTimer invalidate];
	[_refreshTimer release];
	[_accountsManager release];
	[_searchItem release];
	[_searchField release];
	[_noMatchesItem release];
	[_instancesTitleItem release];
	[_displayedInstances release];
	[_instanceSectionItems release];

	[super dealloc];
}

#pragma mark - Status menu

- (void)resetMenu
{
	[self removeMenuItemsBelowSearch];
	[_statusMenu addItem:[self progressMessageItemWithTitle:@"Querying instance info..."]];
	[self addMenuActionItems];
}

- (void)addMenuActionItems
{
	if ([[_accountsManager accounts] count]) {
		// if there are configured accounts, show accounts and region selection

		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        DataSource *dataSource = [DataSource sharedDataSource];
		NSInteger currentAccountId = userDefaults.accountId;
        BOOL hideTerminatedInstances = userDefaults.isHideTerminatedInstances;
		
		// Accounts
		
		[_statusMenu addItem:[NSMenuItem separatorItem]];
		[_statusMenu addItem:[self titleItemWithTitle:@"AWS ACCOUNTS"]];
        
		for (Account *account in [_accountsManager accounts]) {
			NSMenuItem *item = [self actionItemWithLabel:account.title info:nil action:@selector(selectAccountAction:)];
			[item setTag:account.accountId];
			[item setState:account.accountId == currentAccountId ? NSOnState : NSOffState];
			[_statusMenu addItem:item];
		}
		
		// Regions
		
		[_statusMenu addItem:[NSMenuItem separatorItem]];
		[_statusMenu addItem:[self titleItemWithTitle:@"AWS REGIONS"]];

        for (NSString *awsRegion in [userDefaults activeAWSRegions]) {
            [_statusMenu addItem:[self regionItemWithRegion:awsRegion
                                                       info:[dataSource instanceCountInRegionStringRepresentation:awsRegion hideTerminatedInstances:hideTerminatedInstances]]];
        }

		// Refresh
		
		if (!userDefaults.isRefreshOnMenuOpen) {
			[_statusMenu addItem:[NSMenuItem separatorItem]];
			[_statusMenu addItem:[self actionItemWithLabel:@"Refresh" info:nil action:@selector(refreshAction:)]];
		}
	}
	
	// Preferences and Quit

	[_statusMenu addItem:[NSMenuItem separatorItem]];
	[_statusMenu addItem:[self actionItemWithLabel:@"Open AWS Management Console" info:nil action:@selector(openAWSManagementConsoleAction:)]];
	[_statusMenu addItem:[self actionItemWithLabel:@"Preferences..." info:nil action:@selector(editPreferencesAction:)]];
	[_statusMenu addItem:[self actionItemWithLabel:@"Quit" info:nil action:@selector(quitAction:)]];
}

- (void)refreshMenu:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSString *refreshType = [userInfo objectForKey:kDataSourceRefreshTypeInfoKey];
    DataSource *dataSource = [DataSource sharedDataSource];
    
    if ([refreshType isEqualToString:kDataSourceCurrentRegionRefreshType]) {
        // current region refresh

//        TBTrace(@"current region refresh");
        
        [_statusMenu setMinimumWidth:0];
        [self removeMenuItemsBelowSearch];

        NSError *error = [userInfo objectForKey:kDataSourceErrorInfoKey];
        if (error) {
            // refresh finished with error
            
            NSString *errorMessage = nil;
            if ([error domain] == kAWSErrorDomain)
                errorMessage = [[error userInfo] objectForKey:kAWSErrorMessageKey];
            else
                errorMessage = [[error userInfo] objectForKey:NSLocalizedDescriptionKey];
            
            [_statusMenu addItem:[self errorMessageItemWithTitle:errorMessage]];
            
            [self addMenuActionItems];
            
            [[_statusItem button] setImage:_statusItemAlertImage];
            [[_statusItem button] setTitle:@""];
        }
        else {
            // refresh finished successfully
            
            NSArray *instances = nil;
            
            BOOL hideTerminatedInstances = [[NSUserDefaults standardUserDefaults] isHideTerminatedInstances];
            BOOL sortInstancesByTitle = [[NSUserDefaults standardUserDefaults] isSortInstancesByTitle];
            if (hideTerminatedInstances) {
                instances = sortInstancesByTitle ? dataSource.sortedRunningInstances : dataSource.runningInstances;
            }
            else {
                instances = sortInstancesByTitle ? dataSource.sortedInstances : dataSource.instances;
            }
            NSUInteger instancesCount = [instances count];
            
            if (instancesCount > 0) {
                // there are instances
                
                NSMenuItem *titleItem = [self titleItemWithTitle:@"INSTANCES"];
                [_statusMenu addItem:titleItem];
                [self showInstances:instances afterItem:titleItem];
                
                [self addMenuActionItems];
            }
            else {
                // there are no instances
                
                NSString *awsRegionName = AWSRegionTitle([[NSUserDefaults standardUserDefaults] awsRegion]);
                [_statusMenu addItem:[self notificationMessageItemWithTitle:
                                      [NSString stringWithFormat:@"No instances in\n%@ region.", awsRegionName]]];
                
                [self addMenuActionItems];
            }

            // plain title (font set on the button) so the menu bar picks the text color
            [[_statusItem button] setImage:_statusItemImage];
            [[_statusItem button] setTitle:[NSString stringWithFormat:@"%zd", instancesCount]];
        
            [_statusMenu setMinimumWidth:100];
        }
    }
    else if ([refreshType isEqualToString:kDataSourceAllRegionsRefreshType]) {
        // all regions refresh

//        TBTrace(@"all regions refresh");

        BOOL hideTerminatedInstances = [[NSUserDefaults standardUserDefaults] isHideTerminatedInstances];

        for (NSString *awsRegion in AWSRegions()) {
            NSUInteger menuItemIdx = [[_statusMenu itemArray] indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
                *stop = [[obj representedObject] isEqualToString:awsRegion];
                return *stop;
            }];
            
            if (menuItemIdx != NSNotFound) {
                NSMenuItem *regionItem = [self regionItemWithRegion:awsRegion
                                                               info:[dataSource instanceCountInRegionStringRepresentation:awsRegion hideTerminatedInstances:hideTerminatedInstances]]; 
                [_statusMenu removeItemAtIndex:menuItemIdx];
                [_statusMenu insertItem: regionItem atIndex:menuItemIdx];
            }
        }
    }
    else if ([refreshType isEqualToString:kDataSourceVpcsRefreshType]) {
        // VPC names arrived: relabel the groups (a failure just leaves VPC IDs)
        if (![userInfo objectForKey:kDataSourceErrorInfoKey]
            && [[NSUserDefaults standardUserDefaults] groupingMode] == kPreferencesGroupingVPC
            && ![self isSearching])
            [self rebuildInstanceSection];
    }
    else {
        // instance refresh (the instance's item may be inside a group submenu)

        EC2Instance *instance = [dataSource instance:refreshType];
        NSMenuItem *instanceItem = nil;
        for (NSMenuItem *item in [self allInstanceMenuItems]) {
            if ([[item representedObject] isEqualToString:refreshType]) {
                instanceItem = item;
                break;
            }
        }

        if (instance && [instanceItem submenu])
            [self refreshSubmenu:[instanceItem submenu] forInstance:instance];
        else
            TBTrace(@"instance not found: %@", refreshType);
    }
}

#pragma mark - Instance search

- (void)setUpSearchItem
{
	const CGFloat width = 240.f, height = 30.f, inset = 14.f;

	NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, width, height)] autorelease];
	[view setAutoresizingMask:NSViewWidthSizable];

	_searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(inset, 4.f, width - 2 * inset, 22.f)];
	[_searchField setAutoresizingMask:NSViewWidthSizable];
	[[_searchField cell] setPlaceholderString:@"Filter instances"];
	[[_searchField cell] setSendsWholeSearchString:NO];
	[_searchField setDelegate:self];
	[view addSubview:_searchField];

	_searchItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
	[_searchItem setView:view];
	[_statusMenu insertItem:_searchItem atIndex:0];

	_noMatchesItem = [[self notificationMessageItemWithTitle:@"No matching instances"] retain];
	[_noMatchesItem setHidden:YES];
}

// Rebuilding the menu keeps the search item (and its text and focus) in place.
- (void)removeMenuItemsBelowSearch
{
	while ([_statusMenu numberOfItems] > 0 && [_statusMenu itemAtIndex:[_statusMenu numberOfItems] - 1] != _searchItem)
		[_statusMenu removeItemAtIndex:[_statusMenu numberOfItems] - 1];
}

- (void)focusSearchField
{
	NSWindow *window = [_searchField window];
	if (window)
		[window makeFirstResponder:_searchField];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == _searchField)
		[self applySearchFilter];
}

- (BOOL)isSearching
{
	return [[[_searchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
}

// Called as the search text changes: switch between the grouped list and the flat
// search list when searching starts or stops, then filter.
- (void)applySearchFilter
{
	if ([self isSearching] != _instanceSectionIsFlat)
		[self rebuildInstanceSection];
	else
		[self filterInstanceItems];
}

// Hide instance items that don't match. Every word typed must appear (case- and
// diacritic-insensitive) in the name, instance ID, type, private or public IP.
// Only top-level items are filtered: while searching, every instance is top-level.
- (void)filterInstanceItems
{
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSMutableArray *terms = [NSMutableArray array];
	for (NSString *term in [[_searchField stringValue] componentsSeparatedByCharactersInSet:whitespace]) {
		if ([term length])
			[terms addObject:term];
	}

	DataSource *dataSource = [DataSource sharedDataSource];
	NSUInteger instanceCount = 0, visibleCount = 0;

	for (NSMenuItem *item in [_statusMenu itemArray]) {
		if ([item tag] != kInstanceMenuItemTag)
			continue;

		instanceCount++;
		EC2Instance *instance = [dataSource instance:[item representedObject]];
		BOOL visible = ![terms count] || (instance && [self instance:instance matchesSearchTerms:terms]);
		[item setHidden:!visible];
		if (visible)
			visibleCount++;
	}

	[_noMatchesItem setHidden:!(instanceCount > 0 && visibleCount == 0)];
}

- (BOOL)instance:(EC2Instance *)instance matchesSearchTerms:(NSArray *)terms
{
	NSMutableArray *fields = [NSMutableArray array];
	if (instance.title)				[fields addObject:instance.title];
	if (instance.instanceId)		[fields addObject:instance.instanceId];
	if (instance.instanceType)		[fields addObject:instance.instanceType];
	if (instance.privateIpAddress)	[fields addObject:instance.privateIpAddress];
	if (instance.ipAddress)			[fields addObject:instance.ipAddress];
	NSString *haystack = [fields componentsJoinedByString:@" "];

	for (NSString *term in terms) {
		if ([haystack rangeOfString:term options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location == NSNotFound)
			return NO;
	}
	return YES;
}

#pragma mark - Instance section and grouping

- (void)showInstances:(NSArray *)instances afterItem:(NSMenuItem *)titleItem
{
	[_displayedInstances release];
	_displayedInstances = [instances retain];
	[_instancesTitleItem release];
	_instancesTitleItem = [titleItem retain];
	[self rebuildInstanceSection];
}

// Replace the items after "INSTANCES": groups (or a flat list while searching),
// then the "no matches" notice. Leaves the rest of the menu, and the search field
// with its focus, untouched.
- (void)rebuildInstanceSection
{
	if (!_instanceSectionItems)
		_instanceSectionItems = [[NSMutableArray alloc] init];

	for (NSMenuItem *item in _instanceSectionItems) {
		if ([item menu] == _statusMenu)
			[_statusMenu removeItem:item];
	}
	[_instanceSectionItems removeAllObjects];

	NSInteger titleIndex = _instancesTitleItem ? [_statusMenu indexOfItem:_instancesTitleItem] : -1;
	if (titleIndex < 0)
		return;   // no instance list shown (error, or no instances)

	_instanceSectionIsFlat = [self isSearching];

	NSMutableArray *items = [NSMutableArray array];
	if (_instanceSectionIsFlat) {
		for (EC2Instance *instance in _displayedInstances)
			[items addObject:[self instanceItemWithInstance:instance]];
	}
	else {
		[items addObjectsFromArray:[self groupedInstanceItems]];
	}
	[items addObject:_noMatchesItem];

	NSInteger index = titleIndex + 1;
	for (NSMenuItem *item in items) {
		[_statusMenu insertItem:item atIndex:index++];
		[_instanceSectionItems addObject:item];
	}

	[self filterInstanceItems];
}

// Groups (sorted by title), then ungrouped instances, then "Stopped" and
// "Terminated" if enabled.
// With no grouping and no Stopped group this is the plain list.
- (NSArray *)groupedInstanceItems
{
	BOOL groupStopped = [[NSUserDefaults standardUserDefaults] isGroupStoppedInstances];
	BOOL groupTerminated = [[NSUserDefaults standardUserDefaults] isGroupTerminatedInstances];

	NSMutableArray *stopped = [NSMutableArray array];
	NSMutableArray *terminated = [NSMutableArray array];
	NSMutableArray *candidates = [NSMutableArray array];
	for (EC2Instance *instance in _displayedInstances) {
		if (groupTerminated && [instance isTerminated])
			[terminated addObject:instance];
		else if (groupStopped && [instance isStopped])
			[stopped addObject:instance];
		else
			[candidates addObject:instance];
	}

	NSDictionary *groupTitles = [self groupTitlesByInstanceId:candidates];   // instance ID -> group title

	NSMutableDictionary *groups = [NSMutableDictionary dictionary];           // group title -> instances
	NSMutableArray *ungrouped = [NSMutableArray array];
	for (EC2Instance *instance in candidates) {
		NSString *groupTitle = [groupTitles objectForKey:instance.instanceId];
		if (!groupTitle) {
			[ungrouped addObject:instance];
			continue;
		}
		NSMutableArray *members = [groups objectForKey:groupTitle];
		if (!members) {
			members = [NSMutableArray array];
			[groups setObject:members forKey:groupTitle];
		}
		[members addObject:instance];
	}

	NSMutableArray *items = [NSMutableArray array];
	NSArray *sortedTitles = [[groups allKeys] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
	for (NSString *groupTitle in sortedTitles)
		[items addObject:[self groupItemWithTitle:groupTitle instances:[groups objectForKey:groupTitle]]];

	for (EC2Instance *instance in ungrouped)
		[items addObject:[self instanceItemWithInstance:instance]];

	if ([stopped count])
		[items addObject:[self groupItemWithTitle:@"Stopped" instances:stopped]];
	if ([terminated count])
		[items addObject:[self groupItemWithTitle:@"Terminated" instances:terminated]];

	return items;
}

// Which group each instance belongs to under the current grouping setting
// (instance ID -> group title). Instances without a group are left out.
- (NSDictionary *)groupTitlesByInstanceId:(NSArray *)instances
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSMutableDictionary *result = [NSMutableDictionary dictionary];

	switch ([userDefaults groupingMode]) {
		case kPreferencesGroupingVPC: {
			// VPC name (Name tag) once loaded, otherwise the VPC ID; two VPCs with the
			// same name get their IDs added to tell them apart
			DataSource *dataSource = [DataSource sharedDataSource];
			NSMutableDictionary *vpcIdsByTitle = [NSMutableDictionary dictionary];
			for (EC2Instance *instance in instances) {
				if (![instance.vpcId length])
					continue;
				NSString *title = [[dataSource vpcWithId:instance.vpcId] title];
				if (![title length])
					title = instance.vpcId;
				NSString *knownId = [vpcIdsByTitle objectForKey:title];
				if (knownId && ![knownId isEqualToString:instance.vpcId])
					title = [NSString stringWithFormat:@"%@ (%@)", title, instance.vpcId];
				else
					[vpcIdsByTitle setObject:instance.vpcId forKey:title];
				[result setObject:title forKey:instance.instanceId];
			}
			break;
		}

		case kPreferencesGroupingNamePrefixes: {
			// the longest matching prefix wins, ignoring case; groups are titled as typed
			NSMutableArray *prefixes = [NSMutableArray array];
			for (NSString *prefix in [[userDefaults groupingNamePrefixes] componentsSeparatedByString:@","]) {
				NSString *trimmed = [prefix stringByTrimmingCharactersInSet:whitespace];
				if ([trimmed length])
					[prefixes addObject:trimmed];
			}
			for (EC2Instance *instance in instances) {
				NSString *best = nil;
				for (NSString *prefix in prefixes) {
					NSRange range = [instance.title rangeOfString:prefix options:NSCaseInsensitiveSearch | NSAnchoredSearch];
					if (range.location != NSNotFound && [prefix length] > [best length])
						best = prefix;
				}
				if (best)
					[result setObject:best forKey:instance.instanceId];
			}
			break;
		}

		case kPreferencesGroupingAutomaticNamePrefix: {
			// the text before the first - _ . or space (or the whole name, so "ghost" joins
			// "ghost-1" and "ghost-2"), when 2+ instances share it (ignoring case)
			NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"-_. "];
			NSMutableDictionary *membersByKey = [NSMutableDictionary dictionary];
			NSMutableDictionary *titlesByKey = [NSMutableDictionary dictionary];
			for (EC2Instance *instance in instances) {
				NSRange separator = [instance.title rangeOfCharacterFromSet:separators];
				if (separator.location == 0)
					continue;
				NSString *prefix = (separator.location == NSNotFound) ? instance.title : [instance.title substringToIndex:separator.location];
				NSString *key = [prefix lowercaseString];
				NSMutableArray *members = [membersByKey objectForKey:key];
				if (!members) {
					members = [NSMutableArray array];
					[membersByKey setObject:members forKey:key];
					[titlesByKey setObject:prefix forKey:key];
				}
				[members addObject:instance.instanceId];
			}
			for (NSString *key in membersByKey) {
				NSArray *members = [membersByKey objectForKey:key];
				if ([members count] < 2)
					continue;
				for (NSString *instanceId in members)
					[result setObject:[titlesByKey objectForKey:key] forKey:instanceId];
			}
			break;
		}

		case kPreferencesGroupingTag: {
			NSString *tagKey = [[userDefaults groupingTagKey] stringByTrimmingCharactersInSet:whitespace];
			if (![tagKey length])
				break;
			for (EC2Instance *instance in instances) {
				NSString *value = [[instance tagValueForKey:tagKey] stringByTrimmingCharactersInSet:whitespace];
				if ([value length])
					[result setObject:value forKey:instance.instanceId];
			}
			break;
		}

		default:
			break;
	}

	return result;
}

// A group: folder icon, title, instance count, and a submenu of its instances with
// running ones first (otherwise in list order). The submenu deliberately has no
// delegate: the menu delegate methods treat a menu's title as an instance ID.
- (NSMenuItem *)groupItemWithTitle:(NSString *)title instances:(NSArray *)instances
{
	NSArray *ordered = [instances sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(id a, id b) {
		BOOL aRunning = ((((EC2Instance *)a).instanceState.code & 0xFF) == EC2_INSTANCE_STATE_RUNNING);
		BOOL bRunning = ((((EC2Instance *)b).instanceState.code & 0xFF) == EC2_INSTANCE_STATE_RUNNING);
		if (aRunning == bRunning)
			return NSOrderedSame;
		return aRunning ? NSOrderedAscending : NSOrderedDescending;
	}];

	NSMenu *submenu = [[[NSMenu alloc] initWithTitle:title] autorelease];
	[submenu setAutoenablesItems:NO];
	for (EC2Instance *instance in ordered)
		[submenu addItem:[self instanceItemWithInstance:instance]];

	// the count goes in the menu's own badge (macOS 14+), which sits clear of the
	// submenu arrow; a two-column text title would overlap it
	NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:title action:NULL keyEquivalent:@""] autorelease];
	NSString *displayTitle = title;
	if (@available(macOS 14.0, *))
		[item setBadge:[NSMenuItemBadge badgeWithCount:[instances count]]];
	else
		displayTitle = [NSString stringWithFormat:@"%@ (%lu)", title, (unsigned long)[instances count]];
	[item setAttributedTitle:[[[NSAttributedString alloc] initWithString:displayTitle
															  attributes:_taggedInstanceAttributes] autorelease]];
	[item setIndentationLevel:1];
	[item setImage:[NSImage imageWithSystemSymbolName:@"folder" accessibilityDescription:@"Group"]];
	[item setSubmenu:submenu];
	[item setTag:kInstanceGroupMenuItemTag];
	return item;
}

// Every instance item, at the top level or inside a group.
- (NSArray *)allInstanceMenuItems
{
	NSMutableArray *result = [NSMutableArray array];
	for (NSMenuItem *item in [_statusMenu itemArray]) {
		if ([item tag] == kInstanceMenuItemTag) {
			[result addObject:item];
		}
		else if ([item tag] == kInstanceGroupMenuItemTag) {
			for (NSMenuItem *groupedItem in [[item submenu] itemArray]) {
				if ([groupedItem tag] == kInstanceMenuItemTag)
					[result addObject:groupedItem];
			}
		}
	}
	return result;
}

#pragma mark - Menu item helpers

- (NSMenuItem *)titleItemWithTitle:(NSString *)title
{
	NSMutableAttributedString *attributedTitle = [[[NSMutableAttributedString alloc] initWithString:title
																						 attributes:_titleAttributes] autorelease];
	NSMutableParagraphStyle *paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[paragraphStyle setMinimumLineHeight:20.f];

	[attributedTitle addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [attributedTitle length])];

	NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease];
	[menuItem setIndentationLevel:1];
	[menuItem setAttributedTitle:attributedTitle];
	[menuItem setEnabled:NO];

	return menuItem;
}

- (NSMenuItem *)messageItemWithTitle:(NSString *)title image:(NSImage *)image
{
	NSTextTable *table = [[[NSTextTable alloc] init] autorelease];
	[table setNumberOfColumns:1];
	[table setLayoutAlgorithm:NSTextTableAutomaticLayoutAlgorithm];
	[table setHidesEmptyCells:NO];

	NSTextTableBlock *titleBlock = [[[NSTextTableBlock alloc] initWithTable:table startingRow:0 rowSpan:1 startingColumn:0 columnSpan:1] autorelease];
	[titleBlock setContentWidth:kMessageTableWidth type:NSTextBlockAbsoluteValueType];
	[titleBlock setWidth:10.0f type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinXEdge];

	NSMutableParagraphStyle *titleParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[titleParagraphStyle setAlignment:NSLeftTextAlignment];
	[titleParagraphStyle setTextBlocks:[NSArray arrayWithObject:titleBlock]];

	NSMutableAttributedString *attributedTitle = [[[NSMutableAttributedString alloc] initWithString:@""] autorelease];
	NSUInteger attributedTitleLength = [attributedTitle length];

	NSString *titleText = nil;
	if (title) {
		if (NO == [title hasSuffix:@"."])
			titleText = [NSString stringWithFormat:@"%@.", title];
		else
			titleText = title;
	}
	else {
		titleText = @" ";
	}

	[attributedTitle replaceCharactersInRange:NSMakeRange(attributedTitleLength, 0) withString:titleText];
	[attributedTitle setAttributes:_messageItemAttributes range:NSMakeRange(attributedTitleLength, [attributedTitle length] - attributedTitleLength)];
	[attributedTitle addAttribute:NSParagraphStyleAttributeName value:titleParagraphStyle range:NSMakeRange(attributedTitleLength, [attributedTitle length] - attributedTitleLength)];

	NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease];

	[menuItem setIndentationLevel:1];
	[menuItem setAttributedTitle:attributedTitle];
//	[menuItem setTarget:self];
//	[menuItem setAction:@selector(nopAction:)];
	[menuItem setEnabled:NO];
	[menuItem setImage:image];

	return menuItem;
}

- (NSMenuItem *)progressMessageItemWithTitle:(NSString *)title
{
	return [self messageItemWithTitle:title image:[NSImage imageNamed:@"Progress"]];
}
	 
- (NSMenuItem *)errorMessageItemWithTitle:(NSString *)title
{
	return [self messageItemWithTitle:title image:[NSImage imageNamed:@"Error"]];
}

- (NSMenuItem *)notificationMessageItemWithTitle:(NSString *)title
{
	return [self messageItemWithTitle:title image:[NSImage imageNamed:@"Notification"]];
}

- (NSMenuItem *)instanceItemWithInstance:(EC2Instance *)instance
{
	NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease];
	[menuItem setIndentationLevel:1];

	// set item title to Name tag if present, otherwise to Instance ID
    NSAttributedString *attributedTitle = [[[NSAttributedString alloc] initWithString:instance.title attributes:_taggedInstanceAttributes] autorelease];
	menuItem.attributedTitle = attributedTitle;

	// set item image according to instance state
	NSImage *stateImage = nil;
//	if (instance.instanceState.code == EC2_INSTANCE_STATE_RUNNING_272) {
//		// special running state with 0x100 bit set to indicate problems with the host
//		stateImage = [NSImage imageNamed:@"InstanceStateRunning272"];
//	}
//	else {
//		// otherwise, according to API spec, high byte should be ignored
		switch (instance.instanceState.code & 0xFF) {
			case EC2_INSTANCE_STATE_RUNNING:
				stateImage = [NSImage imageNamed:@"InstanceStateRunning"];
				break;
			case EC2_INSTANCE_STATE_STOPPED:
				stateImage = [NSImage imageNamed:@"InstanceStateStopped"];
				break;
			case EC2_INSTANCE_STATE_TERMINATED:
				stateImage = [NSImage imageNamed:@"InstanceStateTerminated"];
				break;
			default:
				stateImage = [NSImage imageNamed:@"InstanceStateOther"];
				break;
		}
//	}
	[menuItem setImage:stateImage];
	
	// set item submenu
	[menuItem setSubmenu:[self submenuForInstance:instance]];
	
	// set item represented object to instance id
	[menuItem setRepresentedObject:instance.instanceId];
    // set tag to mark instance items
    [menuItem setTag:kInstanceMenuItemTag];

	return menuItem;
}

- (NSImage *)imageForRegion:(NSString *)awsRegion
{
    // flags shipped with Elastics 1.x; regions without a matching flag get no image
    if ([awsRegion hasPrefix:@"us-"])
        return _usImage;
    if ([awsRegion hasPrefix:@"eu-"])
        return _euImage;
    if ([awsRegion isEqualToString:@"ap-southeast-1"])
        return _sgImage;
    if ([awsRegion isEqualToString:@"ap-northeast-1"] || [awsRegion isEqualToString:@"ap-northeast-3"])
        return _jpImage;
    if ([awsRegion isEqualToString:@"sa-east-1"])
        return _brImage;
    return nil;
}

- (NSMenuItem *)regionItemWithRegion:(NSString *)awsRegion info:(NSString *)info
{
    NSInteger currentRegion = [[NSUserDefaults standardUserDefaults] region];
    NSInteger regionIndex = AWSRegionPreferenceIndex(awsRegion);
    NSString *title = AWSRegionTitle(awsRegion);

    NSMenuItem *item = [self actionItemWithLabel:(title ? title : awsRegion)
                                            info:info
                                          action:@selector(selectRegionAction:)];
    [item setImage:[self imageForRegion:awsRegion]];
    [item setTag:regionIndex];
    [item setRepresentedObject:awsRegion];
    [item setState:regionIndex == currentRegion ? NSOnState : NSOffState];

    return item;
}

- (NSMenuItem *)chartItemWithRange:(NSUInteger)range datapoints:(NSArray *)datapoints
{
	ChartView *chartView = [[[ChartView alloc] initWithRange:range datapoints:datapoints] autorelease];

	NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease];
	[menuItem setIndentationLevel:1];
	[menuItem setView:chartView];

	return menuItem;
}

- (NSMenuItem *)infoItemWithLabel:(NSString *)label info:(NSString *)info action:(SEL)action tooltip:(NSString *)tooltip
{
	return [self infoItemWithLabel:label info:info action:action tooltip:tooltip
						tableWidth:kInstanceInfoTableWidth labelWidth:kInstanceInfoLabelColumnWidth];
}

- (NSMenuItem *)infoItemWithLabel:(NSString *)label info:(NSString *)info action:(SEL)action tooltip:(NSString *)tooltip
					   tableWidth:(CGFloat)tableWidth labelWidth:(CGFloat)labelWidth
{
	NSTextTable *table = [[[NSTextTable alloc] init] autorelease];
	[table setNumberOfColumns:2];
	[table setLayoutAlgorithm:NSTextTableAutomaticLayoutAlgorithm];
	[table setContentWidth:tableWidth type:NSTextBlockAbsoluteValueType];
	[table setHidesEmptyCells:NO];

	NSTextTableBlock *labelBlock = [[[NSTextTableBlock alloc] initWithTable:table startingRow:0 rowSpan:1 startingColumn:0 columnSpan:1] autorelease];
	[labelBlock setContentWidth:labelWidth type:NSTextBlockAbsoluteValueType];

	NSTextTableBlock *infoBlock = [[[NSTextTableBlock alloc] initWithTable:table startingRow:0 rowSpan:1 startingColumn:1 columnSpan:1] autorelease];

	NSMutableParagraphStyle *labelParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[labelParagraphStyle setAlignment:NSLeftTextAlignment];
	[labelParagraphStyle setTextBlocks:[NSArray arrayWithObject:labelBlock]];

	NSMutableParagraphStyle *infoParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[infoParagraphStyle setAlignment:NSRightTextAlignment];
	[infoParagraphStyle setTextBlocks:[NSArray arrayWithObject:infoBlock]];

	NSMutableAttributedString *attributedTitle = [[[NSMutableAttributedString alloc] initWithString:@""] autorelease];

	NSUInteger textLength = [attributedTitle length];
	[attributedTitle replaceCharactersInRange:NSMakeRange(textLength, 0) withString:[NSString stringWithFormat:@"%@\n", (label ? label : @" ")]];
	[attributedTitle setAttributes:_labelColumnAttributes range:NSMakeRange(textLength, [attributedTitle length] - textLength)];
	[attributedTitle addAttribute:NSParagraphStyleAttributeName value:labelParagraphStyle range:NSMakeRange(textLength, [attributedTitle length] - textLength)];

	textLength = [attributedTitle length];
	[attributedTitle replaceCharactersInRange:NSMakeRange(textLength, 0) withString:[NSString stringWithFormat:@"%@", (info ? info : @" ")]];
	[attributedTitle setAttributes:_infoColumnAttributes range:NSMakeRange(textLength, [attributedTitle length] - textLength)];
	[attributedTitle addAttribute:NSParagraphStyleAttributeName value:infoParagraphStyle range:NSMakeRange(textLength, [attributedTitle length] - textLength)];

	NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:action keyEquivalent:@""] autorelease];

	[menuItem setIndentationLevel:1];
	[menuItem setAttributedTitle:attributedTitle];
	[menuItem setTarget:self];
	[menuItem setEnabled:action != NULL];
	[menuItem setToolTip:tooltip];
	[menuItem setRepresentedObject:info];

	return menuItem;
}

- (NSMenuItem *)actionItemWithLabel:(NSString *)label info:(NSString *)info action:(SEL)action
{
    NSMutableAttributedString *attributedTitle = nil;
    
    if ([info length]) {
        // action item with additional info on the right
        
        NSTextTable *table = [[[NSTextTable alloc] init] autorelease];
        [table setNumberOfColumns:2];
        [table setLayoutAlgorithm:NSTextTableAutomaticLayoutAlgorithm];
//        [table setContentWidth:kActionItemTableWidth type:NSTextBlockAbsoluteValueType];
        [table setHidesEmptyCells:NO];

        NSTextTableBlock *labelBlock = [[[NSTextTableBlock alloc] initWithTable:table startingRow:0 rowSpan:1 startingColumn:0 columnSpan:1] autorelease];
        [labelBlock setContentWidth:kActionItemLabelColumnWidth type:NSTextBlockAbsoluteValueType];
        
        NSTextTableBlock *infoBlock = [[[NSTextTableBlock alloc] initWithTable:table startingRow:0 rowSpan:1 startingColumn:1 columnSpan:1] autorelease];
        
        NSMutableParagraphStyle *labelParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [labelParagraphStyle setAlignment:NSLeftTextAlignment];
        [labelParagraphStyle setLineBreakMode:NSLineBreakByClipping];
        [labelParagraphStyle setTextBlocks:[NSArray arrayWithObject:labelBlock]];
        
        NSMutableParagraphStyle *infoParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [infoParagraphStyle setAlignment:NSRightTextAlignment];
        [infoParagraphStyle setTextBlocks:[NSArray arrayWithObject:infoBlock]];
        
        attributedTitle = [[[NSMutableAttributedString alloc] initWithString:@""] autorelease];
        
        NSUInteger textLength = [attributedTitle length];
        [attributedTitle replaceCharactersInRange:NSMakeRange(textLength, 0) withString:[NSString stringWithFormat:@"%@\n", ([label length] ? label : @" ")]];
        [attributedTitle setAttributes:_actionItemAttributes range:NSMakeRange(textLength, [attributedTitle length] - textLength)];
        [attributedTitle addAttribute:NSParagraphStyleAttributeName value:labelParagraphStyle range:NSMakeRange(textLength, [attributedTitle length] - textLength)];
        
        textLength = [attributedTitle length];
        [attributedTitle replaceCharactersInRange:NSMakeRange(textLength, 0) withString:[NSString stringWithFormat:@"%@", ([info length] ? info : @" ")]];
        [attributedTitle setAttributes:_infoColumnAttributes range:NSMakeRange(textLength, [attributedTitle length] - textLength)];
        [attributedTitle addAttribute:NSParagraphStyleAttributeName value:infoParagraphStyle range:NSMakeRange(textLength, [attributedTitle length] - textLength)];
    }
    else {
        // simple action item

        attributedTitle = [[[NSMutableAttributedString alloc] initWithString:label attributes:_actionItemAttributes] autorelease];
    }
    
    NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:action keyEquivalent:@""] autorelease];

    [menuItem setIndentationLevel:1];
    [menuItem setAttributedTitle:attributedTitle];
    [menuItem setTarget:self];
    
    return menuItem;
}

// HACK HACK HACK
// to force menu redrawing, this item is added at the beginning of the refresh and removed at the completion
- (NSMenuItem *)dummyItem
{
	NSView *dummyView = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1, 0.01f)] autorelease];
	
	NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease];
	[menuItem setIndentationLevel:1];
	[menuItem setView:dummyView];
	
	return menuItem;
}

#pragma mark - Submenu

- (NSMenu *)submenuForInstance:(EC2Instance *)instance
{
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    [menu setTitle:instance.instanceId];
	[menu setDelegate:self];
	[menu setShowsStateColumn:NO];
 
	[self refreshSubmenu:menu forInstance:instance];

	return [menu autorelease];
}

- (void)refreshSubmenu:(NSMenu *)menu forInstance:(EC2Instance *)instance
{
	DataSource *dataSource = [DataSource sharedDataSource];

	// XXX: it seems that there's a bug in Cocoa menu system - when chart menu item gets removed,
	// Cocoa will release submenu's window (NSCarbonMenuWindow) prematurely and the app will crash with zombie access.
	// To work around this, find NSCarbonMenuWindow and send it retain/autorelease to keep it alive until next event loop.
	for (NSInteger i = 0; i < [menu numberOfItems]; i++) {
		NSView *view = [[menu itemAtIndex:i] view];
		if (view) {
			NSWindow *menuWindow = [view window];
			[[menuWindow retain] autorelease];
		}
	}
	
	[menu removeAllItems];

	[menu addItem:[self titleItemWithTitle:@"INSTANCE DETAILS"]];
	[menu addItem:[self infoItemWithLabel:@"Instance ID" info:instance.instanceId action:@selector(copyToPasteboardAction:) tooltip:@"Copy Instance ID"]];
	[menu addItem:[self infoItemWithLabel:@"Image ID" info:instance.imageId action:@selector(copyToPasteboardAction:) tooltip:@"Copy Image ID"]];
	[menu addItem:[self infoItemWithLabel:@"Instance Type" info:instance.instanceType action:NULL tooltip:nil]];
	[menu addItem:[self infoItemWithLabel:@"Lifecycle" info:[instance lifecycleTitle] action:NULL tooltip:nil]];
	[menu addItem:[self infoItemWithLabel:@"Monitoring" info:instance.monitoring.monitoringType action:NULL tooltip:nil]];
	[menu addItem:[self infoItemWithLabel:@"Launched At" info:[instance.launchTime localizedString] action:NULL tooltip:nil]];
	[menu addItem:[self infoItemWithLabel:@"Availability Zone" info:instance.placement.availabilityZone action:NULL tooltip:nil]];
    if (instance.autoscalingGroupName)
        [menu addItem:[self infoItemWithLabel:@"Autoscaling Group" info:instance.autoscalingGroupName action:NULL tooltip:nil]];
	[menu addItem:[self infoItemWithLabel:@"State" info:instance.instanceState.name action:NULL tooltip:nil]];
	NSString *stateReason = [instance stateReasonTitle];
	if (stateReason)
		[menu addItem:[self infoItemWithLabel:@"State Reason" info:stateReason action:NULL tooltip:instance.stateReasonMessage]];
	NSMenuItem *tagsItem = [self tagsItemForInstance:instance];
	if (tagsItem)
		[menu addItem:tagsItem];

	if ([instance.ipAddress length] > 0 || [instance.privateIpAddress length] > 0) {
		[menu addItem:[NSMenuItem separatorItem]];
		[menu addItem:[self titleItemWithTitle:@"NETWORKING"]];
		if ([instance.ipAddress length] > 0)
			[menu addItem:[self infoItemWithLabel:@"Public IP" info:instance.ipAddress action:@selector(copyToPasteboardAction:) tooltip:@"Copy Public IP"]];
		if ([instance.privateIpAddress length] > 0)
			[menu addItem:[self infoItemWithLabel:@"Private IP" info:instance.privateIpAddress action:@selector(copyToPasteboardAction:) tooltip:@"Copy Private IP"]];
	}

	NSArray *storageItems = [self storageItemsForInstance:instance];
	if ([storageItems count]) {
		[menu addItem:[NSMenuItem separatorItem]];
		[menu addItem:[self titleItemWithTitle:@"STORAGE"]];
		for (NSMenuItem *item in storageItems)
			[menu addItem:item];
	}

	if (instance.instanceState.code != EC2_INSTANCE_STATE_PENDING) {
		[menu addItem:[NSMenuItem separatorItem]];
		[menu addItem:[self titleItemWithTitle:@"CPU UTILIZATION"]];
		[menu addItem:[self chartItemWithRange:kAWSLastHourRange datapoints:[dataSource statisticsForMetric:kAWSCPUUtilizationMetric forInstance:instance.instanceId]]];

		if ([[dataSource statisticsForMetric:kAWSCPUUtilizationMetric forInstance:instance.instanceId] count] > 0) {
			CGFloat maxCPUUtilization = [dataSource maximumValueForMetric:kAWSCPUUtilizationMetric forInstance:instance.instanceId forRange:kAWSLastHourRange];
			CGFloat minCPUUtilization = [dataSource minimumValueForMetric:kAWSCPUUtilizationMetric forInstance:instance.instanceId forRange:kAWSLastHourRange];
			CGFloat avgCPUUtilization = [dataSource averageValueForMetric:kAWSCPUUtilizationMetric forInstance:instance.instanceId forRange:kAWSLastHourRange];
			
			if (maxCPUUtilization > 0. || minCPUUtilization > 0. || avgCPUUtilization > 0.) {
				[menu addItem:[self infoItemWithLabel:@"Maximum" info:[NSString stringWithFormat:@"%.1f%%", maxCPUUtilization] action:NULL tooltip:nil]];
				[menu addItem:[self infoItemWithLabel:@"Minimum" info:[NSString stringWithFormat:@"%.1f%%", minCPUUtilization] action:NULL tooltip:nil]];
				[menu addItem:[self infoItemWithLabel:@"Average" info:[NSString stringWithFormat:@"%.1f%%", avgCPUUtilization] action:NULL tooltip:nil]];
			}
		}
	}

	if ((instance.instanceState.code & 0xFF) == EC2_INSTANCE_STATE_RUNNING) {
		[menu addItem:[NSMenuItem separatorItem]];

		if ([instance.platform isEqualToString:@"windows"])
			[menu addItem:[self actionItemWithLabel:@"Connect (RDP)..." info:nil action:@selector(connectToInstanceWithRdpAction:)]];
		else
			[menu addItem:[self actionItemWithLabel:@"Connect (SSH)..." info:nil action:@selector(connectToInstanceWithSshAction:)]];
	}
	
//	[menu addItem:[NSMenuItem separatorItem]];
//	[menu addItem:[self actionItemWithLabel:@"Restart..." action:@selector(connectToInstanceAction:)]];
//	[menu addItem:[self actionItemWithLabel:@"Terminate..." action:@selector(connectToInstanceAction:)]];
}

// "Tags ▸" row (tag count) with a submenu of key/value rows, sorted by key with
// AWS-managed aws: tags last; clicking a row copies the value. nil without tags.
// The submenu has no delegate: menu delegate methods treat a menu's title as an
// instance ID.
- (NSMenuItem *)tagsItemForInstance:(EC2Instance *)instance
{
	NSArray *tags = [instance sortedTags];
	if (![tags count])
		return nil;

	NSMenu *submenu = [[[NSMenu alloc] initWithTitle:@"Tags"] autorelease];
	[submenu setAutoenablesItems:NO];
	[submenu setShowsStateColumn:NO];
	[submenu addItem:[self titleItemWithTitle:@"TAGS"]];

	BOOL addedSeparator = NO;
	for (EC2Tag *tag in tags) {
		if (!addedSeparator && [[tag.key lowercaseString] hasPrefix:@"aws:"] && [[submenu itemArray] count] > 1) {
			[submenu addItem:[NSMenuItem separatorItem]];   // user tags above, AWS-managed tags below
			addedSeparator = YES;
		}
		NSString *value = [tag.value length] ? tag.value : @"";
		NSMenuItem *item = [self infoItemWithLabel:tag.key
											  info:([value length] ? value : @"\u2014")
											action:@selector(copyToPasteboardAction:)
										   tooltip:[NSString stringWithFormat:@"Copy value of %@", tag.key]
										tableWidth:420.f
										labelWidth:200.f];
		[item setRepresentedObject:value];   // copied by copyToPasteboardAction:
		[submenu addItem:item];
	}

	NSMenuItem *item = [self infoItemWithLabel:@"Tags"
										  info:[NSString stringWithFormat:@"%lu", (unsigned long)[tags count]]
										action:NULL
									   tooltip:nil];
	[item setEnabled:YES];   // NULL action disables info rows; this one opens a submenu
	[item setSubmenu:submenu];
	return item;
}

// Storage rows: the root device type, then one row per attached EBS volume (root
// first), labelled by device name, then the instance store disks of the instance type. Size and type come from DescribeVolumes when it
// is permitted; otherwise the volume ID is shown. Clicking a volume copies its ID.
- (NSArray *)storageItemsForInstance:(EC2Instance *)instance
{
	NSMutableArray *items = [NSMutableArray array];
	NSDictionary *volumes = [[DataSource sharedDataSource] volumesForInstance:instance.instanceId];

	if ([instance.rootDeviceType length]) {
		NSString *rootType = [instance.rootDeviceType isEqualToString:@"ebs"] ? @"EBS"
						   : [instance.rootDeviceType isEqualToString:@"instance-store"] ? @"Instance Store"
						   : instance.rootDeviceType;
		NSString *rootInfo = [instance.rootDeviceName length]
						   ? [NSString stringWithFormat:@"%@ \u00B7 %@", rootType, instance.rootDeviceName]
						   : rootType;
		[items addObject:[self infoItemWithLabel:@"Root Device" info:rootInfo action:NULL tooltip:nil]];
	}

	NSString *rootDeviceName = instance.rootDeviceName;
	NSArray *devices = [instance.blockDeviceMapping sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
		BOOL aIsRoot = [[a deviceName] isEqualToString:rootDeviceName];
		BOOL bIsRoot = [[b deviceName] isEqualToString:rootDeviceName];
		if (aIsRoot != bIsRoot)
			return aIsRoot ? NSOrderedAscending : NSOrderedDescending;
		return [[a deviceName] localizedStandardCompare:[b deviceName]];
	}];

	for (EC2BlockDevice *device in devices) {
		if (![device.volumeId length])
			continue;

		EC2Volume *volume = [volumes objectForKey:device.volumeId];
		NSMutableArray *details = [NSMutableArray array];     // shown in the row
		NSMutableArray *extras = [NSMutableArray array];      // tooltip only

		if (volume) {
			if (volume.size > 0)
				[details addObject:[NSString stringWithFormat:@"%ld GiB", (long)volume.size]];
			if ([volume.volumeType length])
				[details addObject:volume.volumeType];
			if (volume.iops > 0)
				[extras addObject:[NSString stringWithFormat:@"%ld IOPS", (long)volume.iops]];
			if (volume.throughput > 0)
				[extras addObject:[NSString stringWithFormat:@"%ld MiB/s", (long)volume.throughput]];
			[extras addObject:volume.encrypted ? @"encrypted" : @"not encrypted"];
		}
		if (device.deleteOnTermination)
			[extras addObject:@"deleted on termination"];

		NSString *info = [details count] ? [details componentsJoinedByString:@" "] : device.volumeId;
		if ([device.status length] && ![device.status isEqualToString:@"attached"])
			info = [NSString stringWithFormat:@"%@ (%@)", info, device.status];

		NSString *tooltip = [NSString stringWithFormat:@"Copy Volume ID %@", device.volumeId];
		if ([extras count])
			tooltip = [tooltip stringByAppendingFormat:@"\n%@", [extras componentsJoinedByString:@", "]];

		NSMenuItem *item = [self infoItemWithLabel:(device.deviceName ? device.deviceName : @"Volume")
											  info:info
											action:@selector(copyToPasteboardAction:)
										   tooltip:tooltip];
		[item setRepresentedObject:device.volumeId];   // copied by copyToPasteboardAction:
		[items addObject:item];
	}

	// instance store (ephemeral) disks: not in the block device mapping, so they come
	// from the instance type; one row per disk size, e.g. "2 × 300 GB NVMe SSD"
	EC2InstanceTypeInfo *typeInfo = [[DataSource sharedDataSource] instanceTypeInfoForInstanceType:instance.instanceType];
	if (typeInfo.instanceStorageSupported) {
		BOOL isNVMe = [typeInfo.nvmeSupport isEqualToString:@"supported"] || [typeInfo.nvmeSupport isEqualToString:@"required"];

		NSMutableArray *extras = [NSMutableArray array];
		if (typeInfo.totalSizeInGB > 0)
			[extras addObject:[NSString stringWithFormat:@"%lld GB total", typeInfo.totalSizeInGB]];
		if ([typeInfo.encryptionSupport isEqualToString:@"required"])
			[extras addObject:@"encrypted at rest"];
		[extras addObject:@"data is lost when the instance stops or terminates"];
		NSString *tooltip = [NSString stringWithFormat:@"Instance store (ephemeral): %@", [extras componentsJoinedByString:@", "]];

		for (EC2InstanceStoreDisk *disk in typeInfo.disks) {
			NSMutableArray *parts = [NSMutableArray array];
			[parts addObject:(disk.count > 1
							  ? [NSString stringWithFormat:@"%ld \u00D7 %lld GB", (long)disk.count, disk.sizeInGB]
							  : [NSString stringWithFormat:@"%lld GB", disk.sizeInGB])];
			if (isNVMe)
				[parts addObject:@"NVMe"];
			if ([disk.type length])
				[parts addObject:[disk.type uppercaseString]];

			[items addObject:[self infoItemWithLabel:@"Instance Store"
												info:[parts componentsJoinedByString:@" "]
											  action:NULL
											 tooltip:tooltip]];
		}
	}

	return items;
}

#pragma mark - DataSource operations and notifications

- (BOOL)refresh
{
	DataSource *dataSource = [DataSource sharedDataSource];
    BOOL result = [dataSource refreshCurrentRegionIgnoringAge:NO];
    [dataSource refreshAllRegionsIgnoringAge:NO];
    if ([[NSUserDefaults standardUserDefaults] groupingMode] == kPreferencesGroupingVPC)
        [dataSource refreshVpcsIgnoringAge:NO];   // at most every few minutes
    
    return result;
}

- (BOOL)refreshIgnoringAge
{
	DataSource *dataSource = [DataSource sharedDataSource];
	BOOL result = [dataSource refreshCurrentRegionIgnoringAge:YES];
    [dataSource refreshAllRegionsIgnoringAge:YES];
    if ([[NSUserDefaults standardUserDefaults] groupingMode] == kPreferencesGroupingVPC)
        [dataSource refreshVpcsIgnoringAge:NO];   // VPC names rarely change
    
    return result;
}

- (BOOL)refresh:(NSString *)instanceId
{
	DataSource *dataSource = [DataSource sharedDataSource];
	return [dataSource refreshInstance:instanceId ignoringAge:NO];
}

- (void)refreshCompleted:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSString *refreshType = [userInfo objectForKey:kDataSourceRefreshTypeInfoKey];
    
    if ([refreshType isEqualToString:kDataSourceCurrentRegionRefreshType]) {
        [_statusMenu addItem:[self dummyItem]];
    }
    
	[self performSelector:@selector(refreshMenu:)
			   withObject:notification
			   afterDelay:0.
				  inModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, nil]];

//	[self performSelectorOnMainThread:@selector(refreshMenu:)
//						   withObject:notification
//						waitUntilDone:NO];

//	[self performSelectorOnMainThread:@selector(refreshMenu:)
//						   withObject:notification
//						waitUntilDone:NO
//								modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, nil]];

//	[self refreshMenu:notification];
}

#pragma mark - Menu delegate

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	NSString *instanceId = [menu title];
	if (![instanceId length]) {
		// status menu
		
		[self disableRefreshTimer];

		// refresh all instances only if "Refresh on menu open" is checked
		if ([[NSUserDefaults standardUserDefaults] isRefreshOnMenuOpen]) {
			if ([self refresh]) {
                // data source did start refresh: show instances (also those inside
                // groups) as refreshing until the new list arrives
                for (NSMenuItem *menuItem in [self allInstanceMenuItems]) {
                    [menuItem setImage:[NSImage imageNamed:@"InstanceStateRefreshing"]];
                    [menuItem setSubmenu:nil];
                }
            }
		}
	}
	else {
		// instance submenu
		
		[self refresh:instanceId];
	}
}

- (void)menuWillOpen:(NSMenu *)menu
{
	if (menu == _statusMenu) {
		// the menu's window exists only once tracking starts; focus the field on the next pass
		[self performSelector:@selector(focusSearchField)
				   withObject:nil
				   afterDelay:0.
					  inModes:[NSArray arrayWithObjects:NSEventTrackingRunLoopMode, NSDefaultRunLoopMode, nil]];
	}
}

- (void)menuDidClose:(NSMenu *)menu
{
	NSString *instanceId = [menu title];
	if (![instanceId length]) {
		// status menu

		// start with an empty search next time
		[_searchField setStringValue:@""];
		[self applySearchFilter];
		
		// enable background refresh
		[self enableRefreshTimer];
	}
}

#pragma mark - User Defaults

- (void)loadPreferences
{
	TBTrace(@"reloading preferences");

	[[NSUserDefaults standardUserDefaults] synchronize];

	// set AWS options
	[self setupDataSource];
	
	// setup background refresh timer
	[self enableRefreshTimer];
}

- (void)setupDataSource
{
	NSMutableDictionary *options = [NSMutableDictionary dictionary];
	
	// reload accounts
	[_accountsManager loadAccounts];

	// get selected account
	Account *account = [_accountsManager accountWithId:[[NSUserDefaults standardUserDefaults] accountId]];
	if (!account && [[_accountsManager accounts] count] > 0) {
		// if previously selected account does not exist, get the first one
		account = [[_accountsManager accounts] objectAtIndex:0];
	}
	
	if (account) {
		[[NSUserDefaults standardUserDefaults] setAccountId:account.accountId];
		[options setObject:account.accessKeyID forKey:kAWSAccessKeyIdOption];
		[options setObject:account.secretAccessKey forKey:kAWSSecretAccessKeyOption];
	}
	else {
		// reset credentials in API
		[options setObject:@"" forKey:kAWSAccessKeyIdOption];
		[options setObject:@"" forKey:kAWSSecretAccessKeyOption];
	}
	
	// setup AWS region from user defaults
	NSString *awsRegion = [[NSUserDefaults standardUserDefaults] awsRegion];
	if (awsRegion) {
		[options setObject:awsRegion forKey:kAWSRegionOption];
	}
	
	[DataSource setDefaultRequestOptions:options];
}

- (void)preferencesDidChange:(NSNotification *)notification
{
	TBTrace(@"%@", notification);

	[self loadPreferences];
	[self refreshIgnoringAge];
}

#pragma mark - Background refresh timer

- (void)enableRefreshTimer
{
	TBTrace(@"enabling background refresh");

	NSTimeInterval refreshInterval = [[NSUserDefaults standardUserDefaults] refreshInterval];
	if (refreshInterval > 0) {
		
		if (_refreshTimer) {
			[_refreshTimer invalidate];
			TBRelease(_refreshTimer);
		}
		
		_refreshTimer = [[NSTimer scheduledTimerWithTimeInterval:refreshInterval
														 target:self
													   selector:@selector(timerRefresh:)
													   userInfo:nil
														repeats:YES] retain];
	}
}

- (void)disableRefreshTimer
{
	TBTrace(@"disabling background refresh");

	if (_refreshTimer) {
		[_refreshTimer invalidate];
		TBRelease(_refreshTimer);
	}
}

- (void)timerRefresh:(NSTimer *)timer
{
	[self refresh];
}

#pragma mark - Workspace notifications

- (void)workspaceSessionDidBecomeActive:(NSNotification *)notification
{
	TBTrace(@"performing refresh and enabling background refresh timer");
	
	[self refresh];
	[self enableRefreshTimer];
}

- (void)workspaceSessionDidResignActive:(NSNotification *)notification
{
	TBTrace(@"disabling background refresh timer");
	
	[self disableRefreshTimer];
}

- (void)workspaceDidWake:(NSNotification *)notification
{
	TBTrace(@"scheduling refresh and enabling background refresh timer");

	[self enableRefreshTimer];
	[self performSelector:@selector(refresh) withObject:nil afterDelay:15.0];
}

#pragma mark - Actions

- (void)nopAction:(id)sender
{
}

- (void)selectAccountAction:(id)sender
{
	NSInteger accountId = [sender tag];
	[[NSUserDefaults standardUserDefaults] setAccountId:accountId];
	
    [[DataSource sharedDataSource] reset];
	[self preferencesDidChange:nil];
}

- (void)selectRegionAction:(id)sender
{
	NSInteger region = [sender tag];
	[[NSUserDefaults standardUserDefaults] setRegion:region];
	
	[self preferencesDidChange:nil];
}

- (void)refreshAction:(id)sender
{
	[self refreshIgnoringAge];
}

- (void)quitAction:(id)sender
{
	[[NSApplication sharedApplication] terminate:self];
}

- (void)editPreferencesAction:(id)sender
{
	NSString *preferencesBundlePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:kElasticsPreferencesApplicationPath];
	[[NSWorkspace sharedWorkspace] launchApplication:preferencesBundlePath];
}

- (void)copyToPasteboardAction:(id)sender
{
	NSMenuItem *menuItem = (NSMenuItem *)sender;
	NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
	NSString *value = [menuItem representedObject];
	if (![value isKindOfClass:[NSString class]])
		return;   // nothing to copy
    [pasteBoard clearContents];
	[pasteBoard setString:value forType:NSPasteboardTypeString];
}

// Public DNS name (if preferred), else public IP, else private IP for VPC-only instances.
- (NSString *)connectAddressForInstance:(EC2Instance *)instance
{
	if ([[NSUserDefaults standardUserDefaults] isUsingPublicDNS] && [instance.dnsName length] > 0)
		return instance.dnsName;
	if ([instance.ipAddress length] > 0)
		return instance.ipAddress;
	return instance.privateIpAddress;
}

- (void)connectToInstanceWithSshAction:(id)sender
{
	NSMenuItem *menuItem = (NSMenuItem *)sender;
	NSString *instanceId = [[menuItem menu] title];
	EC2Instance *instance = [[DataSource sharedDataSource] instance:instanceId];
	NSInteger terminalApplication = [[NSUserDefaults standardUserDefaults] terminalApplication];
	BOOL isOpenInTerminalTab = [[NSUserDefaults standardUserDefaults] isOpenInTerminalTab];
	
	if (instance) {
		Account *account = [_accountsManager accountWithId:[[NSUserDefaults standardUserDefaults] accountId]];
		
		NSString *sshPrivateKeyFile = nil;
		if ([account.sshPrivateKeyFile length] > 0)
			sshPrivateKeyFile = account.sshPrivateKeyFile;
		else
			sshPrivateKeyFile = [[NSUserDefaults standardUserDefaults] sshPrivateKeyFile];
		
		NSString *sshUserName = nil;
		if ([account.sshUserName length] > 0)
			sshUserName = account.sshUserName;
		else
			sshUserName = [[NSUserDefaults standardUserDefaults] sshUserName];
        
        NSUInteger sshPort = 0;
		if (account.sshPort > 0)
			sshPort = account.sshPort;
		else
			sshPort = [[NSUserDefaults standardUserDefaults] sshPort];
		
		NSString *sshOptions = nil;
		if ([account.sshOptions length] > 0)
			sshOptions = account.sshOptions;
		else
			sshOptions = [[NSUserDefaults standardUserDefaults] sshOptions];

        NSString *instanceAddress = [self connectAddressForInstance:instance];

		NSString *cmd = @"ssh";

		if (sshPort > 0)
			cmd = [cmd stringByAppendingFormat:@" -p %zd", sshPort];
        
		// every value is quoted as a single shell word, except SSH options, which are
		// deliberately passed through as written (e.g. "-A -o ServerAliveInterval=30")
		if ([sshPrivateKeyFile length] > 0)
			cmd = [cmd stringByAppendingFormat:@" -i %@", ElasticsShellQuote(sshPrivateKeyFile)];
		
		if ([sshOptions length] > 0)
			cmd = [cmd stringByAppendingFormat:@" %@", sshOptions];

		if ([sshUserName length] > 0)
			cmd = [cmd stringByAppendingFormat:@" %@", ElasticsShellQuote([NSString stringWithFormat:@"%@@%@", sshUserName, instanceAddress])];
		else
			cmd = [cmd stringByAppendingFormat:@" %@", ElasticsShellQuote(instanceAddress)];

		// the command goes inside AppleScript string literals below
		NSString *scriptCmd = ElasticsAppleScriptEscape(cmd);

		switch (terminalApplication) {
			// use iTerm terminal
			case kPreferencesTerminalApplicationiTerm:
            {
                NSString *new = nil;
                NSString *old = nil;

				if (isOpenInTerminalTab) {
					// new iTerm tab

                    // for iTerm 3+
                    new = [NSString stringWithFormat:
                           @"activate\n"
                           @"if current window is missing value then\n"
                           @"   create window with default profile\n"
                           @"end if\n"
                           @"tell current window\n"
                           @"    set newTab to create tab with default profile\n"
                           @"    tell newTab\n"
                           @"        tell current session\n"
                           @"            write text \"%@\"\n"
                           @"        end tell\n"
                           @"    end tell\n"
                           @"end tell",
                           scriptCmd];

                    // for older version
                    old = [NSString stringWithFormat:
                           @"	activate\n"
                           @"	try\n"
                           @"		set myterm to (current terminal)\n"
                           @"		tell myterm\n"
                           @"			launch session \"Default Session\"\n"
                           @"			tell the last session\n"
                           @"				write text \"%@\"\n"
                           @"			end tell\n"
                           @"		end tell\n"
                           @"	on error\n"
                           @"		set myterm to (make new terminal)\n"
                           @"		tell myterm\n"
                           @"			launch session \"Default Session\"\n"
                           @"			tell the last session\n"
                           @"				write text \"%@\"\n"
                           @"			end tell\n"
                           @"		end tell\n"
                           @"	end try",
                           scriptCmd, scriptCmd];
                }
				else {
					// new iTerm window

                    // for iTerm 3+
                    new = [NSString stringWithFormat:
                           @"activate\n"
                           @"set newWindow to create window with default profile\n"
                           @"tell newWindow\n"
                           @"    tell current session\n"
                           @"        write text \"%@\"\n"
                           @"    end tell\n"
                           @"end tell",
                           scriptCmd];

                    // for older versions
                    old = [NSString stringWithFormat:
                           @"	activate\n"
                           @"	set myterm to (make new terminal)\n"
                           @"	tell myterm\n"
                           @"		launch session \"Default Session\"\n"
                           @"		tell the last session\n"
                           @"			write text \"%@\"\n"
                           @"		end tell\n"
                           @"	end tell",
                           scriptCmd];
                }

                // these scripts are themselves embedded in string literals below
                new = ElasticsAppleScriptEscape(new);
                old = ElasticsAppleScriptEscape(old);

                cmd = [NSString stringWithFormat:
                       @"on theSplit(theString, theDelimiter)\n"
                       @"    set oldDelimiters to AppleScript's text item delimiters\n"
                       @"    set AppleScript's text item delimiters to theDelimiter\n"
                       @"    set theArray to every text item of theString\n"
                       @"    set AppleScript's text item delimiters to oldDelimiters\n"
                       @"    return theArray\n"
                       @"end theSplit\n"
                       @"\n"
                       @"on IsModernVersion(version)\n"
                       @"    set myArray to my theSplit(version, \".\")\n"
                       @"    set major to item 1 of myArray\n"
                       @"    set minor to item 2 of myArray\n"
                       @"    set veryMinor to item 3 of myArray\n"
                       @"    \n"
                       @"    if major < 2 then\n"
                       @"        return false\n"
                       @"    end if\n"
                       @"    if major > 2 then\n"
                       @"        return true\n"
                       @"    end if\n"
                       @"    if minor < 9 then\n"
                       @"        return false\n"
                       @"    end if\n"
                       @"    if minor > 9 then\n"
                       @"        return true\n"
                       @"    end if\n"
                       @"    if veryMinor < 20140903 then\n"
                       @"        return false\n"
                       @"    end if\n"
                       @"    return true\n"
                       @"end IsModernVersion\n"
                       @"\n"
                       @"on NewScript()\n"
                       @"    return \"%@\"\n"
                       @"end NewScript\n"
                       @"\n"
                       @"on OldScript()\n"
                       @"    return \"%@\"\n"
                       @"end OldScript\n"
                       @"\n"
                       @"tell application \"iTerm\"\n"
                       @"    if my IsModernVersion(version) then\n"
                       @"        set myScript to my NewScript()\n"
                       @"    else\n"
                       @"        set myScript to my OldScript()\n"
                       @"    end if\n"
                       @"end tell\n"
                       @"\n"
                       @"set fullScript to \"tell application \\\"iTerm\\\"\n"
                       @"\" & myScript & \"\n"
                       @"end tell\"\n"
                       @"\n"
                       @"run script fullScript",
                       new, old];
				break;
            }

			// use Terminal terminal
			default:
				if (isOpenInTerminalTab) {
					// new Terminal tab
					
					cmd = [NSString stringWithFormat:
						   @"activate application \"Terminal\"\n"
						   @"tell application \"System Events\"\n"
						   @"	keystroke \"t\" using {command down}\n"
						   @"end tell\n"
						   @"tell application \"Terminal\"\n"
						   @"	repeat with win in windows\n"
						   @"	try\n"
						   @"		if get frontmost of win is true then\n"
						   @"			do script \"%@\" in (selected tab of win)\n"
						   @"		end if\n"
						   @"	end try\n"
						   @"	end repeat\n"
						   @"end tell",
						   scriptCmd];
				}
				else {
					// new Terminal window
					
					cmd = [NSString stringWithFormat:
						   @"tell application \"Terminal\"\n"
						   @"	do script \"%@\"\n"
						   @"end tell",
						   scriptCmd];
				}
				break;
		}
		
		TBTrace(@"%@", cmd);

		NSAppleScript *appleScript = [[[NSAppleScript alloc] initWithSource:cmd] autorelease];
		NSDictionary *errorInfo = nil;
		[appleScript executeAndReturnError:&errorInfo];

		// TODO: handle errors
	}
}

- (void)connectToInstanceWithRdpAction:(id)sender
{
	NSMenuItem *menuItem = (NSMenuItem *)sender;
	NSString *instanceId = [[menuItem menu] title];
	EC2Instance *instance = [[DataSource sharedDataSource] instance:instanceId];
	
	if (instance) {
		// NSInteger rdpApplication = [[NSUserDefaults standardUserDefaults] rdpApplication];
		// TODO: switch ...
		
		NSString *cmd = nil;
        NSString *instanceAddress = [self connectAddressForInstance:instance];

		cmd = [NSString stringWithFormat:
			   @"tell application \"Finder\" to set the clipboard to \"%@\"\n"
			   @"tell application \"CoRD\" to activate\n"
			   @"tell application \"System Events\"\n"
			   @"	keystroke \"g\" using command down\n"
			   @"	keystroke \"v\" using command down\n"
			   @"	do shell script \"sleep 1\"\n"
			   @"	keystroke return\n"
			   @"end tell\n",
			   ElasticsAppleScriptEscape(instanceAddress)];

		TBTrace(@"%@", cmd);
		
		NSAppleScript *appleScript = [[[NSAppleScript alloc] initWithSource:cmd] autorelease];
		NSDictionary *errorInfo = nil;
		[appleScript executeAndReturnError:&errorInfo];
		
		// TODO: handle errors
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
	[_aboutCopyrightLabel setAttributedStringValue:copyright];
	[copyright release];
	
	[_aboutPanel makeKeyAndOrderFront:self];
}

- (void)openAWSManagementConsoleAction:(id)sender
{
    NSString *awsRegion = [[NSUserDefaults standardUserDefaults] awsRegion];
    NSString *urlString = [NSString stringWithFormat:@"https://console.aws.amazon.com/ec2/home?region=%@", awsRegion];

	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

@end
