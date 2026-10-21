//
//  SigV4Test.m
//  Checks AWSSignatureV4 against the example in AWS's SigV4 documentation.
//
//  Run from the repository root:
//    mkdir -p build && xcrun clang -fno-objc-arc -framework Foundation -I API Tests/SigV4Test.m API/AWSSignatureV4.m -o build/sigv4test && build/sigv4test
//  (Manual retain/release, like the app.)
//

#import <Foundation/Foundation.h>
#import "AWSSignatureV4.h"

static int failures = 0;

static void expect(NSString *name, NSString *actual, NSString *expected)
{
	if ([actual isEqualToString:expected]) {
		printf("PASS %s\n", [name UTF8String]);
	} else {
		printf("FAIL %s\n  expected: %s\n  actual:   %s\n", [name UTF8String], [expected UTF8String], [actual UTF8String]);
		failures++;
	}
}

int main(void)
{
	@autoreleasepool {
		// IAM ListUsers example from "Create a signed AWS API request" (AWS docs)
		NSDictionary *query = @{ @"Action": @"ListUsers", @"Version": @"2010-05-08" };
		NSString *canonicalQuery = AWSSigV4CanonicalQueryString(query);
		expect(@"canonical query", canonicalQuery, @"Action=ListUsers&Version=2010-05-08");

		NSDictionary *headers = @{
			@"Content-Type": @"application/x-www-form-urlencoded; charset=utf-8",
			@"Host": @"iam.amazonaws.com",
			@"X-Amz-Date": @"20150830T123600Z",
		};
		NSString *auth = AWSSigV4AuthorizationHeader(@"GET", @"/", canonicalQuery, headers, nil,
		                                            @"20150830T123600Z", @"us-east-1", @"iam",
		                                            @"AKIDEXAMPLE", @"wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY");
		expect(@"authorization header", auth,
		       @"AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/iam/aws4_request, "
		       @"SignedHeaders=content-type;host;x-amz-date, "
		       @"Signature=5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7");

		// Encoding rules used by EC2/CloudWatch parameters
		expect(@"uri encode", AWSSigV4URIEncode(@"a b+c/d:e~f*"), @"a%20b%2Bc%2Fd%3Ae~f%2A");
		expect(@"sort order", AWSSigV4CanonicalQueryString(@{ @"b": @"1", @"B": @"2", @"a.1": @"3" }), @"B=2&a.1=3&b=1");
		expect(@"amz date", AWSSigV4AmzDate([NSDate dateWithTimeIntervalSince1970:1440938160]), @"20150830T123600Z");
	}
	printf(failures ? "%d FAILED\n" : "ALL PASSED\n", failures);
	return failures ? 1 : 0;
}
