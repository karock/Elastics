//
//  AWSSignatureV4.h
//  Elastics
//
//  AWS Signature Version 4 request signing.
//  https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv4-create-signed-request.html
//

#import <Foundation/Foundation.h>

// Percent-encodes per RFC 3986 as SigV4 requires: everything except A-Z a-z 0-9 - _ . ~
NSString *AWSSigV4URIEncode(NSString *string);

// Encoded and sorted "name=value&name=value" query string. Use the same string
// both in the request URL and when signing.
NSString *AWSSigV4CanonicalQueryString(NSDictionary *parameters);

// Timestamp in the "yyyyMMdd'T'HHmmss'Z'" (UTC) form used by the X-Amz-Date header.
NSString *AWSSigV4AmzDate(NSDate *date);

// Returns the value for the Authorization header.
// - headers: every header to sign (name -> value). Each must also be sent with the
//   request. Must include "host" and "x-amz-date" (whose value is amzDate), plus
//   "x-amz-security-token" when using temporary credentials.
// - payload: request body, or nil for an empty body (GET).
NSString *AWSSigV4AuthorizationHeader(NSString *method,
                                      NSString *path,
                                      NSString *canonicalQuery,
                                      NSDictionary *headers,
                                      NSData *payload,
                                      NSString *amzDate,
                                      NSString *region,
                                      NSString *service,
                                      NSString *accessKeyId,
                                      NSString *secretAccessKey);
