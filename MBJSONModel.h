//
//  MBJSONModel.h
//
//  Created by Mo Bitar on 11/27/13.
//  Copyright (c) 2013 Mo Bitar. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MBValueTransformer.h"

#import "NSDictionary+MBJSONModel.h"

@interface MBJSONModel : NSObject <NSCopying, NSCoding>

/**
 Designated initializer. Creates a model then calls -setValuesFromJSONDictionary
 */
- (instancetype)initWithJSONDictionary:(NSDictionary *)dictionary;

/**
 Returns a dictionary where keys are named exactly as the @property is named
 */
- (NSDictionary *)dictionaryFromObjectProperties;

/**
 Returns a dictionary where keys are converted to JSONKeys using -JSONKeyForPropertyName:
 */
- (NSDictionary *)JSONDictionaryRepresentation;

/**
 Converts -JSONDictionaryRepresentation to NSData
 */
- (NSData *)JSONDataRepresentation;

/** 
  Uses NSKeyedArchiver to archive the model into a data blob
 */
- (NSData *)dataRepresentation;

/**
 The inverse of -dataRepresentation. Convers the data back to a model
 */
+ (instancetype)unarchiveModelFromData:(NSData *)data;


/** Returns an array of strings representing each property the object has including its superclasses (not including NSObject) */
- (NSArray *)extendedArrayOfProperties;

/**
 Converts JSON keys to local @property keys, then sets respective values.
 IMPORTANT: Keys not present in this dictionary will set the model's property for that key to nil.
 To avoid this behavior, use setValuesFromJSONDictionary:ignoreNil:
 */
- (void)setValuesFromJSONDictionary:(NSDictionary *)dictionary;

/**
 Similar to setValuesFromJSONDictionary, but can skip nil values so that they're not overriden.
 */
- (void)setValuesFromJSONDictionary:(NSDictionary *)dictionary ignoreNil:(BOOL)ignoreNil;

/**
 Overridden by subclasses to manually transform a JSON value into a native value.
 Key is local key, not JSON key.
 */
+ (MBValueTransformer *)valueTransformerForKey:(NSString *)key;

/**
 Using -JSONKeyForPropertyName:, this method replaces all keys of the given dictionary to JSON keys.
 */
- (NSDictionary *)dictionaryByConvertingKeysToJSONKeysFromDictionary:(NSDictionary *)dictionary;

/**
 Default implementation returns +JSONKeyTranslationDictionary[propertyName] if non-nil, else returns whatever you pass it in.
 Can be overriden by subclasses.
 */
- (NSString *)JSONKeyForPropertyName:(NSString *)propertyName;

/**
 Copies all object properties (including superclasses up to but not including MBJSONModel) from the source model to the receiver.
 */
- (void)updateWithValuesOfModel:(MBJSONModel *)sourceModel;
- (void)updateWithValuesOfModel:(MBJSONModel *)sourceModel forKeys:(NSArray *)keys;

/** 
 When copying models, you may not neccessarily want to use NSCopying on certain properties, and just assign the actual value to the target model.
 Subclasses can override this to return NO for certain properties. Default is YES.
 */
- (BOOL)shouldCopyValueForKey:(NSString *)key;

/**
 Should be overridden by subclasses. Should return a JSONKey -> local property key mapping.
 */
+ (NSDictionary *)JSONKeyTranslationDictionary;

/**
 Convenience factory method
 */
+ (instancetype)modelFromJSONDictionary:(NSDictionary *)dictionary;

/**
 Loops through JSON dictionaries in given array and creates a model with +modelFromJSONDictionary:
 Returns an array of instancetype models
 */
+ (NSArray *)arrayOfModelsFromJSONDictionaryArray:(NSArray *)dictionaries;

/**
 Reverses keys with values
 */
+ (NSDictionary *)reverseKeyValuePairingOfDictionary:(NSDictionary *)dictionary;

/** Archives the object to disk and indexed via given key */
- (void)writeToDiskWithKey:(NSString *)key;

/** Retreive a model saved to disk via the writeToDiskWithKey: method, using that same key */
+ (instancetype)cachedModelFromDiskWithKey:(NSString *)key;

/** Called when a model is retreived via cachedModelFromDiskWithKey: */
- (void)awakeFromCachedDisk;

/** Archives an array of models. Retreivable by key */
+ (BOOL)writeArrayOfModelsToDisk:(NSArray *)models key:(NSString *)key;

/** Retreive archived models by key */
+ (NSArray *)cachedArrayOfModelsForKey:(NSString *)key;

@end
