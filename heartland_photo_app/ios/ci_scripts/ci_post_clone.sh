# !/bin/sh
echo "change to ios folder"
# Install Flutter dependencies.
cd /Volumes/workspace/repository/ios
pwd

echo "installing flutter"

#Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

#Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
flutter precache --ios

#Install Flutter dependencies.
echo "calling pub get"
flutter pub get

HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

echo "installing pods"
pod install

echo "done"
exit 0
```