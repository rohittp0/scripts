#!/usr/bin/env node

/**
 * update-readme.js
 *
 * This script:
 *   1. Reads `index.json` at the repo root.
 *   2. Finds `# Available Scripts` in `README.md`.
 *   3. Removes everything after it.
 *   4. Appends a new section describing all scripts in `index.json`.
 */

const fs = require('fs');
const path = require('path');

try {
  // 1) Read index.json from the repo root
  const scriptsDataPath = path.join(process.cwd(), 'index.json');
  if (!fs.existsSync(scriptsDataPath)) {
    console.log("index.json not found at repo root. Exiting...");
    process.exit(0);
  }

  const scriptsData = JSON.parse(fs.readFileSync(scriptsDataPath, 'utf8'));

  // 2) Read README.md
  const readmePath = path.join(process.cwd(), 'README.md');
  if (!fs.existsSync(readmePath)) {
    console.log("README.md not found at the repo root. Exiting...");
    process.exit(0);
  }

  let readme = fs.readFileSync(readmePath, 'utf8');

  // 3) Locate '# Available Scripts'
  const header = '# Available Scripts';
  const headerIndex = readme.indexOf(header);
  if (headerIndex === -1) {
    console.log("No '# Available Scripts' header found in README.md. Exiting...");
    process.exit(0);
  }

  // Remove everything after '# Available Scripts'
  const truncatedReadme = readme.substring(0, headerIndex + header.length) + '\n\n';

  // 4) Build new content from index.json
  let newContent = 'Below are the scripts found in `index.json`:\n\n';

  scriptsData.forEach((script) => {
    newContent += `## ${script.name}\n`;
    newContent += `- **Path**: \`${script.path}\`\n`;
    newContent += `- **Description**: ${script.desc || 'N/A'}\n\n`;
  });

  // Write the updated content back to README.md
  fs.writeFileSync(readmePath, truncatedReadme + newContent, 'utf8');

  console.log("README.md updated successfully!");
} catch (error) {
  console.error("Error updating README.md:", error);
  process.exit(1);
}