const fs = require('fs')
const path = require('path')

const findGitRoot = (dir) => {
  if (fs.existsSync(path.join(dir, '.git'))) {
    return dir
  }
  const parent = path.dirname(dir)
  if (parent === dir) {
    return null
  }
  return findGitRoot(parent)
}

const extensionDirname = path.basename(__dirname)
const repoRoot = findGitRoot(__dirname)

const toTitleCase = (string) => {
  return string
    .replace(/-/g, ' ')
    .replace(/(^\w{1})|(\s+\w{1})/g, letter => letter.toUpperCase())
}

const formatName = (string) => {
  return string
    .replace(/-([a-z])/g, (g) => g[1].toUpperCase())
    .replaceAll('.snippet', 'Snippet')
}

const createCommand = (name, title) => ({
  "command": `solos.${formatName(name)}`,
  "title": title,
  "category": "solos"
})

const commands = fs.readdirSync(path.join(repoRoot, extensionDirname, 'snippets'))
  .filter(filename => filename.endsWith('.txt'))
  .map(textFilename => createCommand(
    textFilename.replace('.txt', ''),
    toTitleCase(textFilename.replace('.txt', ''))
  ))

const packageJson = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'))
packageJson.contributes.commands = commands
fs.writeFileSync(path.join(__dirname, 'package.json'), JSON.stringify(packageJson, null, 2))
