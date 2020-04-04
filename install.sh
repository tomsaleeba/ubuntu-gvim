#!/bin/bash
# idempotent install script for Tom's vim setup
set -euo pipefail
[ "${DEBUG:-0}" == "1" ] && set -x
thisDir=$(cd `dirname "$0"` && pwd)
bundleDir=$thisDir/dot-vim/bundle

isQuickMode=0
if [ ! -z "${1:-}" ]; then
  echo '[INFO] Quick mode enabled'
  isQuickMode=1
fi

function doSymlink {
  linkName=$1
  targetPath=$2
  if [ -L $linkName ]; then
    echo "[INFO] $linkName symlink exists, recreating it"
    rm $linkName
    ln -s $thisDir/$targetPath $linkName
  elif [ -e $linkName ]; then
    echo "[ERROR] $linkName already exists but is not a symlink, refusing to touch it"
    exit 1
  else
    echo "[INFO] $linkName symlink does not exist, creating it"
    ln -s $thisDir/$targetPath $linkName
  fi
}

doSymlink ~/.vimrc vimrc
doSymlink ~/.vim dot-vim

# Install gvim/neovim. Even if you want to use vim in a terminal, this is good
# because you get the fully featured vim (with clipboard integration)
if [ "$isQuickMode" == "1" ]; then
  echo '[INFO] skipping gvim/neovim install or update'
else
  echo '[INFO] installing/updating gvim'
  command -v apt-get > /dev/null 2>&1 && {
    # debian/ubuntu
    sudo apt-get -y install \
      exuberant-ctags \
      vim-gtk \
      libpython2.7-dev \
      g++ \
      cmake
  }
  command -v pacman > /dev/null 2>&1 && {
    # arch/manjaro
    sudo pacman --noconfirm --needed -Sy \
      ctags \
      gcc \
      cmake \
      neovim \
      python-neovim \
      # clang # for vim-codefmt on C
  }
fi

# YouCompleteMe
if [ "$isQuickMode" == "1" ]; then
  # if we pull fresh stuff but don't build it, things break. So just don't touch anything
  echo '[INFO] skipping YCM build'
else
  echo '[INFO] processing YouCompleteMe'
  pushd $bundleDir/YouCompleteMe > /dev/null
  git submodule sync --recursive
  git submodule update --init --recursive
  # TODO only run following if changes are present
  # maybe by comparing `find . -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" "` before and after
  python install.py --java-completer
  popd > /dev/null
fi

# compile procvim.vim
echo '[INFO] processing vimproc'
pushd $bundleDir/vimproc.vim > /dev/null
make
popd > /dev/null

echo "[INFO] updating plugins"
for curr in $(cd $bundleDir && ls); do
  echo "Updating $curr"
  cd $bundleDir/$curr
  git pull &
done
wait # for parallel updates

installPowerline () {
  pushd /tmp > /dev/null
  echo '[INFO] updating powerline fonts (fresh clone every time)'
  git clone https://github.com/powerline/fonts.git --depth=1
  cd fonts
  ./install.sh
  cd ..
  rm -fr fonts
  popd > /dev/null
}

if [ "$isQuickMode" == "1" ]; then
  echo '[INFO] skipping install/update of powerline fonts'
else
  installPowerline
fi

# Pathogen help tags generation (hoping NORC fixes the fact that it doesn't like :set inccommand)
echo '[INFO] running pathogen#helptags()'
vim -U NORC -c 'execute pathogen#helptags()' -c q

echo 'The following also need to be installed
  yarn global add prettier     # for vim-codefmt (js)
  yarn global add js-beautify  # for vim-codefmt (html)
'
