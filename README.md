# Elaina — MoonBit Markdown 解析器

将 Markdown 文本解析为 HTML 的轻量级解析器与渲染器，使用 MoonBit 编写。

## ✨ 特性

- 词法分析 → 语法分析 → HTML 渲染的清晰三段式流水线  
- 标题（#1–#6）
- 段落与多行段落换行（渲染为 `<br/>`）
- 围栏代码块（以反引号开始/结束，支持语言 class，如 `class="language-js"`）
- 无序列表（`-` 或单个 `*`）与有序列表（`1.`、`2.`…）
- 引用块的占位识别（当前渲染为空 `<blockquote></blockquote>`，后续完善）
- UTF‑8 友好：提供 `render_html_utf8` 与完整页面 `render_html_page`
- 直接写文件，避免 PowerShell 输出重定向导致的中文乱码

> 说明：目前行内强调/加粗/链接/图片等尚未解析为结构化 Inline 节点，后续在路线图中逐步完善。

## 📦 项目结构

```text
src/
    ast.mbt         # AST 定义（Text / Block 等）
    tokenizer.mbt   # 词法分析：把字符流切分为 Token
    parser.mbt      # 语法分析：把 Token 流构建为 Block 列表
    renderer.mbt    # 渲染：把 Block 渲染为 HTML（含 UTF-8 版本与完整页面）
    main.mbt        # 示例入口：读取 README.md，输出 output.html
    *_test.mbt      # 组件级快照测试（tokenizer/parser/renderer/utf8等）
```

## 🚀 快速开始

前置：已安装 MoonBit 工具链（参考 MoonBit 官方文档）。

- 运行示例入口（读取仓库根目录的 `README.md`，在同目录生成 `output.html`）：

```powershell
moon run ./src/main.mbt
```

- 打开生成的 `output.html` 查看 HTML 渲染结果。

> 注意：项目已改用 `fs` 写文件，避免使用 PowerShell `>` 重定向时可能出现的中文乱码。

## 🛠️ 自定义输入/输出路径

`src/main.mbt` 中示例默认：

```moonbit
let context = @fs.read_file_to_string("./README.md")
@fs.write_string_to_file("./output.html", html)
```

按需修改为你的 Markdown 路径与输出路径即可。

如需生成带 `<head>` 与 UTF‑8 meta 的完整 HTML 页面，建议使用 `render_html_page`：

```moonbit
let (page, err) = render_html_page(context)
@fs.write_string_to_file("./output.html", page)
```

## 📚 API 速览

渲染入口均返回 `(String, String?)`，第二个值为可选错误信息：

- `render_html(input)`：渲染为 HTML 片段（仅 `<body>` 内容）
- `render_html_utf8(input)`：UTF‑8 直出版（保留中文，安全转义特殊字符）
- `render_html_page(input)`：完整 HTML 文档（含 `<meta charset="utf-8">`）
- `render_html_from_utf8_bytes_lossy(bytes)`：从 UTF‑8 字节视图宽松解码后渲染

示例：

```moonbit
let md = "# 标题\n\n这是一个段落\n"
let (html, err) = render_html(md)
match err {
    None => println(html)
    Some(e) => println(e)
}
```

## 🧠 设计概览

- Tokenizer：聚合连续普通字符为 `Text`，识别 `#`、`*`、`` ` ``、`[`、`]`、`(`、`)`、`!`、`>`、`-`、`.` 等标记；兼容 CRLF/LF
- Parser：
    - 标题：行首 `#`×N + 可选空格 + 文本
    - 围栏代码块：行首为反引号(>=3)，直到下一处围栏；首行余部作为语言标识
    - 列表：无序（`-`/`*`）与有序（数字+`.`）
    - 段落：连续非空行合并，换行为 `<br/>`
    - 引用：占位（后续渲染为含内容的 `<blockquote>`）
- Renderer：提供普通版与 UTF‑8 直出版；可输出完整 HTML 页面

## 🗺️ 路线图

- 行内语法：强调、加粗、行内代码、链接、图片
- 引用内容渲染与嵌套列表
- 水平分割线、表格与自动链接
- 严格 HTML 转义（当前 `html_escape` 为直通实现）
- 更完善的错误处理与诊断信息
