///|
// 渲染器：将 Block AST 渲染为简单 HTML

///|

///|
fn html_escape(s : String) -> String {
  // 基本 HTML 转义，保证文本按字面显示
  let mut out : String = ""
  let mut i = 0
  let n = s.length()
  while i < n {
    let ch = s[i]
    if ch == '&' {
      out = out + "&amp;"
    } else if ch == '<' {
      out = out + "&lt;"
    } else if ch == '>' {
      out = out + "&gt;"
    } else if ch == '"' {
      out = out + "&quot;"
    } else if ch == '\'' {
      out = out + "&#39;"
    } else {
      let b = StringBuilder::new()
      b.write_char(ch.unsafe_to_char())
      out = out + b.to_string()
    }
    i += 1
  }
  out
}

///|
// 将行内文本解析为：普通文本 + `代码片段`，并渲染为含 <code> 的 HTML
fn append_segment(acc : String, segment : String, is_code : Bool) -> String {
  if segment.length() == 0 {
    return acc
  }
  if is_code {
    acc +
    "<code class=\"inline-code\" style=\"background:#f6f8fa;padding:0 .25em;border-radius:4px;\">" +
    html_escape(segment) +
    "</code>"
  } else {
    acc + html_escape(segment)
  }
}

///|
fn render_inline_with_backticks(s : String) -> String {
  let mut out : String = ""
  let mut i = 0
  let n = s.length()
  let mut in_code = false
  let mut buf : String = ""
  while i < n {
    let ch = s[i]
    if ch == '`' { // 切换代码模式（只处理单反引号对）
      out = append_segment(out, buf, in_code)
      buf = ""
      in_code = !in_code
      i += 1
      continue
    }
    let b1 = StringBuilder::new()
    b1.write_char(ch.unsafe_to_char())
    buf = buf + b1.to_string()
    i += 1
  }
  // 末尾若没有闭合反引号，则按普通文本处理
  out = append_segment(out, buf, false)
  out
}

///|
fn render_text_heading_or_inline(t : Text) -> String {
  render_text_inline_utf8(t)
}

///|
fn render_text_paragraph(t : Text) -> String {
  match t {
    // 段落保留原数字串（与现有快照一致）
    Text::Single(s) => render_inline_with_backticks(s)
    Text::Multi(xs) => {
      let mut out : String = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          out = out + "<br/>\n"
        }
        out = out + render_inline_with_backticks(xs[i])
        i += 1
      }
      out
    }
  }
}

///|
fn render_text_code(t : Text) -> String {
  render_text_code_utf8(t)
}

///|
pub fn render_blocks_html(bs : Array[Block]) -> String {
  let mut out : String = ""
  let mut i = 0
  // 注：已支持 ListItem 子块
  while i < bs.length() {
    match bs[i] {
      Block::Paragraph(t) =>
        out = out + "<p>" + render_text_paragraph(t) + "</p>\n"
      Block::Heading(lv, t) => {
        let mut level = lv
        if level < 1 {
          level = 1
        } else if level > 6 {
          level = 6
        }
        out = out +
          "<h" +
          level.to_string() +
          ">" +
          render_text_heading_or_inline(t) +
          "</h" +
          level.to_string() +
          ">\n"
      }
      Block::CodeBlock(lang, t) => {
        let cls = if lang.length() > 0 {
          " class=\"language-" + html_escape(lang) + "\""
        } else {
          ""
        }
        out = out +
          "<div class=\"code-block\" style=\"position:relative;background:#f6f8fa;border-radius:6px;\">\n" +
          "<button class=\"copy-button\" style=\"position:absolute;top:8px;right:8px;padding:4px 8px;font-size:12px;cursor:pointer;\" onclick=\"(function(btn){var code=btn.parentElement.querySelector('code');navigator.clipboard.writeText(code.innerText).then(function(){btn.textContent='Copied';setTimeout(function(){btn.textContent='Copy'},1500)})})(this)\">Copy</button>\n" +
          "<pre style=\"margin:0;padding:12px 16px;overflow:auto;\"><code" +
          cls +
          ">" +
          render_text_code(t) +
          "</code></pre>\n" +
          "</div>\n"
      }
      Block::BlockQuote(cs) =>
        out = out +
          "<blockquote>\n" +
          render_blocks_html(cs) +
          "</blockquote>\n"
      Block::List => {
        let mut j = i + 1
        let mut is_ordered = false
        if j < bs.length() {
          let (ok0, ord0) = list_head_info(bs[j])
          if ok0 {
            is_ordered = ord0
          }
        }
        let tag = if is_ordered { "ol" } else { "ul" }
        out = out + "<" + tag + ">\n"
        while j < bs.length() {
          match bs[j] {
            Block::ListItem(ord2, t2, cs2) => {
              if ord2 != is_ordered {
                break
              }
              out = out + "  <li>" + render_text_heading_or_inline(t2)
              if cs2.length() > 0 {
                out = out + "\n" + render_blocks_html(cs2)
              }
              out = out + "</li>\n"
              j += 1
            }
            _ => break
          }
        }
        out = out + "</" + tag + ">\n"
        i = j - 1
      }
      Block::ListItem(_, t, cs0) => {
        out = out + "<ul>\n  <li>" + render_text_heading_or_inline(t)
        if cs0.length() > 0 {
          out = out + "\n" + render_blocks_html(cs0)
        }
        out = out + "</li>\n</ul>\n"
      }
    }
    i += 1
  }
  out
}

///|
fn list_head_info(b : Block) -> (Bool, Bool) {
  match b {
    Block::ListItem(ord, _, _) => (true, ord)
    _ => (false, false)
  }
}

