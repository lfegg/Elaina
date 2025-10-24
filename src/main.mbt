///|
// 在 main 中调用 Markdown 解析与渲染，并将结果输出到标准输出
// 你可以用 PowerShell 将其重定向到文件：
//   moon run .\src\main.mbt > output.html
fn main {
  let input = "# Hello 你好\n\nThis is a paragraph.\n\n```moon\nlet x = 1\n```\n"
  let (html, err) = render_html(input)
  match err {
    None => println(html)
    Some(e) => println(e)
  }
}
