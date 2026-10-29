//
//  EC2Vpc.m
//  Elastics
//

#import "EC2Vpc.h"
#import "EC2Tag.h"

@interface EC2Vpc ()
@property (nonatomic, retain) NSString *vpcId;
@property (nonatomic, retain) NSString *cidrBlock;
@property (nonatomic, assign) BOOL isDefault;
@property (nonatomic, retain) NSArray *tagSet;
@end

@implementation EC2Vpc

@synthesize vpcId = _vpcId;
@synthesize cidrBlock = _cidrBlock;
@synthesize isDefault = _isDefault;
@synthesize tagSet = _tagSet;

- (id)initFromXMLElement:(TBXMLElement *)element parent:(AWSType *)parent
{
	self = [super initFromXMLElement:element parent:parent];

	if (self) {
		element = element->firstChild;

		while (element) {
			NSString *elementName = [TBXML elementName:element];

			if ([elementName isEqualToString:@"vpcId"])
				self.vpcId = [TBXML textForElement:element];
			else if ([elementName isEqualToString:@"cidrBlock"])
				self.cidrBlock = [TBXML textForElement:element];
			else if ([elementName isEqualToString:@"isDefault"])
				self.isDefault = [[TBXML textForElement:element] isEqualToString:@"true"];
			else if ([elementName isEqualToString:@"tagSet"])
				self.tagSet = [self parseElement:element asArrayOf:[EC2Tag class]];

			element = element->nextSibling;
		}
	}

	return self;
}

- (void)dealloc
{
	TBRelease(_vpcId);
	TBRelease(_cidrBlock);
	TBRelease(_tagSet);
	[super dealloc];
}

- (NSString *)title
{
	for (EC2Tag *tag in _tagSet) {
		if ([tag.key compare:@"Name" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
			NSString *name = [tag.value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if ([name length])
				return name;
		}
	}
	return _isDefault ? @"Default VPC" : _vpcId;
}

@end
