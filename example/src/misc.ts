import { Dirs, FileSystem } from 'react-native-file-access';

/**
 * Teilt eine große Datei in kleinere Dateien (Chunks), ohne sie ganz in den RAM zu laden.
 *
 * @param {string} inputPath - Vollständiger Pfad zur Quelldatei (z. B. file:///...)
 * @param {number} chunkSize - Max Größe eines Chunks in Bytes (z. B. 5 * 1024 * 1024 = 5 MB)
 * @param {string} outputDir - Pfad zu Zielordner, in dem Chunks gespeichert werden
 * @returns {Promise<string[]>} - Liste der erzeugten Chunk-Dateipfade
 */
export async function splitFileIntoChunks(inputPath: string) {
  const stat = await FileSystem.stat(normalizeFilePath(inputPath));
  const fileSize = Number(stat.size);
  const requestOptions = {
    method: 'POST',
  };
  var key = '';
  var uploadId = '';
  var partSize = 0;
  var urls: string[] = [];
  try {
    const response = await fetch(
      'https://dev09.ysendit.com/upload/MobileS3/getUrls/' + fileSize,
      requestOptions
    );

    const data = await response.json();

    for (const [partNumber, value] of Object.entries(data.urls)) {
      const index = parseInt(partNumber, 10) - 1;
      if (typeof value === 'string') {
        urls[index] = value;
      }
    }
    partSize = data.partSize;
    uploadId = data.uploadId;
    key = data.key;

    const uploadDirExists = await FileSystem.isDir(
      Dirs.DocumentDir + `/uploads`
    );
    if (!uploadDirExists) {
      await FileSystem.mkdir(Dirs.DocumentDir + `/uploads`);
    }

    const filePath = Dirs.DocumentDir + `/uploads/${key}`;
    if (!(await FileSystem.isDir(filePath))) {
      await FileSystem.mkdir(filePath);
    }

    const tasks = urls.map((_, i) => async () => {
      const offset = i * partSize;
      const currentLength = Math.min(partSize, fileSize - offset);
      var chunk: string | null = await FileSystem.readFileChunk(
        normalizeFilePath(inputPath),
        offset,
        currentLength,
        'base64'
      );
      await FileSystem.writeFile(
        Dirs.DocumentDir + `/uploads/${key}/${i}`,
        chunk,
        'base64'
      );
      chunk = null;
    });

    await runWithConcurrencyLimit(tasks, 3); // max. 3 gleichzeitig aktiv
  } catch (error) {
    console.error(error);
  }

  await createS3Config(uploadId, key, urls);

  return key;
}

async function runWithConcurrencyLimit(
  tasks: (() => Promise<void>)[],
  maxConcurrency: number
) {
  const results: Promise<void>[] = [];
  let index = 0;

  async function worker() {
    while (index < tasks.length) {
      const currentIndex = index++;
      if (tasks[currentIndex] !== undefined) {
        // @ts-ignore
        await tasks[currentIndex]();
      }
    }
  }

  for (let i = 0; i < maxConcurrency; i++) {
    results.push(worker());
  }

  await Promise.all(results);
}

async function createS3Config(
  uploadId: string,
  key: string,
  uploadUrls: string[]
) {
  const parts = uploadUrls.map((element) => {
    return {
      eTag: '',
      uploadUrl: element,
    };
  });
  const data = {
    key: key,
    uploadId: uploadId,
    parts: parts,
  };
  const jsonString = JSON.stringify(data, null, 2); // Pretty-print mit Einrückung
  await FileSystem.writeFile(
    Dirs.DocumentDir + `/uploads/${key}/s3.json`,
    jsonString,
    'utf8'
  );
}

async function getS3Config(key: string) {
  return JSON.parse(
    await FileSystem.readFile(
      Dirs.DocumentDir + `/uploads/${key}/s3.json`,
      'utf8'
    )
  );
}

export async function complete(uploadId: string, key: string) {
  const parts = (await getS3Config(key)).parts;
  parts.map((value: { eTag: string }, index: number) => {
    return {
      ETag: value.eTag,
      PartNumer: index + 1,
    };
  });
  const requestOptions = {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ parts: parts }),
  };

  try {
    await fetch(
      'https://dev09.ysendit.com/upload/MobileS3/complete/' +
        uploadId +
        '/' +
        key,
      requestOptions
    );
  } catch (error) {
    console.error(error);
  }
}

function normalizeFilePath(uri: string): string {
  if (uri.startsWith('file://')) {
    return uri.replace('file://', '');
  }
  return uri;
}
