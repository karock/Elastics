//
//  AWSRequest.m
//  Elastics
//
//  Created by Dmitri Goutnik on 27/11/2010.
//  Copyright 2010 Tundra Bot. All rights reserved.
//

#import "AWSRequest.h"
#import "AWSSignatureV4.h"

// Defaults
#define                AWSApiDefaultRegion		kAWSUSEastRegion
static NSString *const AWSApiDefaultPath		= @"/";
static NSString *const AWSApiDefaultMethod		= @"GET";
static NSString *const AWSApiEC2Version			= @"2016-11-15";
static NSString *const AWSApiMonitoringVersion	= @"2010-08-01";

// Request options keys
NSString *const kAWSAccessKeyIdOption			= @"AWSAccessKeyId";
NSString *const kAWSSecretAccessKeyOption		= @"AWSSecretAccessKey";
NSString *const kAWSSessionTokenOption			= @"AWSSessionToken";
NSString *const kAWSRegionOption				= @"AWSRegion";
NSString *const kAWSServiceOption				= @"AWSService";
NSString *const kAWSPathOption					= @"AWSPath";
NSString *const kAWSUseSSLOption				= @"AWSUseSSL";

// Static variables
static NSMutableDictionary *_s_awsRequestDefaultOptions;

@interface AWSRequest ()

@property (nonatomic, retain, readonly) NSString *host;
@property (nonatomic, retain, readonly) NSString *apiVersion;
@property (nonatomic, retain) NSHTTPURLResponse *responseInfo;
@property (nonatomic, retain) NSData *responseData;
@property (nonatomic, retain) TBXML *responseParser;
@property (nonatomic, retain) AWSResponse *response;
@property (nonatomic, retain) AWSErrorResponse *errorResponse;
@property (nonatomic, retain) NSDate *startedAt;
@property (nonatomic, retain) NSDate *finishedAt;

- (NSDictionary *)parametersForAction:(NSString *)action method:(NSString *)method parameters:(NSDictionary *)parameters;
- (void)currentConnectionDidFinishWithResult:(NSDictionary *)result;
- (AWSResponse *)parseResponse;
- (void)currentConnectionDidFinishLoading;
- (void)currentConnectionDidFailWithError:(NSError *)error;

@end

// One shared session for all requests (ephemeral: no cookies or on-disk cache).
static NSURLSession *AWSRequestURLSession(void)
{
	static NSURLSession *session = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
		configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
		configuration.timeoutIntervalForRequest = 60.0;   // same as the old NSURLRequest default
		configuration.timeoutIntervalForResource = 120.0; // give up on a request that keeps trickling
		session = [[NSURLSession sessionWithConfiguration:configuration] retain];
	});
	return session;
}

@implementation AWSRequest

@synthesize delegate = _delegate;
@synthesize responseInfo = _responseInfo;
@synthesize responseData = _responseData;
@synthesize responseParser = _responseParser;
@synthesize response = _response;
@synthesize errorResponse = _errorResponse;
@synthesize startedAt = _startedAt;
@synthesize finishedAt = _finishedAt;

#pragma mark - Initialization

+ (void)initialize
{
	if (!_s_awsRequestDefaultOptions) {
		_s_awsRequestDefaultOptions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                       AWSApiDefaultRegion, kAWSRegionOption,
                                       AWSApiDefaultPath, kAWSPathOption,
                                       [NSNumber numberWithBool:YES], kAWSUseSSLOption,
                                       nil];

	}
}

+ (NSDictionary *)defaultOptions
{
	return _s_awsRequestDefaultOptions;
}

+ (void)setDefaultOptions:(NSDictionary *)options
{
	[_s_awsRequestDefaultOptions addEntriesFromDictionary:options];
}

- (id)initWithOptions:(NSDictionary *)options delegate:(id<AWSRequestDelegate>)delegate
{
	self = [super init];
	if (self) {
		_options = [[NSMutableDictionary alloc] init];
		[_options addEntriesFromDictionary:options];
		_delegate = delegate;
	}
	return self;
}

- (void)dealloc
{
	TBRelease(_options);
	TBRelease(_responseInfo);
	TBRelease(_responseData);
	TBRelease(_responseParser);
	TBRelease(_response);
	TBRelease(_errorResponse);
	TBRelease(_startedAt);
	TBRelease(_finishedAt);
	[super dealloc];
}

