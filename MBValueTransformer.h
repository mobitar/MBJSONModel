//
//  MBValueTransformer.h
//

#import <Foundation/Foundation.h>

typedef id (^MBValueTransformerBlock)(id);

//
// A value transformer supporting block-based transformation.
//
@interface MBValueTransformer : NSValueTransformer

@property (nonatomic, copy, readonly) MBValueTransformerBlock forwardBlock;
@property (nonatomic, copy, readonly) MBValueTransformerBlock reverseBlock;

// Returns a transformer which transforms values using the given block. Reverse
// transformations will not be allowed.
+ (instancetype)transformerWithBlock:(MBValueTransformerBlock)transformationBlock;

// Returns a transformer which transforms values using the given block, for
// forward or reverse transformations.
+ (instancetype)reversibleTransformerWithBlock:(MBValueTransformerBlock)transformationBlock;

// Returns a transformer which transforms values using the given blocks.
+ (instancetype)reversibleTransformerWithForwardBlock:(MBValueTransformerBlock)forwardBlock reverseBlock:(MBValueTransformerBlock)reverseBlock;

@end
