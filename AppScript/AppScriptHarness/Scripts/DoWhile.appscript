@class DoWhileTest : NSObject

- runTests {
    // do:while: uses the idiomatic NSEnumerator pattern from ARCHITECTURE.md.
    // The condition block returns nil when the enumerator is exhausted, stopping the loop.
    id items = @[@"a", @"b", @"c"]
    id enumerator = [items objectEnumerator]
    id item = [enumerator nextObject]
    id result = [NSMutableArray array]
    [self do:^{
        [result addObject:item]
        item = [enumerator nextObject]
    } while:^{
        return item
    }]
    return result
}

@end
