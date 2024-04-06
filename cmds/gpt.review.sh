#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
. ../../.env.sh
# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "g-review" "Review a file using OpenAI's GPT-4"
fn_arg_accept 'f:' 'filepath' 'The file to review'
fn_arg_accept 'm?' 'model' 'OpenAI model' 'gpt-4'
fn_arg_accept 's?' 'specialty' 'A specialty to refine the system prompt. (eg. nextjs, vscode, etc)' ''
fn_arg_accept 'c?' 'context-file' 'A file whose contents we append to the user message.' ''
fn_arg_parse "$@"
filepath="$(fn_get_arg 'filepath')"
model="$(fn_get_arg 'model')"
specialty="$(fn_get_arg 'specialty')"
add_context_file="$(fn_get_arg 'context-file')"

n=$'\n'

lang=""
add_context=""
if [ -n "$add_context_file" ]; then
  if [ ! -f "$add_context_file" ]; then
    log.throw "The context file provided does not exist."
  fi
  add_context="$(cat "$add_context_file")"
fi
if [ -n "$specialty" ]; then
  specialty="Your expertise is $specialty."
fi
if [ "$(echo $filepath | grep "\.sh$")" ]; then
  lang="shell"
fi
if [ -z "$lang" ]; then
  if [ "$(echo $filepath | grep "\.jsx$")" ] || [ "$(echo $filepath | grep "\.tsx$")" ]; then
    lang="jsx"
  fi
fi
if [ -z "$lang" ]; then
  if [ "$(echo $filepath | grep "\.js$")" ]; then
    lang="javascript"
  fi
fi
if [ -z "$lang" ]; then
  if [ "$(echo $filepath | grep "\.ts$")" ]; then
    lang="typescript"
  fi
fi
if [ -z "$lang" ]; then
  if [ "$(echo $filepath | grep "\.py$")" ]; then
    lang="python"
  fi
fi
if [ -z "$lang" ]; then
  if [ "$(echo $filepath | grep "\.rb$")" ]; then
    lang="ruby"
  fi
fi
if [ -z "$lang" ]; then
  if [ "$(echo $filepath | grep "\.go$")" ]; then
    lang="go"
  fi
fi
if [ -z "$lang" ]; then
  if [ "$(echo $filepath | grep "\.rs$")" ]; then
    lang="rust"
  fi
fi
if [ -z "$lang" ]; then
  if [ "$(echo $filepath | grep "\.html$")" ]; then
    lang="html"
  fi
fi
if [ -z "$lang" ]; then
  if [ "$(echo $filepath | grep "\.css$")" ]; then
    lang="css"
  fi
fi
if [ -z "$lang" ]; then
  log.throw "The file provided does not have a supported extension."
fi

file_contents="$(cat "$filepath")"
system_header="SYSTEM_PROMPT"
user_header="USER_PROMPT"
user_message="Please improve my code:$n\`\`\`$lang$n$file_contents$n\`\`\`$add_context"
system_prompt="You are a $lang programming expert whose job is to review code, find bugs, and suggest improvements. $specialty"
output="$system_header:$n$system_prompt$n$user_header:$n$user_message"
fn_print_line
echo "$output"
fn_print_line
# shellcheck disable=SC2086
escaped_system_prompt=$(echo $system_prompt | jq -R .)
# shellcheck disable=SC2086
escaped_user_message=$(echo $user_message | jq -R .)
# shellcheck disable=SC2086
escaped_model=$(echo $model | jq -R .)
# shellcheck disable=SC2086 disable=SC2000
word_count="$(echo $escaped_system_prompt | wc -c)"
echo "Would you like to run a $word_count word query? (y/n)"
read -r response
if [ "$response" '==' "y" ]; then
  assistant_response=$(
    curl "https://api.openai.com/v1/chat/completions" -H "Content-Type: application/json" -H "Authorization: Bearer ${secret_openai}" -d '{"model": '"${escaped_model}"',"messages": [{"role": "system", "content": '"${escaped_system_prompt}"'},{"role": "user", "content": '"${escaped_user_message}"'}]}' | jq -r '.choices[0].message.content'
  )
  fn_print_line
  echo "$assistant_response"
  fn_print_line
  exit 0
fi