#pragma mark - Properties

- (NSString *)accessKeyId
{
	NSString *result = [_options objectForKey:kAWSAccessKeyIdOption] ? [_options objectForKey:kAWSAccessKeyIdOption] : [_s_awsRequestDefaultOptions objectForKey:kAWSAccessKeyIdOption];
	return result ? result : @"";
}

- (void)setAccessKeyId:(NSString *)value
{
	[_options setObject:[[value copy] autorelease] forKey:kAWSAccessKeyIdOption];
}

- (NSString *)secretAccessKey
{
	NSString *result = [_options objectForKey:kAWSSecretAccessKeyOption] ? [_options objectForKey:kAWSSecretAccessKeyOption] : [_s_awsRequestDefaultOptions objectForKey:kAWSSecretAccessKeyOption];
	return result ? result : @"";
}

- (void)setSecretAccessKey:(NSString *)value
{
	[_options setObject:[[value copy] autorelease] forKey:kAWSSecretAccessKeyOption];
}

- (NSString *)sessionToken
{
	NSString *result = [_options objectForKey:kAWSSessionTokenOption] ? [_options objectForKey:kAWSSessionTokenOption] : [_s_awsRequestDefaultOptions objectForKey:kAWSSessionTokenOption];
	return result ? result : @"";
}

- (void)setSessionToken:(NSString *)value
{
	[_options setObject:[[value copy] autorelease] forKey:kAWSSessionTokenOption];
}

- (NSString *)region
{
	return [_options objectForKey:kAWSRegionOption] ? [_options objectForKey:kAWSRegionOption] : [_s_awsRequestDefaultOptions objectForKey:kAWSRegionOption];
}

- (void)setRegion:(NSString *)value
{
	[_options setObject:[[value copy] autorelease] forKey:kAWSRegionOption];
}

- (NSString *)service
{
	return [_options objectForKey:kAWSServiceOption] ? [_options objectForKey:kAWSServiceOption] : [_s_awsRequestDefaultOptions objectForKey:kAWSServiceOption];
}

- (void)setService:(NSString *)value
{
	[_options setObject:[[value copy] autorelease] forKey:kAWSServiceOption];
}

- (NSString *)path
{
	return [_options objectForKey:kAWSPathOption] ? [_options objectForKey:kAWSPathOption] : [_s_awsRequestDefaultOptions objectForKey:kAWSPathOption];
}

- (void)setPath:(NSString *)value
{
	[_options setObject:[[value copy] autorelease] forKey:kAWSPathOption];
}

- (BOOL)useSSL
{
	return [_options objectForKey:kAWSUseSSLOption] ? [[_options objectForKey:kAWSUseSSLOption] boolValue] : [[_s_awsRequestDefaultOptions objectForKey:kAWSUseSSLOption] boolValue];
}

- (void)setUseSSL:(BOOL)value
{
	return [_options setObject:[NSNumber numberWithBool:value] forKey:kAWSUseSSLOption];
}

- (NSString *)host
{
	NSAssert([self.service length] > 0, @"Empty service.");
	NSAssert([self.region length] > 0, @"Empty region.");

	return [NSString stringWithFormat:@"%@.%@.%@", self.service, self.region, kAWSDomain];
}

- (NSString *)apiVersion
{
	if ([self.service isEqualToString:kAWSEC2Service]) {
		return AWSApiEC2Version;
	}
	else if ([self.service isEqualToString:kAWSMonitoringService]) {
		return AWSApiMonitoringVersion;
	}
	else {
		NSLog(@"Unknown service: \"%@\"", self.service);
		return nil;
	}
}

- (void)setResponseData:(NSData *)responseData
{
	if (_responseData != responseData) {
		[_responseData release];
		_responseData = [responseData retain];
	}
}

- (NSTimeInterval)age
{
    if (_isRunning)
        return 0;
    else
        return _finishedAt ? [[NSDate date] timeIntervalSinceDate:_finishedAt] : NSTimeIntervalSince1970;
}

#pragma mark - Parameter handling

