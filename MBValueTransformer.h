//
//  MBValueTransformer.h
//

#import <Foundation/Foundation.h>

typedef id (^BGMValueTransformerBlock)(id);

//
// A value transformer supporting block-based transformation.
//
@interface MBValueTransformer : NSValueTransformer

@property (nonatomic, copy, readonly) BGMValueTransformerBlock forwardBlock;
@property (nonatomic, copy, readonly) BGMValueTransformerBlock reverseBlock;

// Returns a transformer which transforms values using the given block. Reverse
// transformations will not be allowed.
+ (instancetype)transformerWithBlock:(BGMValueTransformerBlock)transformationBlock;

// Returns a transformer which transforms values using the given block, for
// forward or reverse transformations.
+ (instancetype)reversibleTransformerWithBlock:(BGMValueTransformerBlock)transformationBlock;

// Returns a transformer which transforms values using the given blocks.
+ (instancetype)reversibleTransformerWithForwardBlock:(BGMValueTransformerBlock)forwardBlock reverseBlock:(BGMValueTransformerBlock)reverseBlock;

@end
