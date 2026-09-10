#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

const repo = path.resolve(__dirname, '..', '..');
const wiki = path.join(repo, 'wiki');
const excluded = new Set(['AGENTS.md', 'index.md', 'log.md']);
const contentRoots = new Set([
  'architecture', 'backend', 'decisions', 'design', 'engineering', 'operations', 'process',
  'product', 'quality', 'raw'
]);
const livingTypes = new Set([
  'architecture', 'backend', 'design', 'engineering', 'operations', 'process', 'product', 'quality'
]);
const decisionStatuses = new Set(['proposed', 'accepted', 'implemented', 'superseded', 'rejected']);
const errors = [];

function walk(directory) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap(entry => {
    if (entry.name === '.obsidian' || entry.name === 'tools') return [];
    const full = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

function relative(file) {
  return path.relative(wiki, file).split(path.sep).join('/');
}

function frontmatter(text, file) {
  if (!text.startsWith('---\n')) {
    errors.push(`${file}: missing YAML frontmatter`);
    return {};
  }
  const end = text.indexOf('\n---\n', 4);
  if (end < 0) {
    errors.push(`${file}: unclosed YAML frontmatter`);
    return {};
  }
  const result = {};
  for (const line of text.slice(4, end).split('\n')) {
    const match = line.match(/^([a-z_]+):(?:\s*(.*))?$/);
    if (match) result[match[1]] = match[2] ?? '';
  }
  return result;
}

const markdownFiles = walk(wiki).filter(file => file.endsWith('.md'));
const indexedPages = new Set();
const indexText = fs.readFileSync(path.join(wiki, 'index.md'), 'utf8');
for (const match of indexText.matchAll(/\[[^\]]+\]\(([^)#]+)(?:#[^)]+)?\)/g)) {
  const target = path.resolve(wiki, decodeURIComponent(match[1]));
  indexedPages.add(relative(target));
}

const ids = new Map();
for (const file of markdownFiles) {
  const rel = relative(file);
  if (excluded.has(rel)) continue;
  const root = rel.split('/')[0];
  if (!contentRoots.has(root)) continue;
  const text = fs.readFileSync(file, 'utf8');
  const meta = frontmatter(text, rel);
  for (const key of ['title', 'type', 'status', 'tags']) {
    if (!(key in meta) || !meta[key]) errors.push(`${rel}: missing required frontmatter field '${key}'`);
  }
  if (meta.type === 'decision') {
    for (const key of ['id', 'date', 'sources']) {
      if (!(key in meta)) errors.push(`${rel}: decision missing '${key}'`);
    }
    if (!decisionStatuses.has(meta.status)) errors.push(`${rel}: invalid decision status '${meta.status}'`);
    if (!rel.startsWith('decisions/')) errors.push(`${rel}: decisions must live under decisions/<domain>/`);
    if (meta.id) {
      if (ids.has(meta.id)) errors.push(`${rel}: duplicate id '${meta.id}' also used by ${ids.get(meta.id)}`);
      ids.set(meta.id, rel);
    }
  } else if (meta.type === 'source') {
    if (meta.status !== 'immutable') errors.push(`${rel}: source status must be 'immutable'`);
    if (!('date' in meta) || !('origin' in meta)) errors.push(`${rel}: source requires date and origin`);
  } else {
    if (!livingTypes.has(meta.type)) errors.push(`${rel}: invalid page type '${meta.type}'`);
    if (!new Set(['current', 'historical']).has(meta.status)) errors.push(`${rel}: invalid living status '${meta.status}'`);
    if (!('updated' in meta)) errors.push(`${rel}: living page missing 'updated'`);
  }
  if (root !== 'raw' && !indexedPages.has(rel)) errors.push(`${rel}: page is not linked from index.md`);

  for (const match of text.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    const rawTarget = match[1].trim().split('#')[0];
    if (!rawTarget || /^(https?:|mailto:)/.test(rawTarget)) continue;
    const target = path.resolve(path.dirname(file), decodeURIComponent(rawTarget));
    if (!fs.existsSync(target)) errors.push(`${rel}: broken link '${match[1]}'`);
  }

  const secretPatterns = [
    /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
    /\bAIza[0-9A-Za-z_-]{30,}\b/,
    /\b(?:sk|rk)_(?:live|test)_[0-9A-Za-z]{16,}\b/
  ];
  for (const pattern of secretPatterns) {
    if (pattern.test(text)) errors.push(`${rel}: possible secret detected`);
  }
}

for (const rel of indexedPages) {
  if (!fs.existsSync(path.join(wiki, rel))) errors.push(`index.md: broken catalog entry '${rel}'`);
}

const log = fs.readFileSync(path.join(wiki, 'log.md'), 'utf8');
for (const heading of log.split('\n').filter(line => line.startsWith('## '))) {
  if (!/^## \[\d{4}-\d{2}-\d{2}\] [a-z-]+ \| .+/.test(heading)) {
    errors.push(`log.md: invalid entry heading '${heading}'`);
  }
}

try {
  const tracked = execFileSync('git', ['ls-files', 'wiki/.obsidian'], {cwd: repo, encoding: 'utf8'}).trim();
  if (tracked) errors.push('wiki/.obsidian/: personal Obsidian settings must not be tracked');
} catch (error) {
  errors.push(`unable to inspect tracked Obsidian settings: ${error.message}`);
}

if (errors.length) {
  console.error(`Wiki lint failed with ${errors.length} error(s):`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Wiki lint passed (${markdownFiles.length} Markdown files, ${ids.size} decisions).`);
