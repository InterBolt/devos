const childProcess = require('child_process');

const check = () => {
  try {
    childProcess.execSync("which code", {
      encoding: 'utf8',
    })
  } catch (err) {
    console.log("Can't do that yet. First, open the VSCode command pallete and install `code` to your PATH.");
    process.exit(1);
  }
}

check();