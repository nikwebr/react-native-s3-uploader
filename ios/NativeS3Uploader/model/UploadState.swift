//
//  UploadState.swift
//  RNS3Uploader
//
//  Created by Niklas Weber on 05.05.25.
//

import Foundation

public enum UploadState: String {
    case initialized
  
    case started

    case done
  
    case canceled
  
    case paused
  
    case error
}
