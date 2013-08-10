#import "ZipFile.h"
#import "ZipWriteStream.h"

@interface UIApplication (rtd)
-(NSString *)nameForEncoding:(const char *)enc afterVar:(NSString **)after;
-(NSString *)nameForEncodingS:(NSString *)encoding afterVar:(NSString **)after;
-(void)doRuntimeDump;
-(NSString *)methodsStringForClass:(Class)cls isClassMethods:(BOOL)clsmethods;
-(NSString *)headerStringForClass:(Class)cls;
@end

#define ENC(sym, str) if ([encoding isEqualToString:@sym]) { return str; }
%hook UIApplication
%new
+(NSString *)isWorking {
    return @"yup";
}

%new
-(NSString *)nameForEncoding:(const char *)enc afterVar:(NSString **)after {
    return [self nameForEncodingS:[NSString stringWithUTF8String:enc] afterVar:after];
}


%new
-(NSString *)nameForEncodingS:(NSString *)encoding afterVar:(NSString **)after {
    if (encoding == nil) {
        return @"";
    }
    if ([encoding characterAtIndex:0] == '^') {
        NSString *sofar = [self nameForEncodingS:[encoding substringFromIndex:1] afterVar:after];
        return [sofar stringByAppendingString:([sofar characterAtIndex:sofar.length-1] == '*') ? @"*" : @" *"];
    }
    if ([encoding characterAtIndex:0] == '[') {
        int length = 0;
        [[NSScanner scannerWithString:[encoding stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""]] scanInteger:&length];
        NSString *len = [NSString stringWithFormat:@"%i", length];
        NSString *carryon = [[encoding stringByReplacingCharactersInRange:NSMakeRange(encoding.length-1, 1) withString:@""]  stringByReplacingCharactersInRange:NSMakeRange(0, len.length+1) withString:@""];
        
        NSString *after2 = nil;
        NSString *retVal = [self nameForEncodingS:carryon afterVar:&after2];
        if (after != nil) {
            *after = [NSString stringWithFormat:@"[%i]%@", length, after2 ?: @""];
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
    return [NSString stringWithFormat:@"unk(%@)", encoding];
}
%new
-(NSString *)methodsStringForClass:(Class)cls isClassMethods:(BOOL)clsmethods {
    if (clsmethods) {
        cls = object_getClass(cls);
    }
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    if (methodCount > 0) {
        NSMutableString *methodString = [NSMutableString string];
        for (unsigned int m = 0; m < methodCount; m++) {
            NSString *afterRet = @"";
            NSString *returnType = [self nameForEncoding:method_copyReturnType(methods[m]) afterVar:&afterRet];
            returnType = [returnType stringByAppendingString:afterRet];
            NSString *name = NSStringFromSelector(method_getName(methods[m]));
            unsigned int argCount = method_getNumberOfArguments(methods[m]);
            for (unsigned int a = 2; a < argCount; a++) {//skip 0 and 1 for self, _cmd
                NSString *after = @"";
                NSString *arg = [NSString stringWithFormat:@"!(%@%@)arg%i ", [self nameForEncoding:method_copyArgumentType(methods[m], a) afterVar:&after], after, a];
                NSRange locationOfFirstColon = [name rangeOfString:@":"];
                name = [name stringByReplacingCharactersInRange:locationOfFirstColon withString:arg];
            }
            name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            name = [name stringByReplacingOccurrencesOfString:@"!" withString:@":"];
            [methodString appendFormat:@"%@(%@)%@;\n", clsmethods ? @"+" : @"-", returnType, name];
        }
        return methodString;
    }
    return @"";
}
%new
-(NSString *)headerStringForClass:(Class)cls {
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
    
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    if (ivarCount > 0) {
        NSMutableString *ivarString = [NSMutableString stringWithString:@"{\n"];
        for (unsigned int i = 0; i < ivarCount; i++) {
            const char *type = ivar_getTypeEncoding(ivars[i]);
            NSString *after = @"";
            [ivarString appendFormat:@"    %@ %s%@;\n", [self nameForEncoding:type afterVar:&after], ivar_getName(ivars[i]), after];
        }
        [ivarString appendString:@"}"];
        [output appendFormat:@" %@", ivarString];
    }
    [output appendFormat:@"\n%@", [self methodsStringForClass:cls isClassMethods:YES]];
    [output appendFormat:@"\n%@", [self methodsStringForClass:cls isClassMethods:NO]];
    [output appendString:@"\n@end"];
    return [[output copy] autorelease];
}

%new
-(void)doRuntimeDump {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *basePath = [@"/var/tmp/" stringByAppendingPathComponent:[bundle bundleIdentifier]];
    
    ZipFile *zipFile = [[ZipFile alloc] initWithFileName:[basePath stringByAppendingPathExtension:@"zip"] mode:ZipFileModeCreate];
    
    unsigned int classCount = 0;
    const char **classes = objc_copyClassNamesForImage([[bundle executablePath] UTF8String], &classCount);
    for (unsigned int c = 0; c < classCount; c++) {
        Class cls = objc_getClass(classes[c]);
        NSString *satr = [self headerStringForClass:cls];
        NSString *filePath = [NSStringFromClass(cls) stringByAppendingPathExtension:@"h"];
        ZipWriteStream *stream = [zipFile writeFileInZipWithName:filePath compressionLevel:ZipCompressionLevelBest];
        [stream writeData:[satr dataUsingEncoding:NSUTF8StringEncoding]];
        [stream finishedWriting];
    }
    [zipFile close];
    
    UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"complete" message:[basePath stringByAppendingPathExtension:@"zip"] delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
    [view show];
}

%end
