#import <objc/runtime.h>
#import "RTBSelectView.h"

NSString * nameForEncoding(const char * enc, NSString ** after);
NSString * nameForEncodingS(NSString * enc, NSString ** after);
NSString * methodsStringForClass(Class cls, BOOL clsmethods);

@interface NSObject (clsDmp)
-(NSString *)$headerString;
-(NSString *)$hs;
-(NSString *)$printAllIVars;
-(NSArray *)$messages;
@end

@interface NSBundle (clsDmp)
-(NSArray *)$classes;
@end

@interface UIApplication (rtBrowse)
-(UIView *)$selectView;
@end


@implementation UIApplication (rtBrowse)
-(UIView *)$selectView {
    RTBSelectView *sv = [[RTBSelectView alloc] initWithFrame:[[self keyWindow] bounds]];
    [sv setBackgroundColor:[[UIColor redColor] colorWithAlphaComponent:0.1]];
    [[self keyWindow] addSubview:sv];
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (![sv didGetTouched] && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    CGPoint touchedPoint = [sv touchedPoint];
    [sv removeFromSuperview];
    [sv release];
    return [[UIApplication sharedApplication].keyWindow hitTest:touchedPoint withEvent:nil];
}
@end


@implementation NSObject (clsDmp)

-(NSString *)$printAllIVars {   
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList([self class], &ivarCount);
    NSMutableString *output = [NSMutableString stringWithFormat:@"(%i)\n", ivarCount];
    if (ivarCount == 0) {
        free(ivars);
        return @"No Ivars";
    }
    for (unsigned int i = 0; i < ivarCount; i++) {
        NSString *ivarName = [NSString stringWithUTF8String:ivar_getName(ivars[i])];
        [output appendFormat:@"%@ : %@\n", ivarName, [self valueForKey:ivarName]];
    }
    free(ivars);
    return output;
}

-(NSArray *)$messages {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(object_getClass(self), &methodCount);
    NSMutableArray *collector = [NSMutableArray array];
    for (int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        [collector addObject:NSStringFromSelector(method_getName(method))];
    }
    free(methods);
    return [NSArray arrayWithArray:collector];
}

-(NSString *)$hs {
    return [self $headerString];
}
-(NSString *)$headerString {
    Class cls = [self class];
    NSString *superclass =  NSStringFromClass(class_getSuperclass(cls));
    NSString *mclass = NSStringFromClass(cls);
    NSMutableString *output = [NSMutableString stringWithFormat:@"@interface %@ : %@", mclass, superclass];
    
    unsigned int protocolCount = 0;
    Protocol **protocols = class_copyProtocolList(cls, &protocolCount);
    if (protocolCount > 0) {
        NSMutableString *protocolString = [NSMutableString stringWithString:@"<"];
        for (unsigned int p = 0; p < protocolCount; p++) {
            [protocolString appendFormat:@"%s%@", protocol_getName(protocols[p]), (p == protocolCount-1) ? @"" : @", "];
        }
        [protocolString appendString:@">"];
        [output appendFormat:@" %@", protocolString];
    }
    free(protocols);
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    if (ivarCount > 0) {
        NSMutableString *ivarString = [NSMutableString stringWithString:@"{\n"];
        for (unsigned int i = 0; i < ivarCount; i++) {
            const char *type = ivar_getTypeEncoding(ivars[i]);
            NSString *after = @"";
            [ivarString appendFormat:@"    %@ %s%@;\n", nameForEncoding(type, &after), ivar_getName(ivars[i]), after];
        }
        [ivarString appendString:@"}"];
        [output appendFormat:@" %@", ivarString];
    }
    free(ivars);
    [output appendFormat:@"\n%@", methodsStringForClass(cls, YES)];
    [output appendFormat:@"\n%@", methodsStringForClass(cls, NO)];
    [output appendString:@"\n@end"];
    return [[output copy] autorelease];
}

@end

%hook NSBundle
%new
-(NSArray *)$classes {
    unsigned int count = 0;
    const char** classNames = objc_copyClassNamesForImage([[self executablePath] UTF8String], &count);
    NSMutableArray *collector = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        const char* className = classNames[i];
        [collector addObject:objc_getClass(className)];
    }
    free(classNames);
    return [NSArray arrayWithArray:collector];
}
%new
-(BOOL)$saveAllHeadersToDirectory:(NSString *)directory {
    BOOL success = YES;
    for (Class cls in [self $classes]) {
        NSString *header = [cls $headerString];
        NSString *name = [NSStringFromClass(cls) stringByAppendingString:@".h"];
        BOOL written = [header writeToFile:[directory stringByAppendingPathComponent:name] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        if (!written) {
            success = NO;
        }
    }
    return success;
}

%end

NSString * nameForEncoding(const char * enc, NSString ** after) {
    return nameForEncodingS([NSString stringWithUTF8String:enc], after);
}

#define ENC(sym, str) if ([encoding isEqualToString:@sym]) { return str; }
NSString * nameForEncodingS(NSString * encoding, NSString ** after) {
    if (encoding == nil) {
        return @"";
    }
    if ([encoding characterAtIndex:0] == '^') {
        NSString *sofar = nameForEncodingS([encoding substringFromIndex:1], after);
        return [sofar stringByAppendingString:([sofar characterAtIndex:sofar.length-1] == '*') ? @"*" : @" *"];
    }
    if ([encoding characterAtIndex:0] == '[') {
        NSInteger length = 0;
        [[NSScanner scannerWithString:[encoding stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""]] scanInteger:&length];
        NSString *len = [NSString stringWithFormat:@"%li", (long)length];
        NSString *carryon = [[encoding stringByReplacingCharactersInRange:NSMakeRange(encoding.length-1, 1) withString:@""]  stringByReplacingCharactersInRange:NSMakeRange(0, len.length+1) withString:@""];
        
        NSString *after2 = nil;
        NSString *retVal = nameForEncodingS(carryon, &after2);
        if (after != nil) {
            *after = [NSString stringWithFormat:@"[%li]%@", (long)length, after2 ?: @""];
        }
        return retVal;
    }
    if ([encoding characterAtIndex:0] == 'b') {
        if (after != nil) {
            *after = [encoding stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@":"];
        }
        return @"unsigned int";
    }
    if ([encoding characterAtIndex:0] ==  123) {
        NSUInteger locationOfEquals = [encoding rangeOfString:@"="].location;
        return [encoding substringWithRange:NSMakeRange(1, locationOfEquals -1)];
    }
    if ([encoding characterAtIndex:0] == '@') {
        if (encoding.length == 1) {
            return @"id";
        } else if ([encoding characterAtIndex:1] == '"' && [encoding characterAtIndex:encoding.length-1] == '"') {
            NSMutableString *str = [NSMutableString stringWithString:encoding];
            [str replaceCharactersInRange:NSMakeRange(encoding.length-1, 1) withString:@" *"];
            [str replaceCharactersInRange:NSMakeRange(0, 2) withString:@""];
            return [[str copy] autorelease];
        }
    }
    ENC("c", @"char");
    ENC("i", @"int");
    ENC("s", @"short");
    ENC("l", @"long");
    ENC("q", @"long long");
    ENC("C", @"unsigned char");
    ENC("I", @"unsigned int");
    ENC("S", @"unsigned short");
    ENC("L", @"unsigned long");
    ENC("Q", @"unsigned long long");
    ENC("f", @"float");
    ENC("d", @"double");
    ENC("B", @"bool");
    ENC("v", @"void");
    ENC("*", @"char *");
    ENC("#", @"Class");
    ENC(":", @"SEL");
    return [NSString stringWithFormat:@"id \\*unk(%@)*\\", encoding];
}
NSString * methodsStringForClass(Class cls, BOOL clsmethods) {
    if (clsmethods) {
        cls = object_getClass(cls);
    }
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    if (methodCount > 0) {
        NSMutableString *methodString = [NSMutableString string];
        for (unsigned int m = 0; m < methodCount; m++) {
            NSString *afterRet = @"";
            const char * returnEnc = method_copyReturnType(methods[m]);
            NSString *returnType = nameForEncoding(returnEnc, &afterRet);
            free((void *)returnEnc);
            returnType = [returnType stringByAppendingString:afterRet];
            NSString *name = NSStringFromSelector(method_getName(methods[m]));
            unsigned int argCount = method_getNumberOfArguments(methods[m]);
            for (unsigned int a = 2; a < argCount; a++) {//skip 0 and 1 for self, _cmd
                NSString *after = @"";
                const char *argEnc = method_copyArgumentType(methods[m], a);
                NSString *arg = [NSString stringWithFormat:@"!(%@%@)arg%i ", nameForEncoding(argEnc, &after), after, a];
                free((void *)argEnc);
                NSRange locationOfFirstColon = [name rangeOfString:@":"];
                name = [name stringByReplacingCharactersInRange:locationOfFirstColon withString:arg];
            }
            name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            name = [name stringByReplacingOccurrencesOfString:@"!" withString:@":"];
            [methodString appendFormat:@"%@(%@)%@;\n", clsmethods ? @"+" : @"-", returnType, name];
        }
        free(methods);
        return methodString;
    }
    free(methods);
    return @"";
}

