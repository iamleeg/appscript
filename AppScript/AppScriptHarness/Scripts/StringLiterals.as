@class StringLiteralsTest : NSObject

- runTests {
    id greeting = @"hello"
    id upper = [greeting uppercaseString]
    id combined = [upper stringByAppendingString:@" world"]
    return combined
}

@end
