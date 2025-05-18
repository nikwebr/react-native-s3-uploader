//
//  RCTNativeS3Uploader.h
//  RNS3Uploader
//
//  Created by Niklas Weber on 17.04.25.
//

#import <Foundation/Foundation.h>
#import <NativeS3UploaderSpec/NativeS3UploaderSpec.h>
#import <React/RCTInitializing.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTNativeS3Uploader : NativeS3UploaderSpecBase <NativeS3UploaderSpec, RCTInitializing>
@end

NS_ASSUME_NONNULL_END
