//
//  RCTNativeS3Uploader.m
//  RNS3Uploader
//
//  Created by Niklas Weber on 17.04.25.
//

#import "RCTNativeS3Uploader.h"
#import "RNS3Uploader-Swift.h"

@implementation RCTNativeS3Uploader {
  NativeS3Uploader *uploader;
}

- (id) init {
  if (self = [super init]) {
  }
  return self;
}

- (void) initialize {
  uploader = [NativeS3Uploader get];
  [uploader registerProgressCallbackWithCallback:^(NSString *uploadId, NSNumber *progress) {
    [self emitOnUploadProgress:@{
      @"uploadId": uploadId,
      @"progress": progress
    }];
  }];
  [uploader registerStateCallbackWithCallback:^(NSString *uploadId, NSString *state) {
    [self emitOnUploadStateChange:@{
      @"uploadId": uploadId,
      @"state": state
    }];
  }];
}

- (void)cancel:(NSString *)id resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
  [uploader cancelWithId:id :resolve rejecter:reject];
}

- (NSNumber *)getProgress:(NSString *)id {
  NSError* err=nil;
  NSNumber* progress = [uploader getProgressWithId:id error:&err];
  if (err) {
      @throw [NSException exceptionWithName:err.domain
                                     reason:err.localizedDescription
                                   userInfo:@{ @"code": @(err.code) }];
    }
  return progress;
}


- (void)clear:(nonnull NSString *)id { 
  [uploader clearWithId:id];
}


- (void)listenersReady { 
  [uploader listenersReady];
}

- (nonnull NSString *)getState:(nonnull NSString *)id { 
  NSError* err=nil;
  NSString* state = [uploader getStateWithId:id error:&err];
  if (err) {
      @throw [NSException exceptionWithName:err.domain
                                     reason:err.localizedDescription
                                   userInfo:@{ @"code": @(err.code) }];
    }
  return state;
}

- (nonnull NSArray<NSString *> *)getUploads { 
  return [uploader getUploads];
}


- (void)upload:(nonnull NSString *)id fileDirs:(nonnull NSArray *)fileDirs { 
  NSError* err=nil;
  [uploader uploadWithId:id fileDirs:fileDirs error:&err];
  if (err) {
      @throw [NSException exceptionWithName:err.domain
                                     reason:err.localizedDescription
                                   userInfo:@{ @"code": @(err.code) }];
    }
}

- (void)pause:(nonnull NSString *)id resolve:(nonnull RCTPromiseResolveBlock)resolve reject:(nonnull RCTPromiseRejectBlock)reject { 
  [uploader pauseWithId:id :resolve rejecter:reject];
}


- (void)restart:(nonnull NSString *)id resolve:(nonnull RCTPromiseResolveBlock)resolve reject:(nonnull RCTPromiseRejectBlock)reject { 
  [uploader restartWithId:id :resolve rejecter:reject];
}


- (void)resume:(nonnull NSString *)id resolve:(nonnull RCTPromiseResolveBlock)resolve reject:(nonnull RCTPromiseRejectBlock)reject { 
  [uploader resumeWithId:id :resolve rejecter:reject];
}

- (nonnull NSArray<NSDictionary *> *)getUploadInfo:(nonnull NSString *)id { 
  NSError* err=nil;
  NSArray<NSDictionary *> * completionInfo = [uploader getUploadCompletionInfoWithId:id error:&err];
  if (err) {
      @throw [NSException exceptionWithName:err.domain
                                     reason:err.localizedDescription
                                   userInfo:@{ @"code": @(err.code) }];
    }
  return completionInfo;
}


- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeS3UploaderSpecJSI>(params);
}

+ (NSString *)moduleName
{
  return @"NativeS3Uploader";
}

@end
