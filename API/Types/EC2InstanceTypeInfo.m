//
//  EC2InstanceTypeInfo.m
//  Elastics
//
//  Element names are compared case-insensitively: the API reference lists these
//  members as Disks/SizeInGB/Count/Type while EC2 XML responses use lowerCamelCase.
//

#import "EC2InstanceTypeInfo.h"

static BOOL EC2ElementIs(NSString *elementName, NSString *name)
{
	return [elementName caseInsensitiveCompare:name] == NSOrderedSame;
}

@interface EC2InstanceStoreDisk ()
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, assign) long long sizeInGB;
@property (nonatomic, retain) NSString *type;
@end

@implementation EC2InstanceStoreDisk

@synthesize count = _count;
@synthesize sizeInGB = _sizeInGB;
@synthesize type = _type;

- (id)initFromXMLElement:(TBXMLElement *)element parent:(AWSType *)parent
{
	self = [super initFromXMLElement:element parent:parent];

	if (self) {
		element = element->firstChild;

		while (element) {
			NSString *elementName = [TBXML elementName:element];

			if (EC2ElementIs(elementName, @"count"))
				self.count = [[TBXML textForElement:element] integerValue];
			else if (EC2ElementIs(elementName, @"sizeInGB"))
				self.sizeInGB = [[TBXML textForElement:element] longLongValue];
			else if (EC2ElementIs(elementName, @"type"))
				self.type = [TBXML textForElement:element];

			element = element->nextSibling;
		}
	}

	return self;
}

- (void)dealloc
{
	TBRelease(_type);
	[super dealloc];
}

@end

@interface EC2InstanceTypeInfo ()
@property (nonatomic, retain) NSString *instanceType;
@property (nonatomic, assign) BOOL instanceStorageSupported;
@property (nonatomic, assign) long long totalSizeInGB;
@property (nonatomic, retain) NSString *nvmeSupport;
@property (nonatomic, retain) NSString *encryptionSupport;
@property (nonatomic, retain) NSArray *disks;
@end

@implementation EC2InstanceTypeInfo

@synthesize instanceType = _instanceType;
@synthesize instanceStorageSupported = _instanceStorageSupported;
@synthesize totalSizeInGB = _totalSizeInGB;
@synthesize nvmeSupport = _nvmeSupport;
@synthesize encryptionSupport = _encryptionSupport;
@synthesize disks = _disks;

- (id)initFromXMLElement:(TBXMLElement *)element parent:(AWSType *)parent
{
	self = [super initFromXMLElement:element parent:parent];

	if (self) {
		element = element->firstChild;

		while (element) {
			NSString *elementName = [TBXML elementName:element];

			if (EC2ElementIs(elementName, @"instanceType")) {
				self.instanceType = [TBXML textForElement:element];
			}
			else if (EC2ElementIs(elementName, @"instanceStorageSupported")) {
				self.instanceStorageSupported = [[TBXML textForElement:element] isEqualToString:@"true"];
			}
			else if (EC2ElementIs(elementName, @"instanceStorageInfo")) {
				TBXMLElement *storageElement = element->firstChild;
				while (storageElement) {
					NSString *storageElementName = [TBXML elementName:storageElement];

					if (EC2ElementIs(storageElementName, @"totalSizeInGB"))
						self.totalSizeInGB = [[TBXML textForElement:storageElement] longLongValue];
					else if (EC2ElementIs(storageElementName, @"nvmeSupport"))
						self.nvmeSupport = [TBXML textForElement:storageElement];
					else if (EC2ElementIs(storageElementName, @"encryptionSupport"))
						self.encryptionSupport = [TBXML textForElement:storageElement];
					else if (EC2ElementIs(storageElementName, @"disks"))
						self.disks = [self parseElement:storageElement asArrayOf:[EC2InstanceStoreDisk class]];

					storageElement = storageElement->nextSibling;
				}
			}

			element = element->nextSibling;
		}
	}

	return self;
}

- (void)dealloc
{
	TBRelease(_instanceType);
	TBRelease(_nvmeSupport);
	TBRelease(_encryptionSupport);
	TBRelease(_disks);
	[super dealloc];
}

@end
