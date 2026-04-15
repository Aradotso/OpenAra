```markdown
---
name: maeil-mail-contents
description: Archive of daily technical interview Q&A content (Frontend & Backend) from the maeil-mail.kr service
triggers:
  - browse maeil mail interview questions
  - find frontend interview content
  - search backend interview archive
  - use maeil mail contents
  - access technical interview questions
  - explore maeil mail fe be questions
  - find korean tech interview content
  - load maeil mail archive
---

# maeil-mail-contents

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

## What This Project Is

`maeil-mail-contents` is a static content archive repository preserving all technical interview Q&A content originally published by [maeil-mail.kr](https://maeil-mail.kr) — a daily email service that delivered frontend (FE) and backend (BE) interview questions to subscribers. After the service shut down, this repository was created to keep the content publicly accessible.

The repository contains:
- **Frontend (FE)** interview questions and answers
- **Backend (BE)** interview questions and answers
- Content organized by topic/category in markdown or structured files

---

## Repository Structure

```
maeil-mail-contents/
├── fe/          # Frontend interview content
├── be/          # Backend interview content
└── README.md
```

Each content item typically follows a pattern like:

```
fe/
  javascript/
    closure.md
    promise.md
    event-loop.md
  react/
    virtual-dom.md
    hooks.md
  css/
    box-model.md
be/
  java/
    jvm.md
  spring/
    ioc-di.md
  database/
    index.md
    transaction.md
```

---

## How to Use This Archive

### Clone the Repository

```bash
git clone https://github.com/maeil-mail/maeil-mail-contents.git
cd maeil-mail-contents
```

### Browse Content Locally

Since the content is markdown-based, you can read it directly or render it:

```bash
# List all FE topics
ls fe/

# List all BE topics
ls be/

# Read a specific question
cat fe/javascript/closure.md
```

### Search Across All Content

```bash
# Search by keyword across all content
grep -r "클로저" .

# Search in FE only
grep -r "Promise" fe/

# Search in BE only
grep -r "트랜잭션" be/

# Case-insensitive search
grep -ri "virtual dom" fe/
```

---

## Integrating Content Into Your Own App

### Reading Markdown Files (Node.js)

```js
import fs from 'fs';
import path from 'path';

// Read a specific interview question
function readContent(category, topic, filename) {
  const filePath = path.join(process.cwd(), category, topic, filename);
  return fs.readFileSync(filePath, 'utf-8');
}

const content = readContent('fe', 'javascript', 'closure.md');
console.log(content);
```

### Listing All Questions by Category (Node.js)

```js
import fs from 'fs';
import path from 'path';

function getAllQuestions(category) {
  const categoryPath = path.join(process.cwd(), category);
  const topics = fs.readdirSync(categoryPath, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory())
    .map(dirent => dirent.name);

  const questions = [];

  for (const topic of topics) {
    const topicPath = path.join(categoryPath, topic);
    const files = fs.readdirSync(topicPath)
      .filter(file => file.endsWith('.md'));

    for (const file of files) {
      questions.push({
        category,
        topic,
        filename: file,
        path: path.join(topicPath, file),
      });
    }
  }

  return questions;
}

const feQuestions = getAllQuestions('fe');
const beQuestions = getAllQuestions('be');

console.log(`FE Questions: ${feQuestions.length}`);
console.log(`BE Questions: ${beQuestions.length}`);
```

### Parsing Markdown Content (Node.js + gray-matter)

```bash
npm install gray-matter marked
```

```js
import fs from 'fs';
import matter from 'gray-matter';
import { marked } from 'marked';

function parseQuestion(filePath) {
  const raw = fs.readFileSync(filePath, 'utf-8');
  const { data: frontmatter, content } = matter(raw);

  return {
    meta: frontmatter,         // title, tags, difficulty, etc.
    rawMarkdown: content,
    html: marked(content),     // rendered HTML
  };
}

const question = parseQuestion('fe/javascript/closure.md');
console.log(question.meta);
console.log(question.html);
```

---

## Building a Simple Q&A Viewer (Next.js Example)

```bash
npx create-next-app@latest my-interview-app
cd my-interview-app

# Copy the contents archive into your project
cp -r ../maeil-mail-contents/fe ./content/fe
cp -r ../maeil-mail-contents/be ./content/be

npm install gray-matter
```

```js
// lib/questions.js
import fs from 'fs';
import path from 'path';
import matter from 'gray-matter';

const contentDir = path.join(process.cwd(), 'content');

