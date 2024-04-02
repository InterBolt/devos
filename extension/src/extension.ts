import * as vscode from "vscode";
import * as fs from "fs";
import * as path from "path";

type Command = {
  command: string;
  title: string;
  category: string;
};

export function activate(context: vscode.ExtensionContext) {
  const commandsFromPkgJSON: Array<Command> = JSON.parse(
    fs.readFileSync(path.join(__dirname, "package.json"), "utf8")
  ).contributes.commands;

  const printLLMFile = (cmd: Command) => {
    const [, camelCaseName] = cmd.command.split(".");
    const dashCaseName = camelCaseName
      .replace(/([a-z])([A-Z])/g, "$1-$2")
      .toLowerCase()
      .replace("-snippet", ".snippet");
    const repoWorkspaceFolder = vscode.workspace.workspaceFolders?.[2];
    if (!repoWorkspaceFolder) {
      vscode.window.showErrorMessage(
        `Dev OS: did you change the code-workspace folder recently. The folder containing the LLM txt files is not found.`
      );
      return "";
    }
    const snippetFilePath = path.join(
      repoWorkspaceFolder.uri.fsPath,
      "extension",
      "snippets",
      `${dashCaseName}.txt`
    );
    const contents = fs.readFileSync(snippetFilePath, "utf8");
    return dashCaseName.endsWith(".snippet")
      ? contents
      : contents.replace(/\$/g, "\\$");
  };

  context.subscriptions.push(
    vscode.languages.registerCompletionItemProvider(
      "*",
      {
        provideCompletionItems(
          _document: vscode.TextDocument,
          position: vscode.Position
        ) {
          const completionItems = commandsFromPkgJSON.map((cmd) => {
            const completionItem = new vscode.CompletionItem(cmd.command);
            completionItem.kind = vscode.CompletionItemKind.Snippet;
            const rangeToRemove = new vscode.Range(
              position.line,
              position.character - 1,
              position.line,
              position.character
            );
            completionItem.additionalTextEdits = [
              vscode.TextEdit.delete(rangeToRemove),
            ];
            completionItem.insertText = new vscode.SnippetString(
              printLLMFile(cmd)
            );
            return completionItem;
          });
          return completionItems;
        },
      },
      "+"
    )
  );
}
