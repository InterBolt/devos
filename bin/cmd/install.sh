#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

cmd.install() {
  # find every set function variable in the pattern pkg.*.install
  for var in $(compgen -A function | grep -E "^pkg\..*\.install$"); do
    # get the package name from the function name
    local pkg_name
    pkg_name=$(echo "$var" | sed -E 's/^pkg\.([^.]+)\.install$/\1/')
    # install the package
    log.info "Installing package $pkg_name."
    "$var"
  done
}

# brew install binutils
# brew install diffutils
# brew install ed --with-default-names
# brew install findutils --with-default-names
# brew install gawk
# brew install gnu-indent --with-default-names
# brew install gnu-sed --with-default-names
# brew install gnu-tar --with-default-names
# brew install gnu-which --with-default-names
# brew install gnutls
# brew install grep --with-default-names
# brew install gzip
# brew install screen
# brew install watch
# brew install wdiff --with-gettext
# brew install wget
