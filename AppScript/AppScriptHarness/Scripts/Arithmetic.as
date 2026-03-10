@class ArithmeticTest : NSObject

- runTests {
    id a = 12
    id b = 4
    id sum = [a numberByAdding:b]
    id diff = [a numberBySubtracting:b]
    id product = [a numberByMultiplyingBy:b]
    id quotient = [a numberByDividingBy:b]
    id result = [NSMutableArray array]
    [result addObject:sum]
    [result addObject:diff]
    [result addObject:product]
    [result addObject:quotient]
    return result
}

@end
