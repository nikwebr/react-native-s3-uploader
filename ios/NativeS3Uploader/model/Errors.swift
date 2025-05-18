//
//  Errors.swift
//  RNS3Uploader
//
//  Created by Niklas Weber on 26.04.25.
//

enum UploadInfoError: Error {
    // Throw when an invalid password is entered
    case chunkImportError

    // Throw when an expected resource is not found
    case s3DetailsParsingError
  
    case s3DetailsWritingError
  
    case uploadAlreadyExists
  
    case uploadDoesNotExist
  
  case resumeCalledOnUploadThatIsNotPaused

  case pauseCalledOnUploadThatIsNotStarted

  case restartCalledOnUploadThatIsNotCanceled

  case cancelCalledOnUploadThatIsDone
  
  case uploadNotDone

    // Throw in all other cases
    case unexpected(code: Int)
}

enum UploadURLSessionError: Error {
  case notInitialized
}

enum NativeS3UploaderError: Error {
  case uploadNotFound
}
