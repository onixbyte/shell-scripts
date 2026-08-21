#!/bin/bash

# =================================================================
# GitLab Upgrade and Patch Script
# =================================================================

# Ensure the script is run as root to have necessary permissions for package management and patching
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

echo "--- 1. Stopping Puma and Sidekiq ---"
# Stop data processing and web services before upgrading to reduce the risk of database migration issues
gitlab-ctl stop puma
gitlab-ctl stop sidekiq

echo "--- 2. Updating GitLab via apt ---"
# Update package sources and install the latest version of gitlab-ce (change to gitlab-ee if using the EE edition)
apt-get update
apt-get install --only-upgrade gitlab-ce -y

echo "--- 3. Applying Custom Patches ---"

# 3.1 Applying language switcher patch
# if [ -f /etc/gitlab/patches/language_fix.patch ]; then
#     echo "Applying language_fix.patch..."
#     patch /opt/gitlab/embedded/service/gitlab-rails/app/helpers/preferred_language_switcher_helper.rb < /etc/gitlab/patches/language_fix.patch
# else
#     echo "Warning: language_fix.patch not found!"
# fi

# # 3.2 Applying footer patch (e.g., ICP number)
# if [ -f /etc/gitlab/patches/beian.patch ]; then
#     echo "Applying beian.patch..."
#     patch /opt/gitlab/embedded/service/gitlab-rails/app/views/devise/shared/_footer.html.haml < /etc/gitlab/patches/beian.patch
# else
#     echo "Warning: beian.patch not found!"
# fi

echo "--- 4. Verifying GitLab Version ---"
# Output the currently installed version information
gitlab-rake gitlab:env:info

echo "--- 5. Restarting GitLab Services ---"
# After upgrading, GitLab usually runs reconfigure automatically, but to ensure patches take effect, perform a full restart
gitlab-ctl restart

echo "--- Process Completed Successfully ---"