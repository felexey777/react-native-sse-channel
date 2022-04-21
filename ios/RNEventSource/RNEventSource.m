#import "RNEventSource.h"

#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTUtils.h>
#import <objc/runtime.h>

#import "TRVSEventSource/TRVSEventSource.h"

#if __has_include(<React/RCTBridge.h>)
#import <React/RCTBridge.h>
#elif __has_include("RCTBridge.h")
#import "RCTBridge.h"
#else
#import "React/RCTBridge.h"
#endif

@implementation TRVSEventSource (React)

- (NSNumber *)reactTag
{
  return objc_getAssociatedObject(self, _cmd);
}

- (void)setReactTag:(NSNumber *)reactTag
{
  objc_setAssociatedObject(self, @selector(reactTag), reactTag, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation RNEventSource
{
    NSMutableDictionary<NSNumber *, TRVSEventSource *> *_sources;
}

@synthesize eventSource;
@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (void)dealloc
{
  for (TRVSEventSource *source in _sources.allValues) {
    [source close];
  }
}

RCT_EXPORT_METHOD(connect:(NSString *)URLString sourceID:(nonnull NSNumber *)sourceID)
{
  NSURL *serverURL = [NSURL URLWithString:URLString];

  TRVSEventSource *source = [[TRVSEventSource alloc] initWithURL:serverURL];
  source.delegate = self;
  source.reactTag = sourceID;
  
  [source open];

  if (!_sources) {
    _sources = [NSMutableDictionary new];
  }

  _sources[sourceID] = source;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"eventsourceOpen", @"eventsourceFailed", @"eventsourceEvent"];
}

- (void)eventSourceDidOpen:(TRVSEventSource *)eventSource
{
//    [_bridge.eventDispatcher sendDeviceEventWithName:@"eventsourceOpen" body:@{
//      @"id": eventSource.reactTag
//    }];
    
    [self.bridge
         enqueueJSCall:@"RCTDeviceEventEmitter"
         method: @"emit"
         args: @[@"eventsourceOpen", @{@"id": eventSource.reactTag}]
         completion:NULL];
}

- (void)eventSource:(TRVSEventSource *)eventSource didFailWithError:(NSError *)error
{
//    [_bridge.eventDispatcher sendDeviceEventWithName:@"eventsourceFailed" body:@{
//      @"message": error.localizedDescription,
//      @"id": eventSource.reactTag
//    }];
    
    [self.bridge
     enqueueJSCall:@"RCTDeviceEventEmitter"
     method: @"emit"
     args: @[@"eventsourceFailed", @{
                 @"message": error ? error.localizedDescription : @"The request timed out.",
                 @"id": eventSource.reactTag
                 }]
     completion:NULL];
    
    [eventSource close];
}

- (void)eventSource:(TRVSEventSource *)eventSource didReceiveEvent:(TRVSServerSentEvent *)event
{
    NSString *data = [[NSString alloc] initWithData:event.data encoding:NSUTF8StringEncoding];

//    [_bridge.eventDispatcher sendDeviceEventWithName:@"eventsourceEvent" body:@{
//      @"type": event.event ?: @"message",
//      @"data": RCTNullIfNil(data),
//      @"id": eventSource.reactTag
//    }];
    
    [self.bridge
     enqueueJSCall:@"RCTDeviceEventEmitter"
     method: @"emit"
     args: @[@"eventsourceEvent", @{
                 @"type": event.event ?: @"message",
                 @"data": RCTNullIfNil(data),
                 @"id": eventSource.reactTag
                 }]
     completion:NULL];
}


RCT_EXPORT_METHOD(close:(nonnull NSNumber *)sourceID)
{
    [_sources[sourceID] close];
    [_sources removeObjectForKey:sourceID];
    RCTLogInfo(@"RNEventSource: Closed %@", sourceID);
//    [self.bridge
//     enqueueJSCall:@"RCTDeviceEventEmitter"
//     method: @"emit"
//     args: @[@"eventsourceFailed", @{
//                 @"message": @"RNEventSource: Closed.",
//                 @"id": ((TRVSEventSource*)_sources[sourceID]).reactTag
//                 }]
//     completion:^() {
//         [_sources[sourceID] close];
//         [_sources removeObjectForKey:sourceID];
//     }];
}

@end
