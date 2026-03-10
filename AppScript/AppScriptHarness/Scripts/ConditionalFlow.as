@class ConditionalFlowTest : NSObject

- runTests {
    // ifTrue:ifFalse: executes the true branch when the receiver is YES.
    id yes = YES
    id trueResult = [yes ifTrue:^{
        return @"yes-branch"
    } ifFalse:^{
        return @"wrong"
    }]

    // ifTrue:ifFalse: executes the false branch when the receiver is NO.
    id no = NO
    id falseResult = [no ifTrue:^{
        return @"wrong"
    } ifFalse:^{
        return @"no-branch"
    }]

    id result = [NSMutableArray array]
    [result addObject:trueResult]
    [result addObject:falseResult]
    return result
}

@end
