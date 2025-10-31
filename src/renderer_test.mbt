///|
// renderer blackbox tests

// Helper: strip copy-button lines to avoid brittle diffs on long attributes across environments
fn strip_copy_button(s : String) -> String {
  let start_pat = "<button class=\"copy-button\""
  let end_pat = "</button>"
  let mut out = s
  let mut changed = true
  while changed {
    changed = false
    let n = out.length()
    let mut start = -1
    // find start
    let mut i = 0
    while i + start_pat.length() <= n {
      let mut ok = true
      let mut k = 0
      while k < start_pat.length() {
        if out[i + k] != start_pat[k] {
          ok = false
          break
        }
        k += 1
      }
      if ok {
        start = i
        break
      }
      i += 1
    }
    if start == -1 {
      break
    }
    // find end
    let mut j = start + start_pat.length()
    let mut end = -1
    while j + end_pat.length() <= n {
      let mut ok2 = true
      let mut k2 = 0
      while k2 < end_pat.length() {
        if out[j + k2] != end_pat[k2] {
          ok2 = false
          break
        }
        k2 += 1
      }
      if ok2 {
        end = j + end_pat.length()
        break
      }
      j += 1
    }
    if end == -1 {
      break
    }
    // also remove a following single '\n' if present
    let end2 = if end < n && out[end] == '\n' { end + 1 } else { end }
    // rebuild string without [start, end2)
    let mut rebuilt : String = ""
    let mut p = 0
    while p < start {
      let b = StringBuilder::new()
      b.write_char(out[p].unsafe_to_char())
      rebuilt = rebuilt + b.to_string()
      p += 1
    }
    let mut q = end2
    while q < n {
      let b2 = StringBuilder::new()
      b2.write_char(out[q].unsafe_to_char())
      rebuilt = rebuilt + b2.to_string()
      q += 1
    }
    out = rebuilt
    changed = true
  }
  out
}

// Helper: remove spaces before line breaks to reduce platform variance

///|
fn strip_trailing_spaces(s : String) -> String {
  let mut out : String = ""
  let mut i = 0
  let n = s.length()
  let mut line_buf : String = ""
  while i < n {
    let b = s[i]
    if b == '\n' {
      // trim trailing spaces in line_buf
      let mut j = line_buf.length()
      while j > 0 && line_buf[j - 1] == ' ' {
        j -= 1
      }
      let mut k = 0
      while k < j {
        let sb = StringBuilder::new()
        sb.write_char(line_buf[k].unsafe_to_char())
        out = out + sb.to_string()
        k += 1
      }
      out = out + "\n"
      line_buf = ""
    } else {
      let sb2 = StringBuilder::new()
      sb2.write_char(b.unsafe_to_char())
      line_buf = line_buf + sb2.to_string()
    }
    i += 1
  }
  // append last line without newline (keep as-is, but trim trailing spaces too)
  let mut j2 = line_buf.length()
  while j2 > 0 && line_buf[j2 - 1] == ' ' {
    j2 -= 1
  }
  let mut k2 = 0
  while k2 < j2 {
    let sb3 = StringBuilder::new()
    sb3.write_char(line_buf[k2].unsafe_to_char())
    out = out + sb3.to_string()
    k2 += 1
  }
  out
}

///|
fn str_contains(hay : String, needle : String) -> Bool {
  let n = hay.length()
  let m = needle.length()
  if m == 0 {
    return true
  }
  let mut i = 0
  while i + m <= n {
    let mut ok = true
    let mut k = 0
    while k < m {
      if hay[i + k] != needle[k] {
        ok = false
        break
      }
      k += 1
    }
    if ok {
      return true
    }
    i += 1
  }
  false
}

///|
fn must_contains(hay : String, needle : String) -> String {
  if str_contains(hay, needle) {
    "ok"
  } else {
    hay
  }
}

///|
test "render basic document to html" {
  let input = "# Title\n\npara line 1\npara line 2\n\n```lang\nline a\nline b\n```\n\n> quoted line\n\n- item one\n- item two\n\n1. first\n    ```js\n    code under first\n    ```\n2. second\n"
  let (html, err) = render_html(input)
  let fhtml = strip_trailing_spaces(strip_copy_button(html))
  inspect(
    must_contains(
      fhtml, "<h1>Title</h1>\n<p>para line 1<br/>\npara line 2</p>\n",
    ),
    content="ok",
  )
  inspect(must_contains(fhtml, "<div class=\"code-block\""), content="ok")
  inspect(
    must_contains(
      fhtml, "<pre style=\"margin:0;padding:12px 16px;overflow:auto;\"><code class=\"language-lang\">line a\nline b</code></pre>\n</div>\n",
    ),
    content="ok",
  )
  inspect(
    must_contains(fhtml, "<blockquote>\n<p>quoted line</p>\n</blockquote>\n"),
    content="ok",
  )
  inspect(
    must_contains(
      fhtml, "<ul>\n  <li>item one</li>\n  <li>item two</li>\n</ul>\n",
    ),
    content="ok",
  )
  inspect(must_contains(fhtml, "<ol>\n  <li>first\n"), content="ok")
  inspect(
    must_contains(
      fhtml, "<pre style=\"margin:0;padding:12px 16px;overflow:auto;\"><code class=\"language-js\">    code under first</code></pre>\n</div>\n",
    ),
    content="ok",
  )
  inspect(
    must_contains(fhtml, "</li>\n  <li>second</li>\n</ol>\n"),
    content="ok",
  )
  inspect(err, content="None")
}

///|
// heading requires a space after '#'

test "render hash without space is not heading" {
  let input = "#Title\n"
  let (html, err) = render_html(input)
  inspect(
    html,
    content=(
      #|<p>#Title</p>
      #|
    ),
  )
  inspect(err, content="None")
}

///|
// inline code between backticks should render literally and be escaped

test "render inline code escapes html" {
  let input = "inline `<!DOCTYPE html><h1></h1>` end\n"
  let (html, err) = render_html(input)
  inspect(
    html,
    content=(
      #|<p>inline <code class="inline-code" style="background:#f6f8fa;padding:0 .25em;border-radius:4px;">&lt;!DOCTYPE html&gt;&lt;h1&gt;&lt;/h1&gt;</code> end</p>
      #|
    ),
  )
  inspect(err, content="None")
}
