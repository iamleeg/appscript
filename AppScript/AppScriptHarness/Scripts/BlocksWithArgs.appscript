@class BlocksWithArgsTest : NSObject

- runTests {
    // Pass a two-parameter block to sortedArrayUsingComparator:.
    // The block parameters are bound by NSArray when it calls the comparator.
    id items = @[@"banana", @"apple", @"cherry"]
    id sorted = [items sortedArrayUsingComparator:^(a b) {
        return [a compare:b]
    }]
    return sorted
}

@end
