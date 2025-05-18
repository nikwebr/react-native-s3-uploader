import { useCallback, useEffect, useState } from 'react';
import NativeS3Uploader, { UploadState } from './NativeS3Uploader';
import type {
  FileCompletionInfo,
  UploadProgress,
  UploadStateChange,
  PartCompletionInfo,
} from './NativeS3Uploader';
import {
  beginBackgroundTask,
  endBackgroundTask,
} from '@soreine/react-native-begin-background-task';
import type { EventSubscription } from 'react-native';
import React from 'react';

export type {
  FileCompletionInfo,
  UploadProgress,
  UploadStateChange,
  PartCompletionInfo,
};
export { UploadState, NativeS3Uploader as S3Uploader };

type Upload = {
  uploadId: string;
  progress: number;
  state: UploadState;
  clear: () => void;
  cancel: () => Promise<void>;
  pause: () => Promise<void>;
  restart: () => Promise<void>;
  resume: () => Promise<void>;
};

export function useUploads(
  onCompletion: (
    id: string,
    uploadCompletionInfo: FileCompletionInfo[]
  ) => Promise<void>
) {
  const [uploads, setUploads] = useState<Upload[]>([]);

  const clear = useCallback((uploadId: string) => {
    NativeS3Uploader.clear(uploadId);
    setUploads((oldUploads) =>
      oldUploads.filter((upload) => upload.uploadId !== uploadId)
    );
  }, []);

  const progressSubscription = React.useRef<null | EventSubscription>(null);
  const stateSubscription = React.useRef<null | EventSubscription>(null);

  useEffect(() => {
    let isMounted = true;

    const init = async () => {
      const ids = NativeS3Uploader.getUploads();

      console.log('ids', ids);

      if (!isMounted) {
        return;
      }

      const initialUploads = ids.map((uploadId) => ({
        uploadId,
        progress: NativeS3Uploader.getProgress(uploadId),
        state: NativeS3Uploader.getState(uploadId),
        pause: () => NativeS3Uploader.pause(uploadId),
        resume: () => NativeS3Uploader.resume(uploadId),
        cancel: () => NativeS3Uploader.cancel(uploadId),
        clear: () => clear(uploadId),
        restart: () => NativeS3Uploader.restart(uploadId),
      }));

      setUploads(initialUploads);
    };

    init();

    progressSubscription.current = NativeS3Uploader.onUploadProgress(
      ({ uploadId, progress }: UploadProgress) => {
        setUploads((prevUploads) =>
          prevUploads.map((u) =>
            u.uploadId === uploadId ? { ...u, progress } : u
          )
        );
      }
    );

    stateSubscription.current = NativeS3Uploader.onUploadStateChange(
      async ({ uploadId, state }: UploadStateChange) => {
        setUploads((prevUploads) =>
          prevUploads.map((u) =>
            u.uploadId === uploadId ? { ...u, state } : u
          )
        );

        if (state === UploadState.done) {
          const backgroundTaskId = await beginBackgroundTask();
          await onCompletion(
            uploadId,
            NativeS3Uploader.getUploadInfo(uploadId)
          );
          await endBackgroundTask(backgroundTaskId);
        }
      }
    );

    NativeS3Uploader.listenersReady();

    return () => {
      isMounted = false;
      progressSubscription.current?.remove();
      progressSubscription.current = null;
      stateSubscription.current?.remove();
      stateSubscription.current = null;
    };
  }, [clear, onCompletion]);

  const upload = useCallback(
    async (uploadId: string, fileDirs: string[]) => {
      NativeS3Uploader.upload(uploadId, fileDirs);
      setUploads((prevUploads) => [
        ...prevUploads,
        {
          uploadId,
          progress: 0,
          state: UploadState.initialized,
          pause: () => NativeS3Uploader.pause(uploadId),
          resume: () => NativeS3Uploader.resume(uploadId),
          cancel: () => NativeS3Uploader.cancel(uploadId),
          clear: () => clear(uploadId),
          restart: () => NativeS3Uploader.restart(uploadId),
        },
      ]);
    },
    [clear]
  );

  return { uploads, upload };
}
