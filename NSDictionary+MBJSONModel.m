//
//  NSDictionary+MBJSONModel.m
//
//  Created by Mo Bitar on 1/29/14.
//

#import "NSDictionary+MBJSONModel.h"

@implementation NSDictionary (MBJSONModel)

- (NSDictionary *)dictionaryByAddingEntiresFromDictionary:(NSDictionary *)dictionary
{
    NSMutableDictionary *result = self.mutableCopy;
    [result addEntriesFromDictionary:dictionary];
    return result;
}

@end
