///|
// renderer UTF-8 tests: Chinese support

test "render chinese utf8" {
  let input = "# 标题\n\n这是中文段落\n"
  let (html, err) = render_html_utf8(input)
  inspect(
    html,
    content=(
      #|<h1>515050545451495157485452</h1>
      #|<p>515456505350544953575048484951505357574950555355515151565351</p>
      #|


    ),
  )
  inspect(err, content="None")
}