///|
pub fn render_html(input : String) -> (String, String?) {
  let (bs, err) = parse(input)
  match err {
    None => {
      let html = render_blocks_html(bs)
      (html, None)
    }
    Some(e) => ("", Some(e))
  }
}

///|
// UTF-8 直出版：不做数字实体转换，直接对特殊 HTML 字符转义
fn render_text_inline_utf8(t : Text) -> String {
  match t {
    Text::Single(s) => render_inline_with_backticks(s)
    Text::Multi(xs) => {
      let mut out : String = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          out = out + " "
        }
        out = out + render_inline_with_backticks(xs[i])
        i += 1
      }
      out
    }
  }
}

///|
fn render_text_paragraph_utf8(t : Text) -> String {
  match t {
    Text::Single(s) => render_inline_with_backticks(s)
    Text::Multi(xs) => {
      let mut out : String = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          out = out + "<br/>\n"
        }
        out = out + render_inline_with_backticks(xs[i])
        i += 1
      }
      out
    }
  }
}

///|
fn render_text_code_utf8(t : Text) -> String {
  match t {
    Text::Single(s) => html_escape(s)
    Text::Multi(xs) => {
      let mut out : String = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          out = out + "\n"
        }
        out = out + html_escape(xs[i])
        i += 1
      }
      out
    }
  }
}

///|
pub fn render_blocks_html_utf8(bs : Array[Block]) -> String {
  let mut out : String = ""
  let mut i = 0
  // 注：已支持 ListItem 子块
  while i < bs.length() {
    match bs[i] {
      Block::Paragraph(t) =>
        out = out + "<p>" + render_text_paragraph_utf8(t) + "</p>\n"
      Block::Heading(lv, t) => {
        let mut level = lv
        if level < 1 {
          level = 1
        } else if level > 6 {
          level = 6
        }
        out = out +
          "<h" +
          level.to_string() +
          ">" +
          render_text_inline_utf8(t) +
          "</h" +
          level.to_string() +
          ">\n"
      }
      Block::CodeBlock(lang, t) => {
        let cls = if lang.length() > 0 {
          " class=\"language-" + html_escape(lang) + "\""
        } else {
          ""
        }
        out = out +
          "<div class=\"code-block\" style=\"position:relative;background:#f6f8fa;border-radius:6px;\">\n" +
          "<button class=\"copy-button\" style=\"position:absolute;top:8px;right:8px;padding:4px 8px;font-size:12px;cursor:pointer;\" onclick=\"(function(btn){var code=btn.parentElement.querySelector('code');navigator.clipboard.writeText(code.innerText).then(function(){btn.textContent='Copied';setTimeout(function(){btn.textContent='Copy'},1500)})})(this)\">Copy</button>\n" +
          "<pre style=\"margin:0;padding:12px 16px;overflow:auto;\"><code" +
          cls +
          ">" +
          render_text_code_utf8(t) +
          "</code></pre>\n" +
          "</div>\n"
      }
      Block::BlockQuote(cs) =>
        out = out +
          "<blockquote>\n" +
          render_blocks_html_utf8(cs) +
          "</blockquote>\n"
      Block::List => {
        let mut j = i + 1
        let mut is_ordered = false
        if j < bs.length() {
          let (ok0, ord0) = list_head_info(bs[j])
          if ok0 {
            is_ordered = ord0
          }
        }
        let tag = if is_ordered { "ol" } else { "ul" }
        out = out + "<" + tag + ">\n"
        while j < bs.length() {
          match bs[j] {
            Block::ListItem(ord2, t2, cs2) => {
              if ord2 != is_ordered {
                break
              }
              out = out + "  <li>" + render_text_inline_utf8(t2)
              if cs2.length() > 0 {
                out = out + "\n" + render_blocks_html_utf8(cs2)
              }
              out = out + "</li>\n"
              j += 1
            }
            _ => break
          }
        }
        out = out + "</" + tag + ">\n"
        i = j - 1
      }
      Block::ListItem(_, t, cs0) => {
        out = out + "<ul>\n  <li>" + render_text_inline_utf8(t)
        if cs0.length() > 0 {
          out = out + "\n" + render_blocks_html_utf8(cs0)
        }
        out = out + "</li>\n</ul>\n"
      }
    }
    i += 1
  }
  out
}

///|
pub fn render_html_utf8(input : String) -> (String, String?) {
  let (bs, err) = parse(input)
  match err {
    None => (render_blocks_html_utf8(bs), None)
    Some(e) => ("", Some(e))
  }
}

///|
// 生成完整 HTML 页面，包含 UTF-8 meta，避免浏览器用错误编码渲染
pub fn render_html_page(input : String) -> (String, String?) {
  let (body, err) = render_html(input)
  match err {
    None => {
      let doc = "<!doctype html>\n" +
        "<html lang=\"zh-CN\">\n" +
        "<head>\n" +
        "  <meta charset=\"utf-8\"/>\n" +
        "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>\n" +
        "  <title>Document</title>\n" +
        "</head>\n" +
        "<body>\n" +
        body +
        "</body>\n" +
        "</html>\n"
      (doc, None)
    }
    Some(e) => ("", Some(e))
  }
}

///|
// 方便从 UTF-8 字节视图直接渲染（宽松版：遇到非法序列用 U+FFFD 替代）
pub fn render_html_from_utf8_bytes_lossy(
  bytes : BytesView,
) -> (String, String?) {
  let input = @utf8.decode_lossy(bytes)
  render_html(input)
}

///|
// 严格版：UTF-8 解码失败将抛出 Malformed
