package com.s3uploader

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule

@ReactModule(name = S3UploaderModule.NAME)
class S3UploaderModule(reactContext: ReactApplicationContext) :
  NativeS3UploaderSpec(reactContext) {

  override fun getName(): String {
    return NAME
  }

  // Example method
  // See https://reactnative.dev/docs/native-modules-android
  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }

  companion object {
    const val NAME = "S3Uploader"
  }
}
