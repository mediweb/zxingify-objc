/*
 * Copyright 2012 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "ZXURIParsedResult.h"

static NSRegularExpression* USER_IN_HOST = nil;

@interface ZXURIParsedResult ()

@property (nonatomic, copy) NSString * uri;
@property (nonatomic, copy) NSString * title;

- (BOOL)isColonFollowedByPortNumber:(NSString *)uri protocolEnd:(int)protocolEnd;
- (NSString *)massageURI:(NSString *)uri;

@end

@implementation ZXURIParsedResult

@synthesize uri;
@synthesize title;

+ (void)initialize {
  USER_IN_HOST = [[NSRegularExpression alloc] initWithPattern:@":/*([^/@]+)@[^/]+" options:0 error:nil];
}

- (id)initWithUri:(NSString *)aUri title:(NSString *)aTitle {
  if (self = [super initWithType:kParsedResultTypeURI]) {
    self.uri = [self massageURI:aUri];
    self.title = aTitle;
  }

  return self;
}

- (void)dealloc {
  [uri release];
  [title release];

  [super dealloc];
}


/**
 * Returns true if the URI contains suspicious patterns that may suggest it intends to
 * mislead the user about its true nature. At the moment this looks for the presence
 * of user/password syntax in the host/authority portion of a URI which may be used
 * in attempts to make the URI's host appear to be other than it is. Example:
 * http://yourbank.com@phisher.com  This URI connects to phisher.com but may appear
 * to connect to yourbank.com at first glance.
 */
- (BOOL)possiblyMaliciousURI {
  return [USER_IN_HOST numberOfMatchesInString:uri options:0 range:NSMakeRange(0, uri.length)] > 0;
}

- (NSString *)displayResult {
  NSMutableString* result = [NSMutableString stringWithCapacity:30];
  [ZXParsedResult maybeAppend:title result:result];
  [ZXParsedResult maybeAppend:uri result:result];
  return result;
}

/**
 * Transforms a string that represents a URI into something more proper, by adding or canonicalizing
 * the protocol.
 */
- (NSString *)massageURI:(NSString *)aUri {
  NSString *_uri = [aUri stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  int protocolEnd = [_uri rangeOfString:@":"].location;
  if (protocolEnd == NSNotFound) {
    // No protocol, assume http
    _uri = [NSString stringWithFormat:@"http://%@", _uri];
  } else if ([self isColonFollowedByPortNumber:_uri protocolEnd:protocolEnd]) {
    // Found a colon, but it looks like it is after the host, so the protocol is still missing
    _uri = [NSString stringWithFormat:@"http://%@", _uri];
  } else {
    _uri = [[[_uri substringToIndex:protocolEnd] lowercaseString] stringByAppendingString:[_uri substringFromIndex:protocolEnd]];
  }
  return _uri;
}

- (BOOL)isColonFollowedByPortNumber:(NSString *)aUri protocolEnd:(int)protocolEnd {
  int nextSlash = [aUri rangeOfString:@"/" options:0 range:NSMakeRange(protocolEnd + 1, [aUri length] - protocolEnd - 1)].location;
  if (nextSlash == NSNotFound) {
    nextSlash = [aUri length];
  }
  if (nextSlash <= protocolEnd + 1) {
    return NO;
  }

  for (int x = protocolEnd + 1; x < nextSlash; x++) {
    if ([aUri characterAtIndex:x] < '0' || [aUri characterAtIndex:x] > '9') {
      return NO;
    }
  }

  return YES;
}

@end
