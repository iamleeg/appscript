@class ClassPropertiesTest : NSObject

@property (strong, nonatomic) title
@property (copy) tag
@property (readonly) version

- init {
    [self setTitle:@"AppScript"]
    [self setTag:@"v1"]
    return self
}

- version {
    return @"1.0"
}

- runTests {
    // strong property: getter returns the stored object
    id t = [self title]
    // copy property: a copy is stored; verify the value round-trips
    id g = [self tag]
    // readonly property: backed by a custom method, no synthesised setter
    id v = [self version]
    id result = [NSMutableArray array]
    [result addObject:t]
    [result addObject:g]
    [result addObject:v]
    return result
}

@end
