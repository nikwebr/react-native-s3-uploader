import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';
import type { EventEmitter } from 'react-native/Libraries/Types/CodegenTypes';

export enum UploadState {
  done = 'done',
  initialized = 'initialized',
  started = 'started',
  canceled = 'canceled',
  paused = 'paused',
  error = 'error',
}

export type UploadProgress = {
  uploadId: string;
  progress: number;
};

export type UploadStateChange = {
  uploadId: string;
  state: UploadState;
};

export type PartCompletionInfo = {
  ETag: string;
  PartNumber: number;
};

export type FileCompletionInfo = {
  awsUploadId: string;
  awsKey: string;
  parts: PartCompletionInfo[];
};

export interface Spec extends TurboModule {
  getUploads(): string[];
  getUploadInfo(id: string): FileCompletionInfo[];
  upload(id: string, fileDirs: string[]): void;
  // upload can be re-started by calling upload again with the same id
  cancel(id: string): Promise<void>;
  pause(id: string): Promise<void>;
  resume(id: string): Promise<void>;
  restart(id: string): Promise<void>;

  // only safe to call for ids returned by getUploads or after upload returns
  getProgress(id: string): number;
  // only safe to call for ids returned by getUploads or after upload returns
  getState(id: string): UploadState;
  // call once both listeners are set up
  listenersReady(): void;
  // deletes chunks and data once upload is completed
  clear(id: string): void;
  readonly onUploadProgress: EventEmitter<UploadProgress>;
  // done -> complete upload
  readonly onUploadStateChange: EventEmitter<UploadStateChange>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('NativeS3Uploader');
