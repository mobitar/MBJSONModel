#MBJSONModel

Quick and lightweight JSON → NSObject translation.

Example
-------
```objective-c
@interface User : MBJSONModel
@property (nonatomic, copy) NSString *name;
@property (nonatomic) NSDate *birthDate;
@property (nonatomic) NSArray *tweets;
@end

@implementation User
+ (NSDictionary *)JSONKeyTranslationDictionary
{
    return @{
				@"user_name" : @"name",
				@"birth_date" : @{@"isDate" : @YES, @"format" : @"yyyy-MM-dd", @"property" : @"birthDate"},
				@"data.user.tweets" : @{@"class" : NSStringFromClass([Tweet class]), @"relationship" : @"tweets", @"isArray" : @YES},
              }
}
@end
```

Then, if you have a JSON dictionary that looks like this:
```
{
	"user_name" : "Jon Snow",
	"birth_date" : "1970/03/29",
	"data" : {
		"user" : {
			"tweets" : [
				{
					"text" : "hello world"
				}
			]
		}
	}
}
```

You can easily do:
```objective-c
User *userObj = [User modelFromJSONDictionary:jsonDict];
```


Advanced Options
-------
####Custom value trasformers
You can override a transformer method to manually transform a JSON object to native. Say you have the following JSON dictionary:
```
{
	"custom_text" : "hello\nworld"
}
```

and the following translation dictionary

```objective-c
+ (NSDictionary *)JSONKeyTranslationDictionary
{
    return @{@"custom_text" : @"text"}
}
```

and wanted to change the text to "hello world" before translating to native, you can implement

```objective-c
- (MBValueTransformer *)textJSONValueTransformer
{
	return [MBValueTransformer transformerWithBlock:^id(NSString *incomingString) {
       return [incomingString stringByReplacingOccurrencesOfString:@"/n" withString:@" "];
    }];
}
```

This method will automatically be called by MBJSONModel during the translation process.

####NSCopying
MBJSONModels conform to NSCopying, which means you can make a copy of any model object:

```objective-c
User *user = [User modelFromJSONDictionary:@{@"user_name" : @"Jon Snow"}];
User *userCopy = [user copy];
assert([user.name isEqual:userCopy.name]); // Passes
```

####NSObject → NSDictionary

There are two dictionary instance methods:

```objective-c
/**
 Returns a dictionary where keys are named exactly as the @property is named
 */
- (NSDictionary *)dictionaryFromObjectProperties;
/**
 Returns a dictionary where keys are converted to JSONKeys using -JSONKeyForPropertyName:
 */
- (NSDictionary *)JSONDictionaryRepresentation;
```

```objective-c
User *user = [User modelFromJSONDictionary:@{@"user_name" : @"Jon Snow"}];
```

```objective-c
NSLog([user dictionaryFromObjectProperties]);
```
Output:
> {"name" : "Jon Snow"}

<br>
```objective-c
NSLog([user JSONDictionaryRepresentation]);
```
Output:
> {"user_name" : "Jon Snow"}

Contact
-------

**[Mo Bitar](http://bitar.io)** | [@bitario](https://twitter.com/bitario)

License
-------
MBJSONModel is available under the MIT license.