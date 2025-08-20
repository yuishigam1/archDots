#!/bin/bash

# Set commit message to current date and time
commit_message=$(date +"%Y-%m-%d %H:%M:%S")

# === 1. Backup: Copy folders to archBackup ===
backup_target="/home/yash/repo/extra/archBackup"
echo "🔁 Backing up myApps, myIcons, and myText into: $backup_target"

for dir in myApps myIcons myText; do
  src="/home/yash/$dir"
  dest="$backup_target/$dir"
  if [ -d "$src" ]; then
    rm -rf "$dest"
    cp -r "$src" "$backup_target/"
    echo "✔ Copied $dir to archBackup"
  else
    echo "⚠ $dir not found, skipping backup..."
  fi
done

# === 2. Git Commit + Push all repositories ===
repos=("/home/yash/repo/personal" "/home/yash/repo/books" "/home/yash/repo/college" "/home/yash/repo/extra")

for repo in "${repos[@]}"; do
  echo "📁 Navigating to $repo..."
  cd "$repo" || {
    echo "❌ Directory $repo not found!"
    continue
  }

  git add --all
  git commit -m "$commit_message"
  echo "🔄 Pulling latest changes..."
  git pull --rebase
  echo "🚀 Pushing changes..."
  git push
  cd ~
done

# === 3. Restore: Copy folders back to $HOME ===
echo "🔄 Restoring myApps, myIcons, and myText from archBackup to ~/"

for dir in myApps myIcons myText; do
  src="$backup_target/$dir"
  dest="/home/yash/$dir"
  if [ -d "$src" ]; then
    rm -rf "$dest"
    cp -r "$src" "$dest"
    echo "✔ Restored $dir to ~/"
  else
    echo "⚠ Backup for $dir not found, skipping restore..."
  fi
done

echo "✅ Done! Backup → Git → Restore cycle complete with commit message: $commit_message"
