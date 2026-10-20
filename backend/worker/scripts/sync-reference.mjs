// 把 App 的 SeedData 原封不動（byte-exact）複製到 public/reference/v1/，
// 先驗證 manifest 的 SHA-256 與檔案一致，避免發布 App 會拒收的資料。
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const seed = path.resolve(here, "../../../TravelGenius/Resources/SeedData");
const out = path.resolve(here, "../public/reference/v1");

const manifestBytes = readFileSync(path.join(seed, "manifest.json"));
const manifest = JSON.parse(manifestBytes.toString("utf8"));
if (manifest.contractVersion !== 1) throw new Error(`Unsupported contractVersion ${manifest.contractVersion}`);

const files = Object.keys(manifest.files);
const data = new Map();
for (const name of files) {
  const bytes = readFileSync(path.join(seed, `${name}.json`));
  const hash = createHash("sha256").update(bytes).digest("hex");
  if (hash !== manifest.files[name]) {
    throw new Error(`${name}.json does not match manifest; run python3 scripts/build_reference_manifest.py`);
  }
  data.set(name, bytes);
}

rmSync(path.resolve(here, "../public"), { recursive: true, force: true });
mkdirSync(out, { recursive: true });
for (const [name, bytes] of data) writeFileSync(path.join(out, `${name}.json`), bytes);
writeFileSync(path.join(out, "manifest.json"), manifestBytes);
console.log(`Reference data: ${files.length} files + manifest -> public/reference/v1`);
