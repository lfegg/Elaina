# Elaina — MoonBit Markdown 解析器

将 Markdown 文本解析为 HTML 的轻量级解析器与渲染器，使用 MoonBit 编写。

## ✨ 特性

- 标题规则：仅当 `#` 后有空格时才识别为标题（如 `#Title` 视为普通文本）
- 行内代码：支持反引号包裹的行内代码，内容严格 HTML 转义，并以 `<code>` 加浅色背景渲染
- 围栏代码块：
  - 支持前置缩进
  - 记录开栏反引号数量，闭栏需满足“长度 ≥ 开栏长度”，允许内层更短的反引号出现在代码内
  - 首行余部作为语言标识，渲染为 `<pre><code class="language-...">`
  - 额外提供带背景与“复制”按钮的容器（内置 Clipboard 调用）
- 列表：
  - 支持无序（`-`/`*`）与有序（数字+`.`）
  - 有序列表在代码块或空行之后继续编号，不会重置
  - ListItem 支持嵌套子块（段落、引用、列表、围栏代码等），可表达多层级结构
- 引用（blockquote）：语义化 `<blockquote>`，内部可包含段落/列表/代码块等子内容
- 文本安全：对 `&`、`<`、`>`、`"`、`'` 等字符进行 HTML 转义

> 说明：行内强调/加粗/链接/图片等高级行内语法仍在规划中，后续会逐步完善。

## 📦 项目结构

```
src/
    ast.mbt         # AST 定义（Text / Block 等）
    tokenizer.mbt   # 词法分析：把字符流切分为 Token
    parser.mbt      # 语法分析：把 Token 流构建为 Block 列表（含列表/引用/围栏等）
    renderer.mbt    # 渲染：把 Block 渲染为 HTML（含 UTF-8 版本与完整页面、复制按钮）
```

## 🚀 快速开始

前置：已安装 MoonBit 工具链（参考 MoonBit 官方文档）。

1. 运行示例入口（读取仓库根目录的 `README.md`，在同目录生成 `output.html`）：

    ```powershell
    moon run ./src/main.mbt
    ```

2. 打开生成的 `output.html` 查看 HTML 渲染结果。

> 备注：项目使用 `fs` 写文件，无需 PowerShell 的 `>` 重定向，避免编码问题。

## 🛠️ 自定义输入/输出路径

`src/main.mbt` 中示例默认：

```moonbit
let context = @fs.read_file_to_string("./README.md")
@fs.write_string_to_file("./output.html", html)
```

按需修改为你的 Markdown 路径与输出路径即可。

如需生成带 `<head>` 与 UTF‑8 meta 的完整 HTML 页面，使用 `render_html_page`：

```moonbit
let (page, err) = render_html_page(context)
@fs.write_string_to_file("./output.html", page)
```

## 📚 API 速览

所有渲染入口均返回 `(String, String?)`，第二个值为可选错误信息：

- `render_html(input)`：渲染为 HTML 片段（仅 `<body>` 内容）
- `render_html_utf8(input)`：UTF‑8 直出版（对特殊字符转义，中文直出）
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

## 🧪 测试与格式化

```powershell
moon test         # 运行测试（包含解析与渲染的快照/断言）
moon info         # 更新接口快照（.mbti），便于检查 API 变化
moon fmt          # 格式化代码
```

当你确实更改了输出快照（例如渲染 HTML 的结构/样式变化），可使用：

```powershell
moon test --update
```

## 🧠 设计概览

- Tokenizer：聚合连续普通字符为 `Text`，识别 `#`、`*`、`` ` ``、`[`、`]`、`(`、`)`、`!`、`>`、`-`、`.` 等标记；兼容 CRLF/LF
- Parser：
  - 标题：行首 `#`×N + 空格 + 文本
  - 围栏代码块：支持前置缩进与“闭栏长度 ≥ 开栏长度”的匹配；首行余部作为语言标识
  - 列表：无序/有序，允许空行与子块（段落/引用/列表/围栏）作为 ListItem 嵌套内容；有序列表编号跨子块/空行不重置
  - 引用：解析为携带子块的 BlockQuote
  - 段落：连续非空行合并，换行为 `<br/>`
- Renderer：普通版与 UTF‑8 直出版；代码块容器含背景与复制按钮，列表/引用/嵌套子块递归渲染

## 🗺️ 路线图

- 行内语法：强调、加粗、链接、图片等
- 水平分割线、表格、自动链接/GFM 任务列表
- 更丰富的错误诊断与位置报告