//
// Given an array ["a", "b", "c"] and key "Value", produces
// {"Value.1 => "a", "Value.2" => "b", "Value.3" => "c"}
//
- (NSDictionary *)parameterListFromArray:(NSArray *)array key:(NSString *)key
{
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	NSUInteger idx = 1;

	for (id value in array) {
		NSString *awsKey = [NSString stringWithFormat:@"%@.%zd", key, idx];
		[parameters setObject:value forKey:awsKey];
	}

	return parameters;
}

//
// Given dictionary {"Tag" => ["a", "b"], "Status" => [42]}, produces
// {"Filter.1.Name" => "Tag", "Filter.1.Value.1" => "a", "Filter.1.Value.2" => "b", "Filter.2.Name" => "Status", "Filter.2.Value.1" => 42}
//
- (NSDictionary *)filterListFromDictionary:(NSDictionary *)dictionary
{
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	NSUInteger idx = 1;

	for (NSString *key in [dictionary allKeys]) {
		id value = [dictionary objectForKey:key];
		NSArray *valuesArray = nil;
		NSUInteger valueIdx = 1;

		if ([value isKindOfClass:[NSArray class]]) {
			valuesArray = value;
		}
		else {
			valuesArray = [NSArray arrayWithObject:value];
		}

		NSString *awsNameKey = [NSString stringWithFormat:@"Filter.%zd.Name", idx];
		[parameters setObject:key forKey:awsNameKey];

		for (id valueItem in valuesArray) {
			NSString *awsValueKey = [NSString stringWithFormat:@"Filter.%zd.Value.%zd", idx, valueIdx];
			[parameters setObject:valueItem forKey:awsValueKey];
			valueIdx++;
		}
		idx++;
	}

	return parameters;
}

- (NSDictionary *)dimensionListFromDictionary:(NSDictionary *)dictionary
{
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
	NSUInteger idx = 1;

	for (NSString *key in [dictionary allKeys]) {
		id value = [dictionary objectForKey:key];
		NSArray *valuesArray = nil;

		if ([value isKindOfClass:[NSArray class]]) {
			valuesArray = value;
		}
		else {
			valuesArray = [NSArray arrayWithObject:value];
		}

		for (NSString *valueItem in valuesArray) {
			NSString *awsNameKey = [NSString stringWithFormat:@"Dimensions.member.%zd.Name", idx];
			[parameters setObject:key forKey:awsNameKey];
			NSString *awsValueKey = [NSString stringWithFormat:@"Dimensions.member.%zd.Value", idx];
			[parameters setObject:valueItem forKey:awsValueKey];
			idx++;
		}
	}

	return parameters;
}

//
// Append common parameters to action-specific parameters.
// Authentication is carried in headers (Signature Version 4), not in the query.
//
- (NSDictionary *)parametersForAction:(NSString *)action method:(NSString *)method parameters:(NSDictionary *)parameters
{
	NSMutableDictionary *requestParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];

	[requestParameters setObject:action forKey:@"Action"];
	[requestParameters setObject:self.apiVersion forKey:@"Version"];

	return requestParameters;
}

#pragma mark - Request handling

- (BOOL)start
{
	return [self startWithParameters:nil];
}

- (BOOL)startWithParameters:(NSDictionary *)parameters
{
	NSAssert(FALSE, @"Abstract method call.");
	return FALSE;
}

- (BOOL)isRunning
{
    return _isRunning;
}

