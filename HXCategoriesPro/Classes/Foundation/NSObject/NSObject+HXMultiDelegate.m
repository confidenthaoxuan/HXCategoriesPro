//
//  NSObject+HXMultiDelegate.m
//  ZDTalk
//
//  Created by 吕浩轩 on 2019/12/16.
//  Copyright © 2020 LHX. All rights reserved.
//

#import "NSObject+HXMultiDelegate.h"
#import <objc/runtime.h>

@implementation NSObject (HXMultiDelegate)

//使用动态运行时添加数组对象multiDelegates，保存代理
- (void)setMultiDelegate:(MultiDelegateOC *)multiDelegate
{
    objc_setAssociatedObject(self, @selector(multiDelegate), multiDelegate, OBJC_ASSOCIATION_RETAIN);
}

- (MultiDelegateOC *)multiDelegate
{
    MultiDelegateOC *multiDelegate = objc_getAssociatedObject(self,@selector(multiDelegate));
    if(multiDelegate == nil)
    {
        multiDelegate = [[MultiDelegateOC alloc]init];
        objc_setAssociatedObject(self, @selector(multiDelegate), multiDelegate, OBJC_ASSOCIATION_RETAIN);
    }
    return multiDelegate;
}

- (void)addMultiDelegate:(id)delegate
{
    [self.multiDelegate addDelegate:delegate];
}

- (void)addDelegate:(id)delegate beforeDelegate:(id)otherDelegate
{
    [self.multiDelegate addDelegate:self beforeDelegate:otherDelegate];
}
- (void)addDelegate:(id)delegate afterDelegate:(id)otherDelegate
{
    [self.multiDelegate addDelegate:self afterDelegate:otherDelegate];
}


- (void)removeMultiDelegate:(id)delegate
{
    [self.multiDelegate removeDelegate:self];
}

- (void)removeAllDelegates
{
    [self.multiDelegate removeAllDelegates];
}

@end

@interface MultiDelegateOC()

@property (readwrite,strong,nonatomic) NSPointerArray* delegates;

@end

@implementation MultiDelegateOC

- (instancetype)init
{
    if(self = [super init])
    {
        self.silentWhenEmpty = YES;
    }
    return self;
}

- (void)addDelegate:(id)delegate
{
    [self.delegates addPointer:(__bridge void*)delegate];
}

- (NSUInteger)indexOfDelegate:(id)delegate
{
    for (NSUInteger i = 0; i < self.delegates.count; i += 1) {
        if ([self.delegates pointerAtIndex:i] == (__bridge void*)delegate) {
            return i;
        }
    }
    return NSNotFound;
}

- (void)addDelegate:(id)delegate beforeDelegate:(id)otherDelegate
{
    NSUInteger index = [self indexOfDelegate:otherDelegate];
    if (index == NSNotFound)
    {
        index = self.delegates.count;
    }
    [self.delegates insertPointer:(__bridge void*)delegate atIndex:index];
}

- (void)addDelegate:(id)delegate afterDelegate:(id)otherDelegate
{
    NSUInteger index = [self indexOfDelegate:otherDelegate];
    if (index == NSNotFound)
    {
        index = 0;
    }
    else
    {
        index += 1;
    }
    [self.delegates insertPointer:(__bridge void*)delegate atIndex:index];
}

- (void)removeDelegate:(id)delegate
{
    NSUInteger index = [self indexOfDelegate:delegate];
    if (index != NSNotFound)
    {
        [self.delegates removePointerAtIndex:index];
    }
    [self.delegates compact];
}

- (void)removeAllDelegates
{
    for (NSUInteger i = self.delegates.count; i > 0; i -= 1)
    {
         [self.delegates removePointerAtIndex:i - 1];
    }
}

- (BOOL)respondsToSelector:(SEL)selector
{
    if ([super respondsToSelector:selector])
    {
        return YES;
    }
    for (id delegate in self.delegates)
    {
        if (delegate && [delegate respondsToSelector:selector])
        {
            return YES;
        }
    }
    return NO;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature* signature = [super methodSignatureForSelector:selector];
    if (signature)
    {
        return signature;
    }
    
    [self.delegates compact];
    if (self.silentWhenEmpty && self.delegates.count == 0)
    {
        // return any method signature, it doesn't really matter
        return [self methodSignatureForSelector:@selector(description)];
    }
    
    for (id delegate in self.delegates)
    {
        if (!delegate)
        {
            continue;
        }
        signature = [delegate methodSignatureForSelector:selector];
        if (signature)
        {
             break;
        }
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    SEL selector = [invocation selector];
    BOOL responded = NO;
    
    NSArray *copiedDelegates = [self.delegates copy];
    void *returnValue = NULL;
    for (id delegate in copiedDelegates)
    {
        if (delegate && [delegate respondsToSelector:selector])
        {
            [invocation invokeWithTarget:delegate];
            if(invocation.methodSignature.methodReturnLength != 0)
            {
                void *value = nil;
                [invocation getReturnValue:&value];
                if(value)
                {
                    returnValue = value;
                }
            }
            responded = YES;
        }
    }
    if(returnValue)
    {
        [invocation setReturnValue:&returnValue];
    }
    if (!responded && !self.silentWhenEmpty)
    {
        [self doesNotRecognizeSelector:selector];
    }
}

- (NSPointerArray *)delegates
{
    if(!_delegates)
    {
        _delegates = [NSPointerArray weakObjectsPointerArray];
    }
    return _delegates;
}

@end
