///|
// 在 main 中调用 Markdown 解析与渲染，并将结果输出到标准输出
// 你可以用 PowerShell 将其重定向到文件：
// moon run .\src\main.mbt > output.html（不再推荐使用，因为power shell的问题会出现中文乱码）
// 现在引入了 fs 模块以便读取和写入文件，仅需要运行主函数即可
fn main {
  let context = @fs.read_file_to_string("./README.md") //此处为读取的文件路径
   catch {
    error => {
      println("读取文件失败: \{error}")
      return
    }
  }
  let (html, err) = render_html(context)
  match err {
    None => println("HTML 渲染成功。")
    Some(e) => println(e)
  }
  @fs.write_string_to_file("./output.html", html) //此处为输出的文件路径
   catch {
    error => println("写入文件失败: \{error}")
  }
}
