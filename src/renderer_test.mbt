///|
// renderer blackbox tests

test "render basic document to html" {
  let input = "# Title\n\npara line 1\npara line 2\n\n```lang\nline a\nline b\n```\n\n> quoted line\n\n- item one\n- item two\n\n1. first\n2. second\n"
  let (html, err) = render_html(input)
  inspect(
    html,
    content=(
      #|<h1>Title</h1>
      #|<p>para line 1<br/>
      #|para line 2</p>
      #|<pre><code class="language-lang">line a
      #|line b</code></pre>
      #|<blockquote></blockquote>
      #|<ul>
      #|  <li>item one</li>
      #|  <li>item two</li>
      #|</ul>
      #|<ol>
      #|  <li>first</li>
      #|  <li>second</li>
      #|</ol>
      #|
    ),
  )
  inspect(err, content="None")
}
