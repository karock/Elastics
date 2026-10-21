//
//  EC2BlockDevice.m
//  Elastics
//

#import "EC2BlockDevice.h"
#import "NSString+DateConversions.h"

@interface EC2BlockDevice ()
@property (nonatomic, retain) NSString *deviceName;
@property (nonatomic, retain) NSString *volumeId;
@property (nonatomic, retain) NSString *status;
@property (nonatomic, retain) NSDate *attachTime;
@property (nonatomic, assign) BOOL deleteOnTermination;
@end

@implementation EC2BlockDevice

@synthesize deviceName = _deviceName;
@synthesize volumeId = _volumeId;
@synthesize status = _status;
@synthesize attachTime = _attachTime;
@synthesize deleteOnTermination = _deleteOnTermination;

- (id)initFromXMLElement:(TBXMLElement *)element parent:(AWSType *)parent
{
	self = [super initFromXMLElement:element parent:parent];

	if (self) {
		element = element->firstChild;

		while (element) {
			NSString *elementName = [TBXML elementName:element];

			if ([elementName isEqualToString:@"deviceName"]) {
				self.deviceName = [TBXML textForElement:element];
			}
			else if ([elementName isEqualToString:@"ebs"]) {
				TBXMLElement *ebsElement = element->firstChild;
				while (ebsElement) {
					NSString *ebsElementName = [TBXML elementName:ebsElement];

					if ([ebsElementName isEqualToString:@"volumeId"])
						self.volumeId = [TBXML textForElement:ebsElement];
					else if ([ebsElementName isEqualToString:@"status"])
						self.status = [TBXML textForElement:ebsElement];
					else if ([ebsElementName isEqualToString:@"attachTime"])
						self.attachTime = [[TBXML textForElement:ebsElement] iso8601Date];
					else if ([ebsElementName isEqualToString:@"deleteOnTermination"])
						self.deleteOnTermination = [[TBXML textForElement:ebsElement] isEqualToString:@"true"];

					ebsElement = ebsElement->nextSibling;
				}
			}

			element = element->nextSibling;
		}
	}

	return self;
}

- (void)dealloc
{
	TBRelease(_deviceName);
	TBRelease(_volumeId);
	TBRelease(_status);
	TBRelease(_attachTime);
	[super dealloc];
}

@end
