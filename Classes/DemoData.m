//
//  DemoData.m
//  Elastics
//
//  Every name, ID and address here is invented. IP addresses come from the ranges
//  reserved for documentation (RFC 1918 private 10.x and RFC 5737 TEST-NET-3), and
//  the account ID is the one AWS uses in its own documentation.
//

#import "DemoData.h"
#include <math.h>

static NSString *const kDemoOwnerId = @"123456789012";

static NSString *DemoEscape(NSString *value)
{
	NSString *escaped = [value stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	return [escaped stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
}

// CloudWatch timestamps have no fractional seconds
static NSString *DemoCloudWatchDate(NSDate *date)
{
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
	[formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	[formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
	return [formatter stringFromDate:date];
}

static NSString *DemoISODate(NSDate *date)
{
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
	[formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	[formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
	return [formatter stringFromDate:date];
}

// IDs that look like real ones: prefix + 17 hex digits
static NSString *DemoId(NSString *prefix, NSUInteger index)
{
	unsigned long long value = 0x0a3f5c7e91b2d400ULL + (unsigned long long)index * 0x1d3f2b7a5ULL;
	return [NSString stringWithFormat:@"%@-0%016llx", prefix, value];
}

#pragma mark - Demo fleet

// VPCs: key -> @[id index, Name tag ("" for the default VPC), CIDR]
static NSDictionary *DemoVpcs(void)
{
	return @{
		@"prod":    @[@1, @"production", @"10.0.0.0/16"],
		@"staging": @[@2, @"staging", @"10.1.0.0/16"],
		@"default": @[@3, @"", @"172.31.0.0/16"],
		@"dr":      @[@4, @"production-dr", @"10.10.0.0/16"],
		@"eu":      @[@5, @"production-eu", @"10.20.0.0/16"],
	};
}

// Instances. Keys: name region type state env team vpc ip [publicIp] [asg] [stack]
// [lifecycle] [platform] [volumes: @[@[device, sizeGiB, type, iops, throughput], ...]]
// days (since launch), cpu (typical %), [reason]
static NSArray *DemoInstances(void)
{
	static NSArray *instances = nil;
	if (instances)
		return instances;

	NSArray *root = @[@"/dev/xvda", @30, @"gp3", @3000, @125];
	instances = [@[
		// us-east-1: production
		@{@"name": @"prod-web-1", @"region": @"us-east-1", @"az": @"a", @"type": @"c7g.xlarge", @"state": @"running", @"env": @"production", @"team": @"web", @"vpc": @"prod", @"ip": @"10.0.1.21", @"asg": @"prod-web-asg", @"stack": @"web-production", @"volumes": @[root], @"days": @12, @"cpu": @48},
		@{@"name": @"prod-web-2", @"region": @"us-east-1", @"az": @"b", @"type": @"c7g.xlarge", @"state": @"running", @"env": @"production", @"team": @"web", @"vpc": @"prod", @"ip": @"10.0.2.37", @"asg": @"prod-web-asg", @"stack": @"web-production", @"volumes": @[root], @"days": @12, @"cpu": @52},
		@{@"name": @"prod-web-3", @"region": @"us-east-1", @"az": @"c", @"type": @"c7g.xlarge", @"state": @"running", @"env": @"production", @"team": @"web", @"vpc": @"prod", @"ip": @"10.0.3.14", @"asg": @"prod-web-asg", @"stack": @"web-production", @"volumes": @[root], @"days": @3, @"cpu": @45},
		@{@"name": @"prod-api-1", @"region": @"us-east-1", @"az": @"a", @"type": @"m7g.large", @"state": @"running", @"env": @"production", @"team": @"api", @"vpc": @"prod", @"ip": @"10.0.1.52", @"asg": @"prod-api-asg", @"stack": @"api-production", @"volumes": @[root], @"days": @21, @"cpu": @38},
		@{@"name": @"prod-api-2", @"region": @"us-east-1", @"az": @"b", @"type": @"m7g.large", @"state": @"running", @"env": @"production", @"team": @"api", @"vpc": @"prod", @"ip": @"10.0.2.61", @"asg": @"prod-api-asg", @"stack": @"api-production", @"volumes": @[root], @"days": @21, @"cpu": @41},
		@{@"name": @"prod-db-1", @"region": @"us-east-1", @"az": @"a", @"type": @"r6g.2xlarge", @"state": @"running", @"env": @"production", @"team": @"data", @"vpc": @"prod", @"ip": @"10.0.1.100", @"volumes": @[@[@"/dev/xvda", @50, @"gp3", @3000, @125], @[@"/dev/sdf", @1000, @"io2", @16000, @0]], @"days": @187, @"cpu": @27},
		@{@"name": @"prod-cache-1", @"region": @"us-east-1", @"az": @"a", @"type": @"r7g.large", @"state": @"running", @"env": @"production", @"team": @"data", @"vpc": @"prod", @"ip": @"10.0.1.110", @"volumes": @[root], @"days": @94, @"cpu": @12},
		@{@"name": @"prod-worker-1", @"region": @"us-east-1", @"az": @"b", @"type": @"m5d.large", @"state": @"running", @"env": @"production", @"team": @"data", @"vpc": @"prod", @"ip": @"10.0.2.88", @"lifecycle": @"spot", @"volumes": @[root], @"days": @1, @"cpu": @71},
		@{@"name": @"bastion", @"region": @"us-east-1", @"az": @"a", @"type": @"t3.micro", @"state": @"running", @"env": @"production", @"team": @"platform", @"vpc": @"prod", @"ip": @"10.0.0.10", @"publicIp": @"203.0.113.10", @"volumes": @[@[@"/dev/xvda", @8, @"gp3", @3000, @125]], @"days": @310, @"cpu": @2},
		// us-east-1: staging
		@{@"name": @"staging-web-1", @"region": @"us-east-1", @"az": @"a", @"type": @"t3.large", @"state": @"running", @"env": @"staging", @"team": @"web", @"vpc": @"staging", @"ip": @"10.1.1.20", @"stack": @"web-staging", @"volumes": @[root], @"days": @6, @"cpu": @9},
		@{@"name": @"staging-api-1", @"region": @"us-east-1", @"az": @"a", @"type": @"t3.large", @"state": @"running", @"env": @"staging", @"team": @"api", @"vpc": @"staging", @"ip": @"10.1.1.30", @"stack": @"api-staging", @"volumes": @[root], @"days": @6, @"cpu": @7},
		@{@"name": @"staging-db-1", @"region": @"us-east-1", @"az": @"a", @"type": @"r6g.large", @"state": @"stopped", @"env": @"staging", @"team": @"data", @"vpc": @"staging", @"ip": @"10.1.1.100", @"volumes": @[@[@"/dev/xvda", @50, @"gp3", @3000, @125], @[@"/dev/sdf", @200, @"gp3", @3000, @250]], @"days": @40, @"cpu": @0, @"reason": @"Client.UserInitiatedShutdown: User initiated shutdown"},
		// us-east-1: development and tooling (default VPC)
		@{@"name": @"dev-sandbox", @"region": @"us-east-1", @"az": @"c", @"type": @"t3.medium", @"state": @"running", @"env": @"development", @"team": @"platform", @"vpc": @"default", @"ip": @"172.31.20.15", @"volumes": @[root], @"days": @15, @"cpu": @4},
		@{@"name": @"ci-runner-1", @"region": @"us-east-1", @"az": @"c", @"type": @"c6i.xlarge", @"state": @"running", @"env": @"development", @"team": @"platform", @"vpc": @"default", @"ip": @"172.31.20.41", @"lifecycle": @"spot", @"volumes": @[@[@"/dev/xvda", @100, @"gp3", @3000, @125]], @"days": @0, @"cpu": @63},
		@{@"name": @"ci-runner-2", @"region": @"us-east-1", @"az": @"c", @"type": @"c6i.xlarge", @"state": @"running", @"env": @"development", @"team": @"platform", @"vpc": @"default", @"ip": @"172.31.20.42", @"lifecycle": @"spot", @"volumes": @[@[@"/dev/xvda", @100, @"gp3", @3000, @125]], @"days": @0, @"cpu": @58},
		@{@"name": @"analytics-etl", @"region": @"us-east-1", @"az": @"b", @"type": @"i4i.large", @"state": @"stopped", @"env": @"development", @"team": @"data", @"vpc": @"default", @"ip": @"172.31.10.77", @"volumes": @[root], @"days": @60, @"cpu": @0, @"reason": @"Client.UserInitiatedShutdown: User initiated shutdown"},
		@{@"name": @"win-reporting", @"region": @"us-east-1", @"az": @"a", @"type": @"m6i.large", @"state": @"running", @"env": @"production", @"team": @"finance", @"vpc": @"default", @"ip": @"172.31.5.9", @"platform": @"windows", @"volumes": @[@[@"/dev/sda1", @60, @"gp3", @3000, @125]], @"days": @120, @"cpu": @15},
		@{@"name": @"old-api-1", @"region": @"us-east-1", @"az": @"a", @"type": @"t3.medium", @"state": @"terminated", @"env": @"staging", @"team": @"api", @"vpc": @"staging", @"ip": @"", @"volumes": @[], @"days": @200, @"cpu": @0, @"reason": @"Client.UserInitiatedShutdown: User initiated shutdown"},
		// us-west-2
		@{@"name": @"dr-web-1", @"region": @"us-west-2", @"az": @"a", @"type": @"c7g.large", @"state": @"running", @"env": @"production", @"team": @"web", @"vpc": @"dr", @"ip": @"10.10.1.21", @"volumes": @[root], @"days": @45, @"cpu": @6},
		@{@"name": @"dr-web-2", @"region": @"us-west-2", @"az": @"b", @"type": @"c7g.large", @"state": @"running", @"env": @"production", @"team": @"web", @"vpc": @"dr", @"ip": @"10.10.2.21", @"volumes": @[root], @"days": @45, @"cpu": @5},
		@{@"name": @"dr-db-1", @"region": @"us-west-2", @"az": @"a", @"type": @"r6g.xlarge", @"state": @"stopped", @"env": @"production", @"team": @"data", @"vpc": @"dr", @"ip": @"10.10.1.100", @"volumes": @[@[@"/dev/xvda", @50, @"gp3", @3000, @125]], @"days": @45, @"cpu": @0, @"reason": @"Client.UserInitiatedShutdown: User initiated shutdown"},
		// eu-west-1
		@{@"name": @"eu-web-1", @"region": @"eu-west-1", @"az": @"a", @"type": @"c7g.large", @"state": @"running", @"env": @"production", @"team": @"web", @"vpc": @"eu", @"ip": @"10.20.1.21", @"volumes": @[root], @"days": @30, @"cpu": @33},
		@{@"name": @"eu-api-1", @"region": @"eu-west-1", @"az": @"b", @"type": @"m7g.large", @"state": @"running", @"env": @"production", @"team": @"api", @"vpc": @"eu", @"ip": @"10.20.2.31", @"volumes": @[root], @"days": @30, @"cpu": @29},
	] retain];
	return instances;
}

static NSUInteger DemoIndexOfInstanceId(NSString *instanceId)
{
	NSArray *instances = DemoInstances();
	for (NSUInteger i = 0; i < [instances count]; i++) {
		if ([DemoId(@"i", i) isEqualToString:instanceId])
			return i;
	}
	return NSNotFound;
}

static NSInteger DemoStateCode(NSString *state)
{
	if ([state isEqualToString:@"running"])		return 16;
	if ([state isEqualToString:@"stopped"])		return 80;
	if ([state isEqualToString:@"terminated"])	return 48;
	return 0;
}

#pragma mark - Responses

static NSString *DemoTag(NSString *key, NSString *value)
{
	return [NSString stringWithFormat:@"<item><key>%@</key><value>%@</value></item>", DemoEscape(key), DemoEscape(value)];
}

static NSData *DemoDescribeInstances(NSString *region)
{
	NSArray *instances = DemoInstances();
	NSDictionary *vpcs = DemoVpcs();
	NSMutableString *xml = [NSMutableString stringWithString:
		@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<DescribeInstancesResponse xmlns=\"http://ec2.amazonaws.com/doc/2016-11-15/\">"
		@"<requestId>demo</requestId><reservationSet>"];

	for (NSUInteger i = 0; i < [instances count]; i++) {
		NSDictionary *instance = [instances objectAtIndex:i];
		if (![[instance objectForKey:@"region"] isEqualToString:region])
			continue;

		NSString *state = [instance objectForKey:@"state"];
		BOOL running = [state isEqualToString:@"running"];
		NSString *vpcId = DemoId(@"vpc", [[[vpcs objectForKey:[instance objectForKey:@"vpc"]] objectAtIndex:0] unsignedIntegerValue]);
		NSDate *launch = [NSDate dateWithTimeIntervalSinceNow:-([[instance objectForKey:@"days"] doubleValue] * 86400.0 + 3600.0 * (i % 7 + 1))];
		NSString *ip = [instance objectForKey:@"ip"];
		NSString *publicIp = [instance objectForKey:@"publicIp"];

		[xml appendFormat:@"<item><reservationId>%@</reservationId><ownerId>%@</ownerId><groupSet/><instancesSet><item>", DemoId(@"r", i), kDemoOwnerId];
		[xml appendFormat:@"<instanceId>%@</instanceId><imageId>%@</imageId>", DemoId(@"i", i), DemoId(@"ami", i % 5)];
		[xml appendFormat:@"<instanceState><code>%ld</code><name>%@</name></instanceState>", (long)DemoStateCode(state), state];
		[xml appendFormat:@"<privateDnsName>%@</privateDnsName><dnsName>%@</dnsName>",
			[ip length] ? [NSString stringWithFormat:@"ip-%@.ec2.internal", [ip stringByReplacingOccurrencesOfString:@"." withString:@"-"]] : @"",
			(publicIp && running) ? [NSString stringWithFormat:@"ec2-%@.compute-1.amazonaws.com", [publicIp stringByReplacingOccurrencesOfString:@"." withString:@"-"]] : @""];
		if ([instance objectForKey:@"reason"])
			[xml appendFormat:@"<reason>User initiated (%@)</reason>", [DemoISODate([NSDate dateWithTimeIntervalSinceNow:-86400.0 * 2]) substringToIndex:10]];
		[xml appendFormat:@"<keyName>%@-key</keyName><instanceType>%@</instanceType><launchTime>%@</launchTime>",
			[instance objectForKey:@"env"], [instance objectForKey:@"type"], DemoISODate(launch)];
		[xml appendFormat:@"<placement><availabilityZone>%@%@</availabilityZone><tenancy>default</tenancy></placement>", region, [instance objectForKey:@"az"]];
		if ([instance objectForKey:@"platform"])
			[xml appendFormat:@"<platform>%@</platform>", [instance objectForKey:@"platform"]];
		[xml appendFormat:@"<monitoring><state>%@</state></monitoring>", [[instance objectForKey:@"env"] isEqualToString:@"production"] ? @"enabled" : @"disabled"];
		[xml appendFormat:@"<subnetId>%@</subnetId><vpcId>%@</vpcId>", DemoId(@"subnet", i % 6), vpcId];
		if ([ip length])
			[xml appendFormat:@"<privateIpAddress>%@</privateIpAddress>", ip];
		if (publicIp && running)
			[xml appendFormat:@"<ipAddress>%@</ipAddress>", publicIp];
		[xml appendFormat:@"<groupSet><item><groupId>%@</groupId><groupName>%@-%@</groupName></item></groupSet>",
			DemoId(@"sg", i % 4), [instance objectForKey:@"env"], [instance objectForKey:@"team"]];
		if ([instance objectForKey:@"reason"])
			[xml appendFormat:@"<stateReason><code>Client.UserInitiatedShutdown</code><message>%@</message></stateReason>", [instance objectForKey:@"reason"]];

		NSArray *volumes = [instance objectForKey:@"volumes"];
		NSString *rootDevice = [volumes count] ? [[volumes objectAtIndex:0] objectAtIndex:0] : @"/dev/xvda";
		[xml appendFormat:@"<architecture>%@</architecture><rootDeviceType>ebs</rootDeviceType><rootDeviceName>%@</rootDeviceName>",
			[[instance objectForKey:@"type"] rangeOfString:@"g."].location != NSNotFound ? @"arm64" : @"x86_64", rootDevice];
		[xml appendString:@"<blockDeviceMapping>"];
		for (NSUInteger v = 0; v < [volumes count]; v++) {
			[xml appendFormat:@"<item><deviceName>%@</deviceName><ebs><volumeId>%@</volumeId><status>attached</status><attachTime>%@</attachTime><deleteOnTermination>%@</deleteOnTermination></ebs></item>",
				[[volumes objectAtIndex:v] objectAtIndex:0], DemoId(@"vol", i * 10 + v), DemoISODate(launch), v == 0 ? @"true" : @"false"];
		}
		[xml appendString:@"</blockDeviceMapping>"];
		if ([instance objectForKey:@"lifecycle"])
			[xml appendFormat:@"<instanceLifecycle>%@</instanceLifecycle>", [instance objectForKey:@"lifecycle"]];

		[xml appendString:@"<tagSet>"];
		[xml appendString:DemoTag(@"Name", [instance objectForKey:@"name"])];
		[xml appendString:DemoTag(@"Environment", [instance objectForKey:@"env"])];
		[xml appendString:DemoTag(@"Team", [instance objectForKey:@"team"])];
		[xml appendString:DemoTag(@"CostCenter", [NSString stringWithFormat:@"cc-%@", [instance objectForKey:@"team"]])];
		if ([instance objectForKey:@"asg"])
			[xml appendString:DemoTag(@"aws:autoscaling:groupName", [instance objectForKey:@"asg"])];
		if ([instance objectForKey:@"stack"]) {
			[xml appendString:DemoTag(@"aws:cloudformation:stack-name", [instance objectForKey:@"stack"])];
			[xml appendString:DemoTag(@"aws:cloudformation:logical-id", @"InstanceGroup")];
		}
		[xml appendString:@"</tagSet>"];

		[xml appendString:@"</item></instancesSet></item>"];
	}

	[xml appendString:@"</reservationSet></DescribeInstancesResponse>"];
	return [xml dataUsingEncoding:NSUTF8StringEncoding];
}

static NSData *DemoDescribeVpcs(NSString *region)
{
	NSDictionary *vpcs = DemoVpcs();
	NSMutableSet *keys = [NSMutableSet set];
	for (NSDictionary *instance in DemoInstances()) {
		if ([[instance objectForKey:@"region"] isEqualToString:region])
			[keys addObject:[instance objectForKey:@"vpc"]];
	}

	NSMutableString *xml = [NSMutableString stringWithString:
		@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<DescribeVpcsResponse xmlns=\"http://ec2.amazonaws.com/doc/2016-11-15/\"><requestId>demo</requestId><vpcSet>"];
	for (NSString *key in keys) {
		NSArray *vpc = [vpcs objectForKey:key];
		NSString *name = [vpc objectAtIndex:1];
		[xml appendFormat:@"<item><vpcId>%@</vpcId><state>available</state><cidrBlock>%@</cidrBlock><isDefault>%@</isDefault>",
			DemoId(@"vpc", [[vpc objectAtIndex:0] unsignedIntegerValue]), [vpc objectAtIndex:2], [name length] ? @"false" : @"true"];
		if ([name length])
			[xml appendFormat:@"<tagSet>%@</tagSet>", DemoTag(@"Name", name)];
		[xml appendString:@"</item>"];
	}
	[xml appendString:@"</vpcSet></DescribeVpcsResponse>"];
	return [xml dataUsingEncoding:NSUTF8StringEncoding];
}

static NSData *DemoDescribeVolumes(NSDictionary *parameters)
{
	NSString *instanceId = [parameters objectForKey:@"Filter.1.Value.1"];
	NSUInteger index = DemoIndexOfInstanceId(instanceId);

	NSMutableString *xml = [NSMutableString stringWithString:
		@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<DescribeVolumesResponse xmlns=\"http://ec2.amazonaws.com/doc/2016-11-15/\"><requestId>demo</requestId><volumeSet>"];
	if (index != NSNotFound) {
		NSArray *volumes = [[DemoInstances() objectAtIndex:index] objectForKey:@"volumes"];
		for (NSUInteger v = 0; v < [volumes count]; v++) {
			NSArray *volume = [volumes objectAtIndex:v];
			[xml appendFormat:@"<item><volumeId>%@</volumeId><size>%@</size><volumeType>%@</volumeType>", DemoId(@"vol", index * 10 + v), [volume objectAtIndex:1], [volume objectAtIndex:2]];
			if ([[volume objectAtIndex:3] integerValue] > 0)
				[xml appendFormat:@"<iops>%@</iops>", [volume objectAtIndex:3]];
			if ([[volume objectAtIndex:4] integerValue] > 0)
				[xml appendFormat:@"<throughput>%@</throughput>", [volume objectAtIndex:4]];
			[xml appendString:@"<encrypted>true</encrypted><status>in-use</status></item>"];
		}
	}
	[xml appendString:@"</volumeSet></DescribeVolumesResponse>"];
	return [xml dataUsingEncoding:NSUTF8StringEncoding];
}

static NSData *DemoDescribeInstanceTypes(NSDictionary *parameters)
{
	NSString *instanceType = [parameters objectForKey:@"InstanceType.1"];
	// instance store sizes for the demo types that have one
	NSDictionary *instanceStore = @{
		@"m5d.large": @[@1, @75],
		@"i4i.large": @[@1, @468],
	};
	NSArray *disks = [instanceStore objectForKey:instanceType];

	NSMutableString *xml = [NSMutableString stringWithString:
		@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<DescribeInstanceTypesResponse xmlns=\"http://ec2.amazonaws.com/doc/2016-11-15/\"><requestId>demo</requestId><instanceTypeSet>"];
	if (instanceType) {
		[xml appendFormat:@"<item><instanceType>%@</instanceType><instanceStorageSupported>%@</instanceStorageSupported>", instanceType, disks ? @"true" : @"false"];
		if (disks) {
			long long count = [[disks objectAtIndex:0] longLongValue], size = [[disks objectAtIndex:1] longLongValue];
			[xml appendFormat:@"<instanceStorageInfo><totalSizeInGB>%lld</totalSizeInGB><disks><item><sizeInGB>%lld</sizeInGB><count>%lld</count><type>ssd</type></item></disks><nvmeSupport>required</nvmeSupport><encryptionSupport>required</encryptionSupport></instanceStorageInfo>",
				count * size, size, count];
		}
		[xml appendString:@"</item>"];
	}
	[xml appendString:@"</instanceTypeSet></DescribeInstanceTypesResponse>"];
	return [xml dataUsingEncoding:NSUTF8StringEncoding];
}

// CPU over the last hour, 5-minute datapoints: the instance's typical load plus a
// slow wave and a little per-point variation, so charts look alive and differ.
static NSData *DemoGetMetricStatistics(NSDictionary *parameters)
{
	NSString *instanceId = [parameters objectForKey:@"Dimensions.member.1.Value"];
	NSUInteger index = DemoIndexOfInstanceId(instanceId);
	NSDictionary *instance = (index != NSNotFound) ? [DemoInstances() objectAtIndex:index] : nil;
	BOOL running = [[instance objectForKey:@"state"] isEqualToString:@"running"];
	double base = [[instance objectForKey:@"cpu"] doubleValue];

	NSMutableString *xml = [NSMutableString stringWithString:
		@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<GetMetricStatisticsResponse xmlns=\"http://monitoring.amazonaws.com/doc/2010-08-01/\"><GetMetricStatisticsResult><Datapoints>"];
	if (running) {
		NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
		NSTimeInterval end = floor(now / 300.0) * 300.0;
		for (int step = 12; step >= 1; step--) {
			NSTimeInterval t = end - step * 300.0;
			double wave = sin(t / 1500.0 + (double)index) * (base * 0.25 + 2.0);
			double jitter = sin(t * 0.37 + (double)index * 3.1) * (base * 0.08 + 1.0);
			double average = MAX(0.3, MIN(98.0, base + wave + jitter));
			double minimum = MAX(0.1, average * 0.6);
			double maximum = MIN(100.0, average * 1.35 + 2.0);
			[xml appendFormat:@"<member><Timestamp>%@</Timestamp><Unit>Percent</Unit><Minimum>%.2f</Minimum><Maximum>%.2f</Maximum><Average>%.2f</Average></member>",
				DemoCloudWatchDate([NSDate dateWithTimeIntervalSince1970:t]), minimum, maximum, average];
		}
	}
	[xml appendString:@"</Datapoints><Label>CPUUtilization</Label></GetMetricStatisticsResult><ResponseMetadata><RequestId>demo</RequestId></ResponseMetadata></GetMetricStatisticsResponse>"];
	return [xml dataUsingEncoding:NSUTF8StringEncoding];
}

NSData *ElasticsDemoResponseData(NSString *service, NSString *action, NSString *region, NSDictionary *parameters)
{
	if ([action isEqualToString:@"DescribeInstances"])
		return DemoDescribeInstances(region);
	if ([action isEqualToString:@"DescribeVpcs"])
		return DemoDescribeVpcs(region);
	if ([action isEqualToString:@"DescribeVolumes"])
		return DemoDescribeVolumes(parameters);
	if ([action isEqualToString:@"DescribeInstanceTypes"])
		return DemoDescribeInstanceTypes(parameters);
	if ([action isEqualToString:@"GetMetricStatistics"])
		return DemoGetMetricStatistics(parameters);
	return nil;
}
