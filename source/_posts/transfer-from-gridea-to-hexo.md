
---
title: '从Gridea迁移到Hexo，过程及注意事项'
date: 2024-09-30 16:08:57
cover: /images/banner/1015_20240930_111405.webp
coverWidth: 1280
coverHeight: 720
tags: [hexo, git, nodejs, npm]
published: true
hideInList: false
feature: 
isTop: false
categories: 个人随笔
---

## 参考文章

> https://blog.dctewi.com/2024/01/summary-hexo-migration

## 安装 Hexo

安装Hexo其实挺傻瓜式的，基本按着[官方教程](https://hexo.io/zh-cn/docs/)走下来就ok了。
注：需要先准备 `nodejs` 和  `npm` ，由于各个系统安装步骤并不一致，建议使用 `ubuntu`，一键搞定安装。
```
npm install -g hexo-cli
hexo init
npm install
```

就万事大吉了，就非常的傻瓜式。

## 配置 _config.yml

```yaml
# 博客基础配置
title: 魔都水滴
subtitle: ''
description: ''
keywords: null
author: Margrop
language: cn
timezone: Asia/Shanghai
url: http://blog.margrop.com
permalink: '/post/:name/'  # 为完全兼容 Gridea 路径，换成了/post/:name/
permalink_defaults: null
pretty_urls:
  trailing_index: true
  trailing_html: true
source_dir: source
public_dir: public
tag_dir: tags
archive_dir: archives
category_dir: categories
code_dir: downloads/code
i18n_dir: ':lang'
skip_render: null
new_post_name: ':title.md'
default_layout: post
titlecase: false
external_link:
  enable: true
  field: site
  exclude: ''
filename_case: 0
render_drafts: false
post_asset_folder: false

# 想了下, Github Page在国内某些运营商网络下可能比较慢, 所以镜像了Gitee Page
# 这就需要生成相对路径而不是绝对路径
relative_link: true
future: true

# 和主题配合设置代码高亮
syntax_highlighter: highlight.js
highlight:
  line_number: true
  auto_detect: true
  tab_replace: ''
  wrap: true
  hljs: true
prismjs:
  preprocess: true
  line_number: true
  tab_replace: ''

# 分页相关配置
index_generator:
  path: ''
  per_page: 10
  order_by: '-date'
default_category: uncategorized
category_map: null
tag_map: null
meta_generator: true
date_format: YYYY-MM-DD
time_format: HH:mm:ss
updated_option: mtime
per_page: 10
pagination_dir: page
include: null
exclude: null
ignore: null

# 主题配置
theme: nexmoe

# 部署相关配置
deploy:
  - type: git
    repo: git@github.com:margrop/margrop2.github.io.git
    branch: hexo
    message: '[update] hexo updated at {{ now(''yyyy-MM-dd HH:mm:ss'') }}'

```

## 更换主题和安装插件

原版主题有种2016年Wordpress默认主题的味道，在[主题商店](https://hexo.io/themes/)翻了半天，找到了这个叫做[NexMoe](https://github.com/theme-nexmoe/hexo-theme-nexmoe)的主题，感觉还不错。

依旧是傻瓜式安装：

```bash
npm install hexo-theme-nexmoe hexo-renderer-inferno
hexo config theme nexmoe
hexo g && hexo s
```

进行一次hexo gen之后，会在根目录生成一个\_config.nexmoe.yml，这就是主题的配置文件了。这个主题的配置还挺多的，配置了半天。

* <span data-type="text" style="color: var(--b3-font-color2);">注：这里改用了与 Gridea 一致的 Gitalk 插件，请根据自己的需要自行调整</span>

```yaml
avatar: /images/avatar.webp # 网站 Logo
background: # 既是博客的背景，又是文章默认头图
    path: /images/background.webp
    width: 1280
    height: 720
favicon:
  href: /favicon.ico # 网站图标
  type: image/x-icon # 图标类型，可能的值有(image/png, image/vnd.microsoft.icon, image/x-icon, image/gif)

function: # 功能开关，可选值（true,false）
  globalToc: true # 开启该功能会自动开启文章 TOC（文章目录） 功能
  wordCount: true # 是否开启文章字数统计 (true, false)
  copyCode: true # 是否允许复制代码块

imageCDN: # 图片 CDN 功能
  enable: false # 开启该功能  
  origin: /../../images/ # 图片原始目录
  to: https://cdn.jsdelivr.net/gh/nexmoe/nexmoe.github.io@latest/images/ # 图片 CDN 域名

# 自定义样式，启用后可在站点的source文件夹下新建custom.css自定义站点样式
customStyles:
  - custom.css
  
# 附加图标库 使用说明：https://docs.nexmoe.com/config/icon
iconlib: # //at.alicdn.com/t/font_1038733_0xvrvpg9c0r.css

menu:
    回到首页:
        - /
        - icon-home
    文章归档:
        - /post/archives/
        - icon-container
    下载:
        - https://download.margrop.net/
        - icon-container
    常用链接:
        - /post/favorites/
        - icon-unorderedlist
    GithubStars:
        - /post/github-project-stars/
        - icon-github
    给我赞助:
        - /post/donate/
        - icon-coffee
    关于博主:
        - /post/about/
        - icon-info-circle

widgets:
    - name: search
      enable: true
      options: 
        search: 
            type: engine # 可选engine（用搜索引擎搜索）、swiftype、或local（本地搜索）
            url: https://cn.bing.com/search?q=site:margrop.com # 搜索引擎地址，在type为swiftype时无效 e.g:https://www.google.com/search?q={你的博客链接}
            id: <swiftype-id> # swiftype的id，见启用教程。在type为engine时无效
    - name: social
      enable: true
      options: 
        social:
            QQ群:
                - http://qm.qq.com/cgi-bin/qm/qr?_wv=1027&k=weD8TANNWdCOveAMcdmoAxOKt5owKkDS
                - icon-QQ
                - rgb(249, 174, 8)
                - rgba(249, 174, 8, .1)
            #哔哩哔哩:
            #    - https://space.bilibili.com/20238211
            #    - icon-bilibili
            #    - rgb(231, 106, 141)
            #    - rgba(231, 106, 141, .1)
            GitHub:
                - https://github.com/margrop/
                - icon-github
                - rgb(25, 23, 23)
                - rgba(25, 23, 23, .1)
            #知乎:
            #    - https://www.zhihu.com/people/nexmoe
            #    - icon-zhihu
            #    - rgb(30, 136, 229)
            #    - rgba(30, 136, 229, .1)
            #Twitter:
            #    - https://twitter.com/dennis_1125
            #    - icon-twitter
            #    - rgb(59, 151, 239)
            #    - rgba(59, 151, 239, .1)
            RSS:
                - /atom.xml
                - icon-rss
                - rgb(247, 132, 34)
                - rgba(247, 132, 34, .1)
    - name: category
      enable: true
    - name: tagcloud
      enable: true
      options: 
        maxTagcloud: 17  # 标签云组件显示的标签数量，0 表示不限制
    - name: hitokoto # 一言 widget
      enable: true
      options: 
        widgetHitokoto: # 一言组件
            loading_placeholder: '🚀 获取中...' # 正在一言时的占位符
            loading_error_placeholder: '🐞 获取失败...' # 加载一言失败时的占位符
            category: # 一言句子类型（可选），不配置的话随机获取，详见 https://developer.hitokoto.cn/sentence/#%E5%8F%A5%E5%AD%90%E7%B1%BB%E5%9E%8B-%E5%8F%82%E6%95%B0
    - name: archive #settings: widgetAchive
      enable: true
      options:
        widgetAchive: #文章归档组件
            archive_type: 'year' #按月展示还是按年展示
            show_count: true  #是否展示数量
    - name: recent_posts
      enable: true
    - name: link #settings: widgetLink
      enable: true
      options: 
        widgetLink: #链接组件
            - title: 魔都水滴Blog
              img: /images/avatar.webp
              link : https://blog.margrop.net/

copyTip: "著作权归作者所有。\n商业转载请联系作者获得授权，非商业转载请注明出处。\n来源：%url" # 自定义复制版权文案,使用 %url 代替当前页面URL, 修改为false禁用

slotHead: | 
  <script charset="UTF-8" id="LA_COLLECT" src="//sdk.51.la/js-sdk-pro.min.js"></script>
  <script>LA.init({id:"23bDEwNOu1L8NhV1",ck:"23bDEwNOu1L8NhV1"})</script>
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-4NGHEP8LEV"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());

    gtag('config', 'G-4NGHEP8LEV');
  </script>

slotFooter: | 
  <script src="https://cdn.jsdelivr.net/npm/mathjax@latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML"></script>
  <script>MathJax.Hub.Config({
      tex2jax: {
          inlineMath: [ ['$','$'], ["\\(","\\)"] ],
          processEscapes: true,
          skipTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code']
      }
  });
  MathJax.Hub.Queue(function() {
      var all = MathJax.Hub.getAllJax(), i;
      for(i=0; i < all.length; i += 1) {
          all[i].SourceElement().parentNode.className += ' has-jax';
      }
  });</script>

# 自定义侧边栏尾部内容
slotSidebar: |

# 评论框插槽
slotComment: | 
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/gitalk@1/dist/gitalk.css">
  <script src="https://cdn.jsdelivr.net/npm/gitalk@1/dist/gitalk.min.js"></script>
  <div id="gitalk-container"></div>
  <script>
    const gitalk = new Gitalk({
      clientID: 'Ov23lib2oiNKjG5B7I1N',
      clientSecret: '0a94653f17a7b9630d85b275008da4b38e0259dd',
      repo: 'margropcomment.margrop.io',      // The repository of store comments,
      owner: 'margrop',
      admin: ['margrop'],
      pagerDirection: 'last',
      id: window.location.pathname.substring(0, 49), // 使用 pathname 的前49个字符作为 id
      title: document.title,
      language: 'zh-CN', // 根据需要设置语言
      distractionFreeMode: false
    })
    gitalk.render('gitalk-container')
  </script>

slotCopyright: | 
  <strong>版权声明：</strong>本文采用 <a href="https://creativecommons.org/licenses/by-nc-sa/3.0/cn/deed.zh" target="_blank">CC BY-NC-SA 3.0 CN</a> 协议进行许可

slotArticleEnd: | 
```

之后把所需要的几个插件安装一下：

```
npm install hexo-generator-feed
npm install hexo-generator-json-content
npm install hexo-generator-sitemap
npm install hexo-word-counter
```

并且在_config.yml中进行配置：

```yaml
# hexo-generator-feed
feed:
  enable: true
  type: atom
  path: atom.xml
  limit: 20
  hub: null
  content: null
  content_limit: 140
  content_limit_delim: ' '
  order_by: '-date'
  icon: icon.png
  autodiscovery: true
  template: null

# hexo-generator-json-content
jsonContent:
  meta: false
  pages: false
  posts:
    title: true
    date: false
    path: true
    text: true
    raw: false
    content: false
    slug: false
    updated: false
    comments: false
    link: false
    permalink: false
    excerpt: false
    categories: false
    tags: false

# hexo-word-counter
symbols_count_time:
  symbols: true
  time: true
  total_symbols: false
  total_time: false
  exclude_codeblock: true
  awl: 4
  wpm: 700
  suffix: ''

# hexo-generator-sitemap
sitemap:
  path: sitemap.xml
  # template: ./sitemap_template.xml
  rel: true
  tags: false
  categories: false
```

到这里就大功告成了，剩下的就是迁移内容。

## 迁移Markdown

原 Gridea 目录：`./post/`  -> 新 Hexo 目录 `./source/_posts/`

## 迁移图片资源

原 Gridea 目录：`./post-images/`  -> 新 Hexo 目录 `./source/_posts/`
原 Gridea 文件：`./favicon.ico`  -> 新 Hexo 文件 `./source/favicon.ico`

## 

原 Gridea 目录：`./post/`  -> 新 Hexo 目录 `./source/post-images/`

## 其他的一些配置

### 配置 Gitalk

* 按照官网配下来就可以，本地配置在上方有写。
* 注：`Github` 对唯一 tag 的长度有限制，`Gridea` 使用的是 `pathname` 作为评论唯一 tag
* 上面的配置中，当 `pathname` 超过49字节时，`Gitalk` 使用前49个字节作为评论唯一 tag
<!--stackedit_data:
eyJoaXN0b3J5IjpbMjYwODMxNDk4LC0xMzQ0MDA0NTRdfQ==
-->