//
// Created by Maarten Billemont on 2018-04-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

#import "Observers.h"

@interface WeakReference<__covariant ObjectType> : NSObject

@property(atomic, weak) ObjectType reference;

+ (instancetype)referenceWith:(ObjectType)reference;

@end

@implementation Observers {
    NSMutableOrderedSet *observers;
}

- (instancetype)init {

    if (!(self = [super init]))
        return nil;

    observers = [NSMutableOrderedSet new];

    return self;
}

- (id)register:(id)observer {

    @synchronized (observers) {
        [observers addObject:[WeakReference referenceWith:observer]];
    }
    return observer;
}

- (id)unregister:(id)observer {

    @synchronized (observers) {
        [observers removeObject:observer];
    }
    return NULL;
}

- (void)notify:(void ( ^ )(id observer))action {

    @synchronized (observers) {
        NSMutableArray *obsolete = [NSMutableArray new];
        for (WeakReference *observer in [observers copy]) {
            id reference = observer.reference;
            if (reference)
                action( reference );
            else
                [obsolete addObject:observer];
        }
        [observers removeObjectsInArray:obsolete];
    }
}

@end

@implementation WeakReference

+ (instancetype)referenceWith:(id)reference {

    WeakReference *ref = [self new];
    ref.reference = reference;
    return ref;
}

- (BOOL)isEqual:(id)other {

    return other == self || other == self.reference;
}

- (NSUInteger)hash {

    return [self.reference hash];
}

- (NSString *)debugDescription {

    return [self.reference debugDescription]?: @"<empty>";
}

@end
