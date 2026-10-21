//
//  AWSSignatureV4.m
//  Elastics
//
//  AWS Signature Version 4 request signing (manual retain/release).
//

#import "AWSSignatureV4.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

static NSString *const kAWSSigV4Algorithm = @"AWS4-HMAC-SHA256";

static NSString *AWSSigV4Hex(NSData *data)
{
	const unsigned char *bytes = [data bytes];
	NSMutableString *hex = [NSMutableString stringWithCapacity:[data length] * 2];
	for (NSUInteger i = 0; i < [data length]; i++)
		[hex appendFormat:@"%02x", bytes[i]];
	return hex;
}

static NSData *AWSSigV4SHA256(NSData *data)
{
	unsigned char digest[CC_SHA256_DIGEST_LENGTH];
	CC_SHA256([data bytes], (CC_LONG)[data length], digest);
	return [NSData dataWithBytes:digest length:sizeof(digest)];
}

static NSData *AWSSigV4HMAC(NSData *key, NSString *message)
{
	NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char mac[CC_SHA256_DIGEST_LENGTH];
	CCHmac(kCCHmacAlgSHA256, [key bytes], [key length], [messageData bytes], [messageData length], mac);
	return [NSData dataWithBytes:mac length:sizeof(mac)];
}

NSString *AWSSigV4URIEncode(NSString *string)
{
	static NSCharacterSet *unreserved = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		unreserved = [[NSCharacterSet characterSetWithCharactersInString:
					   @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"] retain];
	});
	return [string stringByAddingPercentEncodingWithAllowedCharacters:unreserved];
}

NSString *AWSSigV4CanonicalQueryString(NSDictionary *parameters)
{
	NSMutableDictionary *encoded = [NSMutableDictionary dictionaryWithCapacity:[parameters count]];
	for (id key in parameters) {
		id value = [parameters objectForKey:key];
		NSString *valueString = [value isKindOfClass:[NSString class]] ? value : [value description];
		[encoded setObject:AWSSigV4URIEncode(valueString) forKey:AWSSigV4URIEncode([key description])];
	}

	// sort by encoded name, byte order
	NSArray *sortedKeys = [[encoded allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
		return [a compare:b options:NSLiteralSearch];
	}];

	NSMutableArray *pairs = [NSMutableArray arrayWithCapacity:[sortedKeys count]];
	for (NSString *key in sortedKeys)
		[pairs addObject:[NSString stringWithFormat:@"%@=%@", key, [encoded objectForKey:key]]];

	return [pairs componentsJoinedByString:@"&"];
}

NSString *AWSSigV4AmzDate(NSDate *date)
{
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
	[formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	[formatter setCalendar:[[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease]];
	[formatter setDateFormat:@"yyyyMMdd'T'HHmmss'Z'"];
	return [formatter stringFromDate:date];
}

static NSString *AWSSigV4CanonicalURI(NSString *path)
{
	if ([path length] == 0)
		return @"/";

	NSMutableArray *segments = [NSMutableArray array];
	for (NSString *segment in [path componentsSeparatedByString:@"/"])
		[segments addObject:AWSSigV4URIEncode(segment)];
	return [segments componentsJoinedByString:@"/"];
}

NSString *AWSSigV4AuthorizationHeader(NSString *method,
                                      NSString *path,
                                      NSString *canonicalQuery,
                                      NSDictionary *headers,
                                      NSData *payload,
                                      NSString *amzDate,
                                      NSString *region,
                                      NSString *service,
                                      NSString *accessKeyId,
                                      NSString *secretAccessKey)
{
	// 1. Canonical headers: lowercase names, trimmed values, sorted by name
	NSMutableDictionary *canonicalHeaders = [NSMutableDictionary dictionaryWithCapacity:[headers count]];
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
	for (NSString *name in headers) {
		NSString *value = [[headers objectForKey:name] stringByTrimmingCharactersInSet:whitespace];
		while ([value rangeOfString:@"  "].location != NSNotFound)
			value = [value stringByReplacingOccurrencesOfString:@"  " withString:@" "];
		[canonicalHeaders setObject:value forKey:[name lowercaseString]];
	}
	NSArray *sortedNames = [[canonicalHeaders allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
		return [a compare:b options:NSLiteralSearch];
	}];

	NSMutableString *canonicalHeadersString = [NSMutableString string];
	for (NSString *name in sortedNames)
		[canonicalHeadersString appendFormat:@"%@:%@\n", name, [canonicalHeaders objectForKey:name]];
	NSString *signedHeaders = [sortedNames componentsJoinedByString:@";"];

	// 2. Canonical request
	NSString *payloadHash = AWSSigV4Hex(AWSSigV4SHA256(payload ? payload : [NSData data]));
	NSString *canonicalRequest = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@\n%@",
								  method,
								  AWSSigV4CanonicalURI(path),
								  canonicalQuery ? canonicalQuery : @"",
								  canonicalHeadersString,
								  signedHeaders,
								  payloadHash];

	// 3. String to sign
	NSString *dateStamp = [amzDate substringToIndex:8];
	NSString *credentialScope = [NSString stringWithFormat:@"%@/%@/%@/aws4_request", dateStamp, region, service];
	NSString *stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@",
							  kAWSSigV4Algorithm,
							  amzDate,
							  credentialScope,
							  AWSSigV4Hex(AWSSigV4SHA256([canonicalRequest dataUsingEncoding:NSUTF8StringEncoding]))];

	// 4. Signing key and signature
	NSData *key = [[@"AWS4" stringByAppendingString:secretAccessKey] dataUsingEncoding:NSUTF8StringEncoding];
	key = AWSSigV4HMAC(key, dateStamp);
	key = AWSSigV4HMAC(key, region);
	key = AWSSigV4HMAC(key, service);
	key = AWSSigV4HMAC(key, @"aws4_request");
	NSString *signature = AWSSigV4Hex(AWSSigV4HMAC(key, stringToSign));

	return [NSString stringWithFormat:@"%@ Credential=%@/%@, SignedHeaders=%@, Signature=%@",
			kAWSSigV4Algorithm, accessKeyId, credentialScope, signedHeaders, signature];
}
