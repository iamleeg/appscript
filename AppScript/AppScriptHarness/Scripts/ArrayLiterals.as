@class ArrayLiteralsTest : NSObject

- runTests {
    id items = @[@"apple", @"banana", @"cherry"]
    id count = [items count]
    id first = [items objectAtIndex:0]
    id result = [NSMutableArray array]
    [result addObject:count]
    [result addObject:first]
    return result
}

@end
