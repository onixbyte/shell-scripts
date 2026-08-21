#!/bin/bash

# 获取当前绝对路径，方便日志输出
BASE_DIR=$(pwd)
echo "🚀 开始扫描当前目录下的子文件夹: $BASE_DIR"
echo "--------------------------------------------------"

# 计数器
repo_count=0
updated_count=0

# 遍历当前目录下的所有一级子目录
for dir in "$BASE_DIR"/*/; do
    # 确保路径存在（防止空目录匹配）
    [ -d "$dir" ] || continue

    # 进入子目录
    cd "$dir"

    # 1. 检测是否为 Git 仓库
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        repo_count=$((repo_count + 1))
        dirname=$(basename "$dir")
        
        # 2. 获取所有的 remote 名称
        remotes=$(git remote)
        has_updates=false

        # 3. 遍历当前仓库的远程配置
        for remote in $remotes; do
            current_url=$(git remote get-url "$remote")
            
            # 检查是否匹配旧域名
            if [[ "$current_url" == *"git.onixbyte.com"* ]]; then
                new_url=${current_url//git.onixbyte.com/onixbyte.dev}
                
                # 如果是该仓库第一次发现匹配，打印仓库头部信息
                if [ "$has_updates" = false ]; then
                    echo "📦 发现 Git 仓库: [$dirname]"
                    has_updates=true
                fi
                
                echo "   ⚙️  远程 [$remote]:"
                echo "      旧地址: $current_url"
                echo "      新地址: $new_url"
                
                # 执行替换
                git remote set-url "$remote" "$new_url"
            fi
        done

        if [ "$has_updates" = true ]; then
            echo "   ✅ 该仓库域名已更新完毕。"
            echo "--------------------------------------------------"
            updated_count=$((updated_count + 1))
        fi
    fi

    # 返回上一级目录，准备检查下一个
    cd "$BASE_DIR"
done

echo "🏁 扫描结束！"
echo "📊 统计报告: 共检测了 $repo_count 个 Git 仓库，其中 $updated_count 个执行了域名更新。"