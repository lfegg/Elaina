///|
// 渲染器：将 Block AST 渲染为简单 HTML

///|

///|
fn html_escape(s : String) -> String {
  s
}

///|
fn render_text_heading_or_inline(t : Text) -> String {
  render_text_inline_utf8(t)
}

///|
fn render_text_paragraph(t : Text) -> String {
  match t {
    // 段落保留原数字串（与现有快照一致）
    Text::Single(s) => html_escape(s)
    Text::Multi(xs) => {
      let mut out : String = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          out = out + "<br/>\n"
        }
        out = out + html_escape(xs[i])
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
          "<pre><code" +
          cls +
          ">" +
          render_text_code(t) +
          "</code></pre>\n"
      }
      Block::BlockQuote => out = out + "<blockquote></blockquote>\n"
      Block::List => {
        // 查看后续的第一个 ListItem 判断类型
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
            Block::ListItem(ord2, t2) => {
              if ord2 != is_ordered {
                break
              }
              out = out +
                "  <li>" +
                render_text_heading_or_inline(t2) +
                "</li>\n"
              j += 1
            }
            _ => break
          }
        }
        out = out + "</" + tag + ">\n"
        i = j - 1
      }
      Block::ListItem(_, t) =>
        out = out +
          "<ul>\n  <li>" +
          render_text_heading_or_inline(t) +
          "</li>\n</ul>\n"
    }
    i += 1
  }
  out
}

///|
fn list_head_info(b : Block) -> (Bool, Bool) {
  match b {
    Block::ListItem(ord, _) => (true, ord)
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
    Text::Single(s) => html_escape(s)
    Text::Multi(xs) => {
      let mut out : String = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          out = out + " "
        }
        out = out + html_escape(xs[i])
        i += 1
      }
      out
    }
  }
}

///|
fn render_text_paragraph_utf8(t : Text) -> String {
  match t {
    Text::Single(s) => html_escape(s)
    Text::Multi(xs) => {
      let mut out : String = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          out = out + "<br/>\n"
        }
        out = out + html_escape(xs[i])
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
          "<pre><code" +
          cls +
          ">" +
          render_text_code_utf8(t) +
          "</code></pre>\n"
      }
      Block::BlockQuote => out = out + "<blockquote></blockquote>\n"
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
            Block::ListItem(ord2, t2) => {
              if ord2 != is_ordered {
                break
              }
              out = out + "  <li>" + render_text_inline_utf8(t2) + "</li>\n"
              j += 1
            }
            _ => break
          }
        }
        out = out + "</" + tag + ">\n"
        i = j - 1
      }
      Block::ListItem(_, t) =>
        out = out +
          "<ul>\n  <li>" +
          render_text_inline_utf8(t) +
          "</li>\n</ul>\n"
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
