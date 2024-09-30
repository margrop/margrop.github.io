---
title: '如何在Mac上执行一行命令，同时运行多个Python脚本？'
date: 2021-02-25 15:52:15
tags: [mac,command,terminal,python]
published: true
hideInList: false
feature: 
isTop: false
---
目前有4个Python脚本，打算使用一条命令，同时执行这4个脚本，如何操作呢？
我目前采用的办法比较简陋，使用了5个shell脚本来实现，不知道还有没有更好的方法。

# shell脚本runAll.sh
```bash
#!/bin/bash
ls
open -a Terminal.app run17688821.sh
open -a Terminal.app run49763693.sh
open -a Terminal.app run857413.sh
open -a Terminal.app run856853.sh
```

<!-- more -->

# shell脚本run17688821.sh
```bash
#!/bin/bash
cd  ~/CodesTemp/yzf99-50/
python3 yzf_17688821.py
```

# shell脚本run49763693.sh
```bash
#!/bin/bash
cd  ~/CodesTemp/yzf99-50/
python3 yzf_49763693.py
```

# shell脚本run857413.sh
```bash
#!/bin/bash
cd  ~/CodesTemp/yzf99-50/
python3 yzf_857413.py
```

# shell脚本run856853.sh
```bash
#!/bin/bash
cd  ~/CodesTemp/yzf99-50/
python3 yzf_856853.py
```

# 参考文章
<https://stackoverflow.com/questions/989349/running-a-command-in-a-new-mac-os-x-terminal-window>
