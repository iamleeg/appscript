@class VariablesTest : NSObject

- runTests {
    id strong = @"strong"
    weak id weakRef = strong
    constant id fixed = @"fixed"
    id result = [NSMutableArray array]
    [result addObject:strong]
    [result addObject:weakRef]
    [result addObject:fixed]
    return result
}

@end
