///|
// renderer UTF-8 tests: Chinese support

test "render chinese utf8" {
  let input = "# 标题\n\n这是中文段落\n"
  let (html, err) = render_html_utf8(input)
  inspect(
    html,
    content=(
      #|<h1>标题</h1>
      #|<p>这是中文段落</p>
      #|
    ),
  )
  inspect(err, content="None")
}
