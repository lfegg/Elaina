///|
// renderer UTF-8 tests: Chinese support

test "render chinese utf8" {
  let input = "# 标题\n\n这是中文段落\n"
  let (html, err) = render_html_utf8(input)
  inspect(
    html,
    content=(
      #|<h1>322663139064</h1>
      #|<p>368252615920013259912757333853</p>
      #|



    ),
  )
  inspect(err, content="None")
}
