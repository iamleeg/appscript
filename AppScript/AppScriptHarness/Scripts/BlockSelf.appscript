@class BlockSelfTest : NSObject

@property label

- init {
    [self setLabel:@"receiver"]
    return self
}

- runTests {
    // Inside a block, self refers to the enclosing method's receiver, not the block.
    id nameInBlock = @"unset"
    id flag = YES
    [flag ifTrue:^{
        nameInBlock = [self label]
    } ifFalse:^{
        nameInBlock = @"wrong"
    }]
    return nameInBlock
}

@end
