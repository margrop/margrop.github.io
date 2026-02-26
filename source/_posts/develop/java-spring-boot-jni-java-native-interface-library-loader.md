---
title: Java基于 SpringBoot 的 JNI 本地方法库加载器
tags:
  - Java
  - springboot
  - spring
  - jni
  - so
  - dll
  - jnilib
  - dylib
  - MacOS
  - Linux
  - Windows
published: true
hideInList: false
isTop: false
categories:
  - develop
date: 2021-03-27 16:37:31
feature:
---
由于Java跨平台需要，自行写了一个跨平台的 JNI 本地方法库加载器。

# 简单实现逻辑
1. 根据环境变量`os.name`，判断当前系统属于`Windows`,`Linux`还是`MacOS`
2. 如果是`Linux`，继续判断是`CentOS`还是`Debian`
3. 读取 jar 包中的库文件
4. 根据文件名后缀`dll`、`so`、`jnilib`和`dylib`，过滤符合当前平台的库文件
5. 将当前平台的库文件复制到系统临时目录`java.io.tmpdir`
6. 使用`System.load`加载库文件

<!-- more -->

# 详细代码
```java
import cn.hutool.core.io.IoUtil;
import cn.hutool.core.util.StrUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;

import java.io.*;

public class NativeLibLoader {
    private static final Logger logger = LoggerFactory.getLogger(NativeLibLoader.class);

    public static void load(String[] snks) {
        String currentOS = System.getProperty("os.name");
        if (currentOS.contains("Windows")) {
            linuxPrefix(new String[]{"dir"});
            for (String snk : snks) {
                if (StrUtil.endWithIgnoreCase(snk, "dll")) {
                    loadFile(snk, snk);
                }
            }
        } else if (currentOS.contains("Linux")) {
            String linuxPrefix = linuxPrefix(new String[]{"/bin/bash", "-c", "cat /etc/*-release"});
            for (String snk : snks) {
                if (StrUtil.endWithIgnoreCase(snk, "so")) {
                    loadFile(linuxPrefix + "-" + snk, snk);
                }
            }
        } else if (currentOS.contains("Mac OS X")) {
            linuxPrefix(new String[]{"ls"});
            for (String snk : snks) {
                if (StrUtil.endWithIgnoreCase(snk, "jnilib") || StrUtil.endWithIgnoreCase(snk, "dylib")) {
                    loadFile(snk, snk);
                }
            }
        } else {
            logger.info("NativeLibLoader : not supported " + currentOS);
        }
    }

    private static String linuxPrefix(String[] args) {
        StringBuilder sbRead = new StringBuilder();
        StringBuilder sbErr = new StringBuilder();
        try {
            // 启动另一个进程来执行命令
            Process pro = Runtime.getRuntime().exec(args);
            pro.waitFor();
            try (BufferedReader read = new BufferedReader(new InputStreamReader(pro.getInputStream()));
                 BufferedReader err = new BufferedReader(new InputStreamReader(pro.getErrorStream()))) {
                String line;
                while ((line = read.readLine()) != null) {
                    logger.info(line);
                    sbRead.append(line);
                }

                while ((line = err.readLine()) != null) {
                    logger.error(line);
                    sbErr.append(line);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        String releaseInfo = sbRead.toString();
        if (releaseInfo.contains("Debian")) {
            return "debian";
        }
        return "centos";
    }

    public static void loadFile(String src, String snk) {
        String srcAndPath = "classpath:" + src;
        try {
            logger.info("NativeLibLoader : copy " + srcAndPath + " to " + snk);
            File file = copyResourceToTempDirFile(srcAndPath, snk);
            String filePath = file.getAbsolutePath();
            System.load(filePath);
            logger.info("NativeLibLoader : load " + filePath + " successful");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private static File copyResourceToTempDirFile(String src, String snk) throws IOException {
        File tempDir = new File(System.getProperty("java.io.tmpdir"));
        File tempDirFile = new File(tempDir, snk);

        PathMatchingResourcePatternResolver patternResolver = new PathMatchingResourcePatternResolver();
        Resource[] resources = patternResolver.getResources(src);

        if (resources.length == 0) {
            return null;
        }

        try (InputStream input = resources[0].getInputStream();
             OutputStream output = new FileOutputStream(tempDirFile)) {
            IoUtil.copy(input, output);
            tempDirFile.deleteOnExit();
            return tempDirFile;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
```

# 如何加载
* 启动时，运行`NativeLibLoader.load()`方法即可
```java
NativeLibLoader.load(new String[]{"jniortools.dll", "libortools.so", "libjniortools.so", "libortools.dylib", "libjniortools.jnilib"});
```