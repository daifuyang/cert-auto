import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';

const profile = process.argv[2] || 'enterprise';
const region = process.argv[3] || 'cn-shanghai';
const configPath = path.join(homedir(), '.config/aic/config.toml');
const config = readFileSync(configPath, 'utf8');

const sectionPattern = new RegExp(
  String.raw`\[aliyun\.profiles\.${profile.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\]([\s\S]*?)(?=\n\[|$)`,
);
const section = config.match(sectionPattern)?.[1];

if (!section) {
  throw new Error(`Aliyun profile not found in AIC config: ${profile}`);
}

function readTomlString(key) {
  const match = section.match(new RegExp(String.raw`^${key}\s*=\s*"([^"]+)"`, 'm'));
  return match?.[1];
}

const accessKeyId = readTomlString('accessKeyId');
const accessKeySecret = readTomlString('accessKeySecret');

if (!accessKeyId || !accessKeySecret) {
  throw new Error(`Aliyun profile is missing accessKeyId/accessKeySecret: ${profile}`);
}

execFileSync(
  'aliyun',
  [
    'configure',
    'set',
    '--profile',
    profile,
    '--mode',
    'AK',
    '--region',
    region,
    '--access-key-id',
    accessKeyId,
    '--access-key-secret',
    accessKeySecret,
  ],
  { stdio: 'inherit' },
);
