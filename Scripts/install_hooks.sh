#!/bin/bash

# 安装 Git Hooks 脚本
# 用法: ./Scripts/install_hooks.sh

echo "🔧 安装 SSHAIClient Git Hooks..."

# 创建 hooks 目录
mkdir -p .git/hooks

# 创建 pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

echo "🔍 执行代码审查检查..."

# 运行代码审查脚本
if swift Scripts/code_review_check.swift; then
    echo "✅ 代码审查通过"
else
    echo "❌ 代码审查失败，请修复问题后再提交"
    echo "📖 详细规范请查看: TECHNICAL_SPECIFICATION.md"
    exit 1
fi

# 运行 Swift 构建测试
echo "🔨 运行构建测试..."
if swift build 2>/dev/null; then
    echo "✅ 构建成功"
else
    echo "❌ 构建失败"
    exit 1
fi

# 运行单元测试（可选，取消注释启用）
# echo "🧪 运行单元测试..."
# if swift test 2>/dev/null; then
#     echo "✅ 测试通过"
# else
#     echo "❌ 测试失败"
#     exit 1
# fi

echo "🎉 所有检查通过，可以提交！"
EOF

# 设置执行权限
chmod +x .git/hooks/pre-commit

echo "✅ Git Hooks 安装成功！"
echo ""
echo "现在每次 git commit 前都会自动执行："
echo "  1. 代码规范检查"
echo "  2. 构建测试"
echo ""
echo "如需跳过检查，可使用: git commit --no-verify"
