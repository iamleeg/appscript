@class Shape : NSObject

@property sides

- describe {
    return @"shape"
}

- sidesDescription {
    id s = [[self sides] description]
    return [@"sides=" stringByAppendingString:s]
}

@end

@class Triangle : Shape

- init {
    [self setSides:3]
    return self
}

- describe {
    return @"triangle"
}

@end

@class InheritanceTest : NSObject

- runTests {
    id tri = [Triangle new]
    id result = [NSMutableArray array]
    // Overridden method returns subclass value
    [result addObject:[tri describe]]
    // Inherited method from Shape works on Triangle instance
    [result addObject:[tri sidesDescription]]
    return result
}

@end
