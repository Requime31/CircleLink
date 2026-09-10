#!/usr/bin/env node

const {execFileSync} = require('node:child_process');
const path = require('node:path');

const repo = path.resolve(__dirname, '..', '..');
const arguments = Object.fromEntries(process.argv.slice(2).map(value => {
  const [key, ...rest] = value.split('=');
  return [key.replace(/^--/, ''), rest.join('=')];
}));
const base = arguments.base;
const head = arguments.head || 'HEAD';
const labels = new Set((arguments.labels || '').split(',').map(value => value.trim()).filter(Boolean));

if (!base) {
  console.error('Wiki impact check requires --base=<git-ref>.');
  process.exit(2);
}

const files = execFileSync('git', ['diff', '--name-only', `${base}...${head}`], {
  cwd: repo,
  encoding: 'utf8'
}).trim().split('\n').filter(Boolean);
const codeChanged = files.some(file =>
  file.startsWith('CircleLink/') || file.startsWith('CircleLinkTests/') ||
  file.startsWith('functions/') || ['firebase.json', 'firestore.rules', 'firestore.indexes.json'].includes(file)
);
const knowledgeChanged = files.some(file =>
  /^wiki\/(?:architecture|backend|decisions|design|engineering|operations|process|product|quality)\/.+\.md$/.test(file) ||
  ['wiki/index.md', 'wiki/log.md'].includes(file)
);

if (!codeChanged || knowledgeChanged || labels.has('wiki-not-required')) {
  console.log('Wiki impact gate passed.');
  process.exit(0);
}

console.error('Code changed without a knowledge update. Update the wiki or apply wiki-not-required after review.');
process.exit(1);
