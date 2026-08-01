#!/bin/bash

export http_proxy="192.168.1.252:7890"
export https_proxy="192.168.1.252:7890"

CURRENT_PATH=$(cd $(dirname $0 ) ||exit;pwd)
TMP_PATH=${CURRENT_PATH}/tmp
LIST_PATH=${CURRENT_PATH}/list

# 定义输入文件
input_file="${CURRENT_PATH}/list.conf"  # 替换成你的文件名

# 声明两个数组
names=()
urls=()

# 逐行读取文件内容
#echo "list config file: ${input_file}"
while IFS=' ' read -r name url; do
    # 去除可能的空格和空行
    if [[ -n "$name" && -n "$url" ]]; then
        names+=("$name")
        urls+=("$url")
    fi
done < "${input_file}"

# 
# 打印数组内容（验证）
#echo "Names: ${names[@]}"
#echo "URLs: ${urls[@]}"


if [ ! -d "${TMP_PATH}" ]; then
   mkdir -p ${TMP_PATH}
fi

echo "Start Downloading...$(date '+%F %T')"

for i in "${!names[@]}"; do
    echo "Downloading ${names[$i]} from ${urls[$i]}..."
    curl -L --connect-timeout 10 --retry 3 -o "${TMP_PATH}/${names[$i]}" -s "${urls[$i]}"
    if [ $? -eq 0 ]; then
        echo "✅ Successfully downloaded ${names[$i]}"
        mv "${TMP_PATH}/${names[$i]}" "${LIST_PATH}/${names[$i]}"
        # 过滤 Mihomo 不兼容规则（如 USER-AGENT、IN-NAME 等）
        echo "开始过滤 Mihomo 不兼容规则..."
        # 删除 USER-AGENT 规则行
        if grep -q "^USER-AGENT" "${LIST_PATH}/${names[$i]}"; then
            echo "⚠️ 发现 USER-AGENT 规则，正在删除..."
            grep -v "^USER-AGENT" "${LIST_PATH}/${names[$i]}" > "${TMP_PATH}/${names[$i]}.tmp" && mv "${TMP_PATH}/${names[$i]}.tmp" "${LIST_PATH}/${names[$i]}"
        fi
        # 删除其他不兼容规则类型（IN-NAME、IN-TYPE、IN-USER、PROTOCOL、SCRIPT 等）
        for bad in "IN-NAME" "IN-TYPE" "IN-USER" "PROTOCOL" "SCRIPT"; do
            if grep -q "^$bad" "${LIST_PATH}/${names[$i]}"; then
                echo "⚠️ 发现 $bad 规则，正在删除..."
                grep -v "^$bad" "${LIST_PATH}/${names[$i]}" > "${TMP_PATH}/${names[$i]}.tmp" && mv "${TMP_PATH}/${names[$i]}.tmp" "${LIST_PATH}/${names[$i]}"
            fi
        done
        echo "✅ 过滤完成"
    else
        echo "❌ Failed to download ${names[$i]} (check URL or network)"
    fi
done

echo "Download completed."

echo "git action..."

git_repo_dir=$(git rev-parse --show-toplevel 2>/dev/null)  # 获取Git仓库根目录
# --- 2. 检查是否在Git仓库中 ---
if [ -z "$git_repo_dir" ]; then
    echo "❌ 当前目录不是Git仓库，跳过自动提交。"
    exit 1
fi

# 检查是否有文件变更
if git diff --quiet --exit-code; then
    echo "🔄 没有文件变更，无需提交。"
else
    # 添加变更并提交
    git add "${CURRENT_PATH}"/*
    git commit -m "自动更新脚本: $(date '+%F %T')"
    if [ $? -eq 0 ]; then
        echo "✅ Git提交成功！"
        # 可选：自动推送到远程仓库
        git push origin main  # 替换为你的分支名
    else
        echo "❌ Git提交失败（可能是无变更或冲突）"
    fi
fi

echo "🎉 操作完成！"
