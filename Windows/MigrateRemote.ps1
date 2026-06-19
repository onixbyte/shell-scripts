# 确保脚本在遇到非致命错误时也能正常处理
$ErrorActionPreference = "Stop"

$currentDir = Get-Item .
Write-Host "🚀 开始扫描当前目录下的子文件夹: $($currentDir.FullName)" -ForegroundColor Cyan
Write-Host "--------------------------------------------------"

$repoCount = 0
$updatedCount = 0

# 获取当前目录下的所有子文件夹
$subDirs = Get-ChildItem -Directory

foreach ($dir in $subDirs) {
    # 切换到子文件夹路径
    Set-Location $dir.FullName

    # 1. 检测是否为 Git 仓库
    if (git rev-parse --is-inside-work-tree 2>$null) {
        $repoCount++
        $hasUpdates = $false
        
        # 2. 获取所有远程仓库名称
        $remotes = git remote
        
        foreach ($remote in $remotes) {
            # 获取当前 remote 的 URL
            $currentUrl = git remote get-url $remote
            
            # 3. 检查并替换域名
            if ($currentUrl -like "*git.onixbyte.com*") {
                $newUrl = $currentUrl -replace "git.onixbyte.com", "onixbyte.dev"
                
                # 首次发现匹配时，打印仓库名称
                if (-not $hasUpdates) {
                    Write-Host "📦 发现 Git 仓库: [$($dir.Name)]" -ForegroundColor Yellow
                    $hasUpdates = $true
                }
                
                Write-Host "   ⚙️  远程 [$remote]:"
                Write-Host "      旧地址: $currentUrl"
                Write-Host "      新地址: $newUrl" -ForegroundColor Green
                
                # 执行更新
                git remote set-url $remote $newUrl
            }
        }
        
        if ($hasUpdates) {
            Write-Host "   ✅ 该仓库域名已更新完毕。" -ForegroundColor Green
            Write-Host "--------------------------------------------------"
            $updatedCount++
        }
    }
}

# 恢复到初始执行路径
Set-Location $currentDir.FullName

Write-Host "🏁 扫描结束！" -ForegroundColor Cyan
Write-Host "📊 统计报告: 共检测了 $repoCount 个 Git 仓库，其中 $updatedCount 个执行了域名更新。" -ForegroundColor White