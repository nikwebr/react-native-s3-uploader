import { Text, View, StyleSheet, Button } from 'react-native';
import { useUploads } from 'react-native-s3-uploader';
import type { FileCompletionInfo } from 'react-native-s3-uploader';
import { pick } from '@react-native-documents/picker';
import { splitFileIntoChunks } from './misc';
import ProgressBar from './ProgressBar';

const onUpload = async (
  id: string,
  uploadCompletionInfo: FileCompletionInfo[]
) => {
  console.log('finished upload', id);
  for (const completedFile of uploadCompletionInfo) {
    await fetch(
      'https://dev09.ysendit.com/upload/MobileS3/complete/' +
        completedFile.awsUploadId +
        '/' +
        completedFile.awsKey,
      {
        method: 'POST',
        body: JSON.stringify({
          parts: completedFile.parts,
        }),
        headers: {
          'Content-type': 'application/json; charset=UTF-8',
        },
      }
    );
  }
};

export default function App() {
  const { upload, uploads } = useUploads(onUpload);
  return (
    <View style={styles.container}>
      <Button
        title="open file"
        onPress={async () => {
          const result = await pick({
            mode: 'import',
            allowMultiSelection: true,
          });
          const keys: string[] = [];
          for (const file of result) {
            keys.push(await splitFileIntoChunks(file.uri));
          }
          await upload(`${new Date().getTime()}`, keys);
        }}
      />

      <>
        {uploads.map((item) => (
          <>
            <ProgressBar progress={item.progress} />
            <Text>State: {item.state} %</Text>
            <Button title="Pause" onPress={() => item.pause()} />
            <Button title="Resume" onPress={() => item.resume()} />
            <Button title="Cancel" onPress={() => item.cancel()} />
            <Button title="Restart" onPress={() => item.restart()} />
            <Button title="Clear" onPress={() => item.clear()} />
          </>
        ))}
      </>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
