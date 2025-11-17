#!/bin/bash

echo "📁 开始创建 BreezeJP 项目目录结构..."

##############################
# lib/
##############################

mkdir -p lib/router

mkdir -p lib/core/constants
mkdir -p lib/core/utils
mkdir -p lib/core/widgets

mkdir -p lib/data/db
mkdir -p lib/data/models
mkdir -p lib/data/repositories

mkdir -p lib/features/learn/controller
mkdir -p lib/features/learn/pages
mkdir -p lib/features/learn/widgets
mkdir -p lib/features/learn/state

mkdir -p lib/features/word_detail
mkdir -p lib/features/settings
mkdir -p lib/features/review

mkdir -p lib/services

##############################
# assets/
##############################

mkdir -p assets/database
mkdir -p assets/audio/words
mkdir -p assets/audio/examples
mkdir -p assets/images

##############################
# test helpers
##############################
mkdir -p test/utils
mkdir -p test/features

##############################
# Done
##############################

echo "✅ 目录结构创建完成！"
echo ""
echo "现在你的项目结构已经准备好。"