- (BOOL)startRequestWithAction:(NSString *)action parameters:(NSDictionary *)parameters
{
	@synchronized(self) {
		if (!_isRunning)
			_isRunning = YES;
		else
			return FALSE;
	}

	self.responseData = [NSData data];
	self.startedAt = [NSDate date];
	self.finishedAt = nil;

	// prepare parameters
	NSDictionary *requestParameters = [self parametersForAction:action method:AWSApiDefaultMethod parameters:parameters];

	// prepare request URL; the query string must be byte-for-byte the one that gets signed
	NSString *canonicalQuery = AWSSigV4CanonicalQueryString(requestParameters);
	NSURL *url = [NSURL URLWithString:
				  [NSString stringWithFormat:@"%@://%@%@?%@",
				   self.useSSL ? @"https" : @"http",
				   self.host,
				   self.path,
				   canonicalQuery]];

	// sign with AWS Signature Version 4
	NSString *amzDate = AWSSigV4AmzDate(_startedAt);
	NSMutableDictionary *signedHeaders = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										  self.host, @"host",
										  amzDate, @"x-amz-date",
										  nil];
	NSString *sessionToken = self.sessionToken;
	if ([sessionToken length] > 0)
		[signedHeaders setObject:sessionToken forKey:@"x-amz-security-token"];
	NSString *authorization = AWSSigV4AuthorizationHeader(AWSApiDefaultMethod,
														  self.path,
														  canonicalQuery,
														  signedHeaders,
														  nil,
														  amzDate,
														  self.region,
														  self.service,
														  self.accessKeyId,
														  self.secretAccessKey);

	// prepare request (Host is set by the URL loading system from the URL)
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
	[request setHTTPMethod:AWSApiDefaultMethod];
	[request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	[request setValue:amzDate forHTTPHeaderField:@"X-Amz-Date"];
	[request setValue:authorization forHTTPHeaderField:@"Authorization"];
	if ([sessionToken length] > 0)
		[request setValue:sessionToken forHTTPHeaderField:@"X-Amz-Security-Token"];

	// start the request; the completion handler runs on the session's background queue,
	// results are handed to the main thread in default and menu-tracking run loop modes
	// so the status menu can update while it is open
	NSArray *modes = [NSArray arrayWithObjects:NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, nil];
	NSURLSessionDataTask *task = [AWSRequestURLSession() dataTaskWithRequest:request
														   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error) {
			[self performSelectorOnMainThread:@selector(currentConnectionDidFailWithError:)
								   withObject:error
								waitUntilDone:NO
										modes:modes];
		}
		else {
			NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
									response, @"response",
									(data ? data : [NSData data]), @"data",
									nil];
			[self performSelectorOnMainThread:@selector(currentConnectionDidFinishWithResult:)
								   withObject:result
								waitUntilDone:NO
										modes:modes];
		}
	}];
	[request release];
	[task resume];

	// notify delegate that request started
	[_delegate requestDidStartLoading:self];

	return TRUE;
}

- (AWSResponse *)parseResponse
{
	NSAssert(FALSE, @"Abstract method call.");
	return nil;
}

- (AWSErrorResponse *)parseErrorResponse
{
	NSAssert(FALSE, @"Abstract method call.");
	return nil;
}

- (void)currentConnectionDidFinishWithResult:(NSDictionary *)result
{
	self.responseInfo = (NSHTTPURLResponse *)[result objectForKey:@"response"];
	self.responseData = [result objectForKey:@"data"];
	[self currentConnectionDidFinishLoading];
}

- (void)currentConnectionDidFinishLoading
{
#ifdef TB_DEBUG
	{
//		NSString *responseString = [[NSString alloc] initWithData:_responseData encoding:NSUTF8StringEncoding];
//		//TBTrace(@"%@", [responseString substringToIndex:MIN([responseString length], 4096)]);
//		TBTrace(@"%@", responseString);
//		[responseString release];
	}
#endif

	self.finishedAt = [NSDate date];
	self.responseParser = [TBXML tbxmlWithXMLData:self.responseData];

	if ([_responseInfo statusCode] >= 400) {
#ifdef TB_DEBUG
        {
            NSString *responseString = [[NSString alloc] initWithData:_responseData encoding:NSUTF8StringEncoding];
            TBTrace(@"%@", responseString);
            [responseString release];
        }
#endif
		self.response = nil;
		self.errorResponse = [self parseErrorResponse];
	}
	else {
		self.response = [self parseResponse];
		self.errorResponse = nil;
	}

	if (_errorResponse) {
		NSDictionary *errorInfo = [[[_errorResponse errors] objectAtIndex:0] dictionaryRepresentation];
		[_delegate request:self didFailWithError:[NSError errorWithDomain:kAWSErrorDomain code:0 userInfo:errorInfo]];
	}
	else {
		[_delegate requestDidFinishLoading:self];
	}

	@synchronized(self) {
		_isRunning = NO;
	}
}

- (void)currentConnectionDidFailWithError:(NSError *)error
{
	TBLog(@"%@", error);

	self.finishedAt = [NSDate date];

	self.response = nil;
	[_delegate request:self didFailWithError:error];

	@synchronized(self) {
		_isRunning = NO;
	}
}

@end
