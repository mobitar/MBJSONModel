//
//  MBJSONModel.m
//
//  Created by Mo Bitar on 11/27/13.
//  Copyright (c) 2013 Mo Bitar. All rights reserved.
//

#import "MBJSONModel.h"
#import <objc/runtime.h>

NSString *MBSetSelectorForKey(NSString *key)
{
    NSString *firstLetter = [[key substringToIndex:1] capitalizedString];
    NSString *capitlizedPropertyName = [firstLetter stringByAppendingString:[key substringFromIndex:1]];
    NSString *selectorName = [[@"set" stringByAppendingString:capitlizedPropertyName] stringByAppendingString:@":"];
    return selectorName;
}

@implementation MBJSONModel

- (NSString *)description
{
    return [[self dictionaryFromObjectProperties] description];
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)dictionary
{
    if(self = [super init]) {
        [self setValuesFromJSONDictionary:dictionary ignoreNil:YES];
    }

    return self;
}

+ (NSArray *)propertiesToSkipInEnumeration
{
    return @[@"description", @"superclass", @"debugDescription"];
}

+ (NSArray *)arrayOfObjectPropertyNamesForClass:(Class)aClass
{
    unsigned int count;
    objc_property_t *propertyList = class_copyPropertyList(aClass, &count);
    NSMutableArray *properties = [NSMutableArray new];
    for (int i = 0; i < count; i++) {
        objc_property_t property = propertyList[i];
        const char *propertyName = property_getName(property);
        NSString *propertyNameString = [NSString stringWithUTF8String:propertyName];
        [properties addObject:propertyNameString];
    }
    
    [properties removeObjectsInArray:[self propertiesToSkipInEnumeration]];
    
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
        if([self respondsToSelector:NSSelectorFromString(propertyName)]) {
            id value = [self valueForKey:propertyName];
            if (value) {
                [valuesDictionary setObject:value forKey:propertyName];
            }
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
    if(JSONKey.length) {
        return JSONKey;
    }

    return propertyName;
}

- (NSDictionary *)dictionaryByConvertingKeysToJSONKeysFromDictionary:(NSDictionary *)dictionary
{
    NSMutableDictionary *JSONDictionary = [NSMutableDictionary new];
    for(NSString *key in dictionary) {
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
        id value = nil;
        
        if([JSONKey rangeOfString:@"."].location != NSNotFound) {
            // trace keypath
            NSScanner *scanner = [NSScanner scannerWithString:JSONKey];
            BOOL hasResult = YES;
            while(!scanner.isAtEnd && hasResult) {
                NSString *currentKeyPath;
                hasResult = [scanner scanUpToString:@"." intoString:&currentKeyPath];
                NSInteger targetLocation = scanner.scanLocation + 1;
                if(targetLocation < scanner.string.length) {
                    [scanner setScanLocation:targetLocation];
                }
                
                if(currentKeyPath.length) {
                    if(value) {
                        value = value[currentKeyPath];
                    } else {
                        value = dictionary[currentKeyPath];
                    }
                }
            }

        } else {
            value = [dictionary objectForKey:JSONKey];
        }
        if((!value || [value isEqual:[NSNull null]]) && ignoreNil) {
            continue;
        }
        if(mappedKey) {
            if([mappedKey isKindOfClass:[NSDictionary class]]) {
                BOOL isDate = [mappedKey[@"isDate"] boolValue];
                if(isDate) {
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:mappedKey[@"format"]];
                    NSTimeZone *timezone = mappedKey[@"timezone"];
                    if(timezone) {
                        [formatter setTimeZone:timezone];
                    } else {
                        [formatter setTimeZone:[NSTimeZone systemTimeZone]];
                    }
                    [self setValue:[formatter dateFromString:value] forKeyPath:mappedKey[@"property"]];
                } else {
                    // relationship
                    BOOL isArray = [mappedKey[@"isArray"] boolValue];
                    Class relationshipClass = NSClassFromString(mappedKey[@"class"]);
                    if(relationshipClass) {
                        MBValueTransformer *transformer = [self transformerForKey:mappedKey[@"relationship"]];
                        if(transformer) {
                            [self setValue:[transformer transformedValue:value] forKey:mappedKey[@"relationship"]];
                        } else if(isArray) {
                            [self setValue:[relationshipClass arrayOfModelsFromJSONDictionaryArray:value] forKey:mappedKey[@"relationship"]];
                        } else {
                            [self setValue:[relationshipClass modelFromJSONDictionary:value] forKey:mappedKey[@"relationship"]];
                        }
                    }
                }
            } else {
                MBValueTransformer *transformer = [self transformerForKey:mappedKey];
                if(transformer) {
                    value = [transformer transformedValue:value];
                    if(value) {
                        [self setValue:value forKey:mappedKey];
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
}

- (MBValueTransformer *)transformerForKey:(NSString *)key
{
    MBValueTransformer *transformer = nil;
    if([key isKindOfClass:[NSString class]]) {
        transformer = [self.class valueTransformerForKey:key];
    }
    
    if(!transformer) {
        NSString *selectorString = [key stringByAppendingString:@"JSONValueTransformer"];
        if([self.class respondsToSelector:NSSelectorFromString(selectorString)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            transformer = [self.class performSelector:NSSelectorFromString(selectorString)];
#pragma clang diagnostic pop
        }
    }

    return transformer;
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
        NSString *selectorName = MBSetSelectorForKey(propertyName);
        if(![self respondsToSelector:NSSelectorFromString(selectorName)]) {
            continue;
        }
        
        id value = [sourceModel valueForKey:propertyName];
        if([value conformsToProtocol:@protocol(NSCopying)] && [self shouldCopyValueForKey:propertyName]) {
            [self setValue:[value copy] forKey:propertyName];
        } else {
            [self setValue:value forKey:propertyName];
        }
    }
}

- (BOOL)shouldCopyValueForKey:(NSString *)key
{
    return YES;
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

    for(NSDictionary *jsonDic in dictionaries) {
        [models addObject:[self modelFromJSONDictionary:jsonDic]];
    }
    
    return models;
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    MBJSONModel *model = [[[self class] alloc] init];
    if(model) {
        [model updateWithValuesOfModel:self];
    }
    
    return model;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    NSDictionary *dictionary = [self dictionaryFromObjectProperties];
    for(NSString *key in dictionary) {
        id value = dictionary[key];
        if([value respondsToSelector:@selector(encodeWithCoder:)] && [value conformsToProtocol:NSProtocolFromString(@"NSCopying")]) {
            if([self respondsToSelector:NSSelectorFromString(MBSetSelectorForKey(key))]) {
                @try {
                    [aCoder encodeObject:dictionary[key] forKey:key];
                }
                @catch (NSException *exception) {}
            }
        }
    }
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if(self = [super init]) {
        NSArray *properties = [self extendedArrayOfProperties];
        for(NSString *property in properties) {
            if([self respondsToSelector:NSSelectorFromString(MBSetSelectorForKey(property))]) {
                [self setValue:[aDecoder decodeObjectForKey:property] forKey:property];
            }
        }
    }
    
    return self;
}

+ (NSString *)pathForObjectKey:(NSString *)key
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"MBJSONModel-%@", key]];
    return path;
}

- (void)writeToDiskWithKey:(NSString *)key
{
    NSString *path = [self.class pathForObjectKey:key];
    BOOL success = [NSKeyedArchiver archiveRootObject:self toFile:path];
    NSAssert(success, nil);
}

+ (instancetype)cachedModelFromDiskWithKey:(NSString *)key
{
    return [NSKeyedUnarchiver unarchiveObjectWithFile:[self pathForObjectKey:key]];
}

+ (BOOL)writeArrayOfModelsToDisk:(NSArray *)models key:(NSString *)key
{
    NSString *path = [self pathForObjectKey:key];
    BOOL success = [NSKeyedArchiver archiveRootObject:models toFile:path];
    return success;
}

+ (NSArray *)cachedArrayOfModelsForKey:(NSString *)key
{
    return [NSKeyedUnarchiver unarchiveObjectWithFile:[self pathForObjectKey:key]];
}

@end
