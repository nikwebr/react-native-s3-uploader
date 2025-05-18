# react-native-s3-uploader

Chunked background uploader to s3 compatible endpoints. Only works for the new architecture. The android side is not yet implemented.

Idea: The caller of this library is responsible for splitting the files in parts, for starting respective s3 multipart uploads and for generating presigned upload urls. The upload urls and file parts are passed to this library that in turn uploads the parts in the background. Once the upload is done, the caller is called to complete the multipart upload.

## Installation

```sh
npm install react-native-s3-uploader
```

### iOS
Add the "Background Modes > Background fetch" capability.

## useUploads Hook
The useUploads hook provides an upload method to start a new upload and a reactive uploads array that holds each started and not cleared upload. Each upload in the array has the following properties:

| Property   | Description                                                                                                                                                                         |
|------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `uploadId` | id passed to the upload() method                                                                                                                                                    |
| `progress` | number between 0 and 1 representing the upload progress. Right after app restart, the progress does not exactly reflect the actual progress. It is stable after at least 2 seconds. |
| `state`    | initialized, started, paused, done, canceled, error                                                                                                                                 |

The following methods are available, either on an upload object or via the hook:

| Method                                         | Description                                                                                                                                                                                                                                                                    |
|------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `upload(uploadId: string, fileDirs: string[])` | Creates a new upload with the id *uploadId*. Expects a separate dir for each file to upload. Each dir should contain the parts of the file to upload, named by the respective part number starting with 0. Also, each dir must contain a s3.json file that is specified below. |
| `async upload.pause()`                         | Pauses the upload and all ongoing network activities.<br> **Can only be called in the started state.**<br> Throws an error wih code "PAUSE" otherwise.                                                                                                                         |
| `async upload.resume()`                        | Resumes the upload and respective network activities.<br> **Can only be called in the paused state.**<br> Throws an error wih code "RESUME" otherwise.                                                                                                                         |
| `async upload.cancel()`                        | Stops all ongoing network activities and rests the upload progress. Thereafter, the upload can be restarted.<br> **Can be called in all states except the done state.**<br> Throws an error wih code "CANCEL" otherwise.                                                       |
| `async upload.restart()`                       | Starts the upload from the beginning. Depending on the s3 implementation, a new multipart upload should be started and set in the s3.json file.<br> **Can only be called in the canceled state.**<br> Throws an error wih code "RESTART" otherwise.                            |
| `upload.clear()`                               | Stops all ongoing network activities, deletes the file parts in each fileDir and all stored data belonging to the upload.<br> Can be called in all states. Should be called inside the onUpload callback to free space after completion.                                       |

The directory of each file must contain a s3.json file of the following structure:

```json
{
  "key": "s3KeyFromCreateMultipartUpload",
  "uploadId": "s3UploadIdFromCreateMultipartUpload",
  "parts": [
    {
      "eTag": "",
      "uploadUrl": "presignedUploadUrlForEachPart"
    }
  ]
}
```

The useUploads hook expects a callback function as a parameter that gets called once an upload is completed. In this callback function, call the s3 multipart completion api and then clear the upload.

## Usage
```js
import { FileCompletionInfo, useUploads } from 'react-native-s3-uploader';

const onUpload = async (id: string, uploadCompletionInfo: FileCompletionInfo[]) => {
  for (const completedFile of uploadCompletionInfo) {
    // call s3 complete endpoint
  }
}

const {upload, uploads} = useUploads(onUpload);
await upload(`uploadId`, fileDirs)
```

Refer to the example app for a more in-depth documentation of the libraries' usage.

## Conventional API
If you want to use the event subscriptions onUploadProgress() and onUploadStateChange() of the conventional API, do not use the useUploads() hook. Otherwise, it is not ensured that the subscriptions catch all events.

| Method                                                  | Description                                                                                                                                                                                                                                                                   |
|---------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `getUploads(): string[]`                                | Returns all ids of uploads that have not been cleared.                                                                                                                                                                                                                        |
| `upload(uploadId: string, fileDirs: string[])`          | Creates a new upload with the id *uploadId*. Expects a separate dir for each file to upload. Each dir should contain the parts of the file to upload, named by the respective part number starting with 0. Also, each dir must contain a s3.json file that is specified below. |
| `getState(uploadId: string): UploadState`               | Returns the current state of the upload. One of initialized, started, paused, done, canceled, error.                                                                                                                                                                          |
| `getProgress(uploadId: string): number`                 | Returns the current progress. Between 0 and 1. Right after app restart, the progress does not exactly reflect the actual progress. It is stable after at least 2 seconds.                                                                                                                                                                                                                               |
| `async pause(uploadId: string)`                         | Pauses the upload and all ongoing network activities.<br> **Can only be called in the started state.**<br> Throws an error wih code "PAUSE" otherwise.                                                                                                                        |
| `async resume(uploadId: string)`                        | Resumes the upload and respective network activities.<br> **Can only be called in the paused state.**<br> Throws an error wih code "RESUME" otherwise.                                                                                                                        |
| `async cancel(uploadId: string)`                        | Stops all ongoing network activities and rests the upload progress. Thereafter, the upload can be restarted.<br> **Can be called in all states except the done state.**<br> Throws an error wih code "CANCEL" otherwise.                                                      |
| `async restart(uploadId: string)`                       | Starts the upload from the beginning. Depending on the s3 implementation, a new multipart upload should be started and set in the s3.json file.<br> **Can only be called in the canceled state.**<br> Throws an error wih code "RESTART" otherwise.                           |
| `clear(uploadId: string)`                               | Stops all ongoing network activities, deletes the file parts in each fileDir and all stored data belonging to the upload.<br> Can be called in all states. Should be called inside the onUpload callback to free space after completion.                                      |
| `onUploadProgress(({uploadId, progress}) => {})`        | Called once the progress of an upload gets updated.                                                                                                                                                                                                                           |
| `onUploadStateChange(({uploadId, state}) => {})`        | Called once the state of an upload updates.                                                                                                                                                                                                                                   |
| `listenersReady()`                                      | Call this method once all onUploadProgress() and onUploadStateChange() handlers are set up. Events that are fired before this method is called are buffered and sent once the method is called.                                                                               |
| `getUploadInfo(uploadId: string): FileCompletionInfo[]` | Returns the awsUploadId, awsKey and eTags for all files of an upload. <br> **Can only be called in the done state.**<br> Throws an error otherwise.                                                                                                               |


## Example app
```sh
yarn
yarn example start
yarn example [android | ios]
```

## FAQ
### What happens in cases of network failures while an upload is in progress?
Failed parts are re-uploaded in the background up to 7 days since the start of the upload

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
