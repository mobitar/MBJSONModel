//
//  NSDictionary+MBJSONModel.h
//
//  Created by Mo Bitar on 1/29/14.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (MBJSONModel)

- (NSDictionary *)dictionaryByAddingEntiresFromDictionary:(NSDictionary *)dictionary;

@end
