@test "aliased/*" {
  for file in ./aliased/*.sh; do
    if [[ $file == *".__test__.sh" ]]; then
      ./$file >&3
    fi
  done
}

@test "lib/*" {
  for file in ./lib/*.sh; do
    if [[ $file == *".__test__.sh" ]]; then
      ./$file >&3
    fi
  done
}
