//
//  MBJSONModel.m
//
//  Created by Mo Bitar on 11/27/13.
//  Copyright (c) 2013 Mo Bitar. All rights reserved.
//

#import "MBJSONModel.h"
#import <objc/runtime.h>

@implementation MBJSONModel

- (NSString *)description
{
    return [[self dictionaryFromObjectProperties] description];
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)dictionary
{
    if(self = [super init])
    {
        [self setValuesFromJSONDictionary:dictionary];
    }

    return self;
}

+ (NSArray *)arrayOfObjectPropertyNamesForClass:(Class)aClass
{
    unsigned int count;
    objc_property_t *propertyList = class_copyPropertyList(aClass, &count);
    NSMutableArray *properties = [NSMutableArray new];
    for (int i = 0; i < count; i++) {
        objc_property_t property = propertyList[i];
        const char *propertyName = property_getName(property);
        [properties addObject:[NSString stringWithUTF8String:propertyName]];
    }
    
    free(propertyList);
    return [properties copy];
}

- (NSArray *)extendedArrayOfProperties
{
    NSMutableArray *properties = [NSMutableArray new];
    Class aClass = self.class;
    while (aClass != [MBJSONModel class]) {
        [properties addObjectsFromArray:[MBJSONModel arrayOfObjectPropertyNamesForClass:aClass]];
        aClass = [aClass superclass];
    }
    return [properties copy];
}

- (NSDictionary *)dictionaryFromObjectProperties
{
    NSMutableDictionary *valuesDictionary = [[NSMutableDictionary alloc] init];
    
    NSArray *properties = [self extendedArrayOfProperties];
    for (NSString *propertyName in properties) {
        id value = [self valueForKey:propertyName];
        if (value) {
            [valuesDictionary setObject:value forKey:propertyName];
        }
    }
    
    return valuesDictionary;
}

- (NSDictionary *)JSONDictionaryRepresentation
{
    NSMutableDictionary *valuesDictionary = [[self dictionaryFromObjectProperties] mutableCopy];
    NSDictionary *mappingDict = [self.class JSONKeyTranslationDictionary];
    for(NSString *key in [valuesDictionary mutableCopy]) {
        // transform existing values if transformer exists
        MBValueTransformer *transformer = [self.class valueTransformerForKey:key];
        if(transformer.reverseBlock) {
            valuesDictionary[key] = [transformer reverseTransformedValue:valuesDictionary[key]];
        }
        
        if([mappingDict allKeysForObject:key].count == 0) {
            // property not found in translation dict, remove it from JSON dict
            [valuesDictionary removeObjectForKey:key];
        } else if([[mappingDict objectForKey:key] isKindOfClass:[NSDictionary class]]) {
            // no support currently for reverse coding a relationship class, will skip
            [valuesDictionary removeObjectForKey:key];
        }
    }
    
    NSDictionary *JSONDictionary = [self dictionaryByConvertingKeysToJSONKeysFromDictionary:valuesDictionary];
    return JSONDictionary;
}

- (NSData *)JSONDataRepresentation
{
    NSDictionary *JSONDictionary = [self JSONDictionaryRepresentation];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:JSONDictionary options:0 error:&error];
    if (error) {
        NSLog(@"Error serializing JSON: %@", error);
    }
    return data;
}

- (NSString *)JSONKeyForPropertyName:(NSString *)propertyName
{
    NSDictionary *mapping = [self.class JSONKeyTranslationDictionary];
    NSString *JSONKey = [[mapping allKeysForObject:propertyName] lastObject];
    if(JSONKey.length)
    {
        return JSONKey;
    }

    return propertyName;
}

- (NSDictionary *)dictionaryByConvertingKeysToJSONKeysFromDictionary:(NSDictionary *)dictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary new];
    for(NSString *key in dictionary)
    {
        NSString *JSONKey = [self JSONKeyForPropertyName:key];
        [JSONDictionary setObject:dictionary[key] forKey:JSONKey];
    }
    
    return JSONDictionary;
}

- (void)setValuesFromJSONDictionary:(NSDictionary *)dictionary
{
    [self setValuesFromJSONDictionary:dictionary ignoreNil:NO];
}

- (void)setValuesFromJSONDictionary:(NSDictionary *)dictionary ignoreNil:(BOOL)ignoreNil
{
    NSDictionary *mapping = [[self class] JSONKeyTranslationDictionary];
    for (NSString *JSONKey in mapping.allKeys) {
        id mappedKey = [mapping objectForKey:JSONKey];
        id value = [dictionary objectForKey:JSONKey];
        if((!value || [value isEqual:[NSNull null]]) && ignoreNil) {
            continue;
        }
        if(mappedKey) {
            MBValueTransformer *transformer = nil;
            if([mappedKey isKindOfClass:[NSString class]]) {
                transformer = [self.class valueTransformerForKey:mappedKey];
            }
            
            if(transformer) {
                value = [transformer transformedValue:value];
                if(value) {
                    [self setValue:value forKey:mappedKey];
                }
            }
            else if([mappedKey isKindOfClass:[NSDictionary class]]) {
                BOOL isArray = [mappedKey[@"isArray"] boolValue];
                Class relationshipClass = NSClassFromString(mappedKey[@"class"]);
                if(relationshipClass) {
                    if(isArray) {
                        [self setValue:[relationshipClass arrayOfModelsFromJSONDictionaryArray:value] forKey:mappedKey[@"relationship"]];
                    } else {
                        [self setValue:[relationshipClass modelFromJSONDictionary:value] forKey:mappedKey[@"relationship"]];
                    }
                }
            }
            else {
                if([value isEqual:[NSNull null]] == NO) {
                    [self setValue:value forKey:mappedKey];
                }
            }
        }
    }
}

- (void)setNilValueForKey:(NSString *)key
{
    @try {
        [self setValue:@(0) forKey:key];
    }
    @catch (NSException *exception) {}
}

- (void)updateWithValuesOfModel:(MBJSONModel *)sourceModel
{
    NSAssert([self class] == [sourceModel class], @"Cannot copy properties of models of different classes");
    NSArray *properties = [sourceModel extendedArrayOfProperties];
    [self updateWithValuesOfModel:sourceModel forKeys:properties];
}

- (void)updateWithValuesOfModel:(MBJSONModel *)sourceModel forKeys:(NSArray *)keys
{
    for(NSString *propertyName in keys) {
        [self setValue:[sourceModel valueForKey:propertyName] forKey:propertyName];
    }
}

+ (MBValueTransformer *)valueTransformerForKey:(NSString *)key
{
    return nil;
}

+ (NSDictionary *)JSONKeyTranslationDictionary
{
    return nil;
}

+ (NSDictionary *)reverseKeyValuePairingOfDictionary:(NSDictionary *)dictionary
{
    NSMutableDictionary *reversedDictionary = [NSMutableDictionary new];
    for(NSString *key in dictionary) {
        [reversedDictionary setObject:key forKey:dictionary[key]];
    }
    
    return reversedDictionary;
}

+ (instancetype)modelFromJSONDictionary:(NSDictionary *)dictionary
{
    return [[self alloc] initWithJSONDictionary:dictionary];
}

+ (NSArray *)arrayOfModelsFromJSONDictionaryArray:(NSArray *)dictionaries
{
    NSMutableArray *models = [NSMutableArray new];

    for(NSDictionary *jsonDic in dictionaries)
    {
        [models addObject:[self modelFromJSONDictionary:jsonDic]];
    }
    
    return models;
}

@end