export function getQuestionSlugs(category) {
  const dir = path.join(contentDir, category);
  const topics = fs.readdirSync(dir);
  const slugs = [];

  for (const topic of topics) {
    const topicPath = path.join(dir, topic);
    if (!fs.statSync(topicPath).isDirectory()) continue;
    const files = fs.readdirSync(topicPath).filter(f => f.endsWith('.md'));
    for (const file of files) {
      slugs.push({ category, topic, slug: file.replace('.md', '') });
    }
  }

  return slugs;
}

export function getQuestion(category, topic, slug) {
  const filePath = path.join(contentDir, category, topic, `${slug}.md`);
  const raw = fs.readFileSync(filePath, 'utf-8');
  const { data, content } = matter(raw);
  return { meta: data, content };
}
```

```jsx
// app/[category]/[topic]/[slug]/page.jsx
import { getQuestion, getQuestionSlugs } from '@/lib/questions';

export async function generateStaticParams() {
  const fe = getQuestionSlugs('fe');
  const be = getQuestionSlugs('be');
  return [...fe, ...be];
}

export default function QuestionPage({ params }) {
  const { category, topic, slug } = params;
  const { meta, content } = getQuestion(category, topic, slug);

  return (
    <main>
      <h1>{meta.title || slug}</h1>
      <p>Category: {category.toUpperCase()} / {topic}</p>
      <article dangerouslySetInnerHTML={{ __html: content }} />
    </main>
  );
}
```

---

## Python: Bulk Processing Content

```python
import os
import glob

def load_all_questions(base_dir='.', category='fe'):
    pattern = os.path.join(base_dir, category, '**', '*.md')
    files = glob.glob(pattern, recursive=True)
    questions = []

    for filepath in files:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        parts = filepath.replace(base_dir, '').strip('/').split('/')
        questions.append({
            'category': parts[0],
            'topic': parts[1] if len(parts) > 2 else 'general',
            'filename': parts[-1],
            'content': content,
        })

    return questions

fe_questions = load_all_questions(category='fe')
be_questions = load_all_questions(category='be')

print(f"Loaded {len(fe_questions)} FE questions")
print(f"Loaded {len(be_questions)} BE questions")
```

### Search Questions by Keyword (Python)

```python
def search_questions(questions, keyword):
    keyword_lower = keyword.lower()
    return [
        q for q in questions
        if keyword_lower in q['content'].lower()
        or keyword_lower in q['filename'].lower()
    ]

results = search_questions(fe_questions, 'closure')
for r in results:
    print(f"[{r['category']}] {r['topic']} / {r['filename']}")
```

---

## Common Patterns

### Random Daily Question (CLI Script)

```js
// scripts/daily-question.js
import fs from 'fs';
import path from 'path';

function randomQuestion(category) {
  const dir = path.join(process.cwd(), category);
  const allFiles = [];

  for (const topic of fs.readdirSync(dir)) {
    const topicPath = path.join(dir, topic);
    if (!fs.statSync(topicPath).isDirectory()) continue;
    for (const file of fs.readdirSync(topicPath)) {
      if (file.endsWith('.md')) {
        allFiles.push(path.join(topicPath, file));
      }
    }
  }

  const picked = allFiles[Math.floor(Math.random() * allFiles.length)];
  return fs.readFileSync(picked, 'utf-8');
}

const category = process.argv[2] || 'fe';
console.log(randomQuestion(category));
```

```bash
node scripts/daily-question.js fe
node scripts/daily-question.js be
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Files not found | Ensure you cloned the full repo including subfolders (`git clone --recurse-submodules`) |
| Korean text garbled | Open files with UTF-8 encoding explicitly (`utf-8` in Node.js / Python) |
| Empty directory listings | Check that `fe/` and `be/` directories exist at root level |
| Markdown not rendering | Install a markdown parser like `marked` (JS) or `markdown` (Python) |
| Search returns no results | Try Korean keywords — content is written in Korean |

### Verify Clone Is Complete

```bash
# Should show fe/ and be/ directories
ls maeil-mail-contents/

# Count total markdown files
find maeil-mail-contents/ -name "*.md" | wc -l
```

---

## Key Facts for AI Agents

- **Primary language**: Markdown (content), no executable code in the repo itself
- **Content language**: Korean (한국어)
- **Categories**: `fe` (Frontend), `be` (Backend)
- **Purpose**: Static archive — read-only reference material
- **License**: Not specified — treat as reference/educational use
- **No build step required** — clone and read directly
- **Stars**: 311 (growing rapidly at ~103/day), indicating high community value
```
