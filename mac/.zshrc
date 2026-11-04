export PATH="$HOME/.bun/bin:$PATH"
export PATH="$HOME/fvm/default/bin:$PATH"

# Android SDK
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Created by `pipx` on 2026-09-20 22:36:25
export PATH="$PATH:/Users/andrew/.local/bin"
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
export PATH="$PATH":"$HOME/.pub-cache/bin"

# Set Android Home directory
export ANDROID_HOME=$HOME/Library/Android/sdk

# Add Android SDK tools to PATH
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin


# Flutter / Dart
alias f="fvm flutter"
alias d="fvm dart"

# Project generators & tools
alias vite="bun create vite"
alias newexpo="bun create expo-app --template default@next"
alias mirror="scrcpy -m1920 -S"

# Bun replacements
alias npm="bun"
alias npx="bunx"
alias node="bun"
alias anstart="nohup emulator -avd Resizable_Experimental > /dev/null 2>&1 &"

# Claude CLI
alias con="claude --continue"
alias aaa="agy -dangerously-skip-permissions"
alias astart="adb kill-server && adb start-server"
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# Use PyPy as the default python
alias python=pypy3
alias python3=pypy3
alias pip='pypy3 -m pip'
