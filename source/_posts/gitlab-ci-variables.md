---
title: 'gitlab-ci-yml配置说明（官方文档翻译）'
date: 2023-04-02 09:02:29
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
## 重要的内置变量
`CI_COMMIT_REF_NAME`: The branch or tag name for which project is built.
`CI_CONFIG_PATH`: The path to the CI/CD configuration file. Defaults to .gitlab-ci.yml. Read-only inside a running pipeline.
`CI_PROJECT_PATH`: The project namespace with the project name included.
`CI_BUILDS_DIR`: The top-level directory where builds are executed.
`CI_PROJECT_DIR`: The full path the repository is cloned to, and where the job runs from. If the GitLab Runner builds_dir parameter is set, this variable is set relative to the value of builds_dir. For more information, see the Advanced GitLab Runner configuration.

<!-- more -->

## gitlab-ci-yml配置说明（官方文档翻译）
<https://github.com/szyhf/gitlab-study/blob/master/gitlab-ci.yml%E9%85%8D%E7%BD%AE%E8%AF%B4%E6%98%8E.md>

## gradle init 命令
<https://docs.gradle.org/current/samples/sample_building_java_applications_multi_project.html>


## GitLab CI流水线配置文件.gitlab-ci.yml详解
<https://meigit.readthedocs.io/en/latest/gitlab_ci_.gitlab-ci.yml_detail.html>

## 更多关于变量的说明
<https://docs.gitlab.com/ce/ci/variables/README.html>

<https://docs.gitlab.com/ee/ci/variables/predefined_variables.html>


