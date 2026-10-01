import {readFile, writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const webDataPath = path.join(root, 'web/packmon/dist/data.js');
const seedDirectory = path.join(root, 'TravelGenius/Resources/SeedData');

const currentSource = await readFile(webDataPath, 'utf8');
const prefix = 'export default ';
if (!currentSource.startsWith(prefix)) {
  throw new Error('Unexpected web data.js format');
}

const current = JSON.parse(currentSource.slice(prefix.length).trim().replace(/;$/, ''));
for (const key of ['prohibited_items', 'aviation_rules', 'border_rules']) {
  const filename = `${key}.json`;
  current[key] = JSON.parse(await readFile(path.join(seedDirectory, filename), 'utf8'));
}

await writeFile(webDataPath, `${prefix}${JSON.stringify(current)};\n`);
