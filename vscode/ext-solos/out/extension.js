"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = void 0;
const vscode = require("vscode");
const fs = require("fs");
const path = require("path");
function activate(context) {
    const commandsFromPkgJSON = JSON.parse(fs.readFileSync(path.join(__dirname, "package.json"), "utf8")).contributes.commands;
    const printFile = (cmd) => {
        const [, camelCaseName] = cmd.command.split(".");
        const dashCaseName = camelCaseName
            .replace(/([a-z])([A-Z])/g, "$1-$2")
            .toLowerCase()
            .replace("-snippet", ".snippet");
        const preferredWorkspaceIndex = 3;
        const fallbackWorkspaceIndex = 0;
        const workspaceDir = vscode.workspace.workspaceFolders?.[preferredWorkspaceIndex] ||
            vscode.workspace.workspaceFolders?.[fallbackWorkspaceIndex];
        if (!workspaceDir) {
            vscode.window.showErrorMessage(`SolOS: neither workspace folder #${preferredWorkspaceIndex} or #${fallbackWorkspaceIndex} were found.`);
            return "";
        }
        const snippetFilePath = path.join(workspaceDir.uri.fsPath, "vscode-extension", "snippets", `${dashCaseName}.txt`);
        const contents = fs.readFileSync(snippetFilePath, "utf8");
        return dashCaseName.endsWith(".snippet")
            ? contents
            : contents.replace(/\$/g, "\\$");
    };
    context.subscriptions.push(vscode.languages.registerCompletionItemProvider("*", {
        provideCompletionItems(_document, position) {
            const completionItems = commandsFromPkgJSON.map((cmd) => {
                const completionItem = new vscode.CompletionItem(cmd.command);
                completionItem.kind = vscode.CompletionItemKind.Snippet;
                const rangeToRemove = new vscode.Range(position.line, position.character - 1, position.line, position.character);
                completionItem.additionalTextEdits = [
                    vscode.TextEdit.delete(rangeToRemove),
                ];
                completionItem.insertText = new vscode.SnippetString(printFile(cmd));
                return completionItem;
            });
            return completionItems;
        },
    }, "+"));
}
exports.activate = activate;
//# sourceMappingURL=extension.js.map