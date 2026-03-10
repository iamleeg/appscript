@class BlocksNoArgsTest : NSObject

- runTests {
    // Declare a no-argument block literal and have it invoked via ifTrue:ifFalse:.
    id flag = YES
    id result = [flag ifTrue:^{
        return @"ran"
    } ifFalse:^{
        return @"skipped"
    }]
    return result
}

@end
