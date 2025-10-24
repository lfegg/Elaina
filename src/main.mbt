///|
// 在 main 中调用 Markdown 解析与渲染，并将结果输出到标准输出
// 你可以用 PowerShell 将其重定向到文件：
//   moon run .\src\main.mbt > output.html
fn main {
	  // 使用 try-catch 处理文件读取
  let context = try {
    @fs.read_file_to_string("./README.md")
  } catch {
    error => {
      println("读取文件失败: \{error}")
      return 
    }
  }

  // let input = "# Hello \nThis is a paragraph.\n## nihao \n### three\n#### four\n```moonbit\nlet x = 1\n```"
  let (html, err) = render_html(context)
  match err {
    None => println(html)
    Some(e) => println(e)
  }
	
	try {
	@fs.write_string_to_file("./output.html", html)
	} catch {
		error => {
			println("写入文件失败: \{error}")
		}
	}
}


