# SUSTechMobile 图标来源

按用户要求，仅保留南方科技大学校徽的中央火炬（火焰与底座），排除外围文字和圆环。
背景为学校标识常用深青色 #004851，火炬保持原矢量文件的色彩与比例；不加文字或手工圆角。
iOS 自行应用桌面图标遮罩。

- 学校官方标识页：https://www.sustech.edu.cn/zh/school_logo.html
- 官方源文件包：https://www.sustech.edu.cn/uploads/%E6%A0%A1%E5%BE%BD.rar
- `sustech-emblem-source.ai`：来自该源文件包的 PDF-compatible AI，SHA256
  `316e4aadab9f3ff8897b0d129ea3b80fe94ce07b4556e83372f5679cfa27bb85`。
- 原始矢量第 5、6（从零计数）条填充路径分别为中央底座和火焰；不重新描摹。
- `torch-only.pdf`：仅含这两条原始路径的中间矢量文件。
- `AppIcon-preview.png`：1024×1024 不透明图标预览。
- `scripts/generate_app_icon.py`：使用 PyMuPDF/Pillow 从原矢量生成 iPhone/iPad 全套图标尺寸。

校徽图形及相应标识权利归南方科技大学。本项目继续明确标注非官方校园工具。
