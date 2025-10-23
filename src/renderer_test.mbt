///|
// renderer blackbox tests

test "render basic document to html" {
  let input = "# Title\n\npara line 1\npara line 2\n\n```lang\nline a\nline b\n```\n\n> quoted line\n\n- item one\n- item two\n\n1. first\n2. second\n"
  let (html, err) = render_html(input)
  inspect(
    html,
    content=(
      #|<h1>&#32;&#84;&#105;&#116;&#108;&#101;</h1>
      #|<p>&#112;&#97;&#114;&#97;&#32;&#108;&#105;&#110;&#101;&#32;49<br/>
      #|&#112;&#97;&#114;&#97;&#32;&#108;&#105;&#110;&#101;&#32;50</p>
      #|<pre><code class="language-&#108;&#97;&#110;&#103;">&#108;&#105;&#110;&#101;&#32;&#97;
      #|&#108;&#105;&#110;&#101;&#32;&#98;</code></pre>
      #|<blockquote></blockquote>
      #|<ul>
      #|  <li>&#32;&#105;&#116;&#101;&#109;&#32;&#111;&#110;&#101;</li>
      #|  <li>&#32;&#105;&#116;&#101;&#109;&#32;&#116;&#119;&#111;</li>
      #|</ul>
      #|<ol>
      #|  <li>&#32;&#102;&#105;&#114;&#115;&#116;</li>
      #|  <li>&#32;&#115;&#101;&#99;&#111;&#110;&#100;</li>
      #|</ol>
      #|




    ),
  )
  inspect(err, content="None")
}
