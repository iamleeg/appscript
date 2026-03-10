@class BlockCaptureTest : NSObject

- runTests {
    // Non-constant captured variables are implicitly mutable from within blocks
    // (equivalent to __block in Objective-C).
    id captured = @"initial"
    id flag = YES
    [flag ifTrue:^{
        captured = @"modified"
    } ifFalse:^{
        captured = @"wrong"
    }]
    return captured
}

@end
