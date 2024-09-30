---
title: 'Brew一键安装swagger2markup并生成markdown文档'
date: 2022-01-25 21:43:39
tags: [brew,swagger,markdown]
published: true
hideInList: false
feature: 
isTop: false
---
# 1. 一键安装
```
brew install swagger2markup-cli
```

<!-- more -->


# 2. 编辑配置文件
```
mkdir ~/.swagger2markup
vim ~/.swagger2markup/config.properties

swagger2markup.markupLanguage=MARKDOWN
swagger2markup.outputLanguage=EN
```

# 3. 转换文档
```
wget http://api-staging.gs-robot.com/robot-task/v2/api-docs
swagger2markup convert -i api-docs -d ~/Documents/api -c ~/.swagger2markup/config.properties
swagger2markup convert -i api-docs -f ~/Documents/api/api_all -c ~/.swagger2markup/config.properties
```

# 4. 使用说明
```
http://swagger2markup.github.io/swagger2markup/1.3.3/#_usage_guide_7
```
