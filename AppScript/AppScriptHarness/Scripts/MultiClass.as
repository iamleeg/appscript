@class Formatter : NSObject

- formatValue: aValue {
    id prefix = @"value="
    return [prefix stringByAppendingString:[aValue description]]
}

@end

@class Accumulator : NSObject

@property total

- init {
    [self setTotal:0]
    return self
}

- addNumber: n {
    id next = [[self total] numberByAdding:n]
    [self setTotal:next]
    return self
}

@end

@class MultiClassTest : NSObject

- runTests {
    // One AppScript class creates and uses instances of two other AppScript classes.
    id acc = [Accumulator new]
    [acc addNumber:7]
    [acc addNumber:5]

    id fmt = [Formatter new]
    return [fmt formatValue:[acc total]]
}

@end
