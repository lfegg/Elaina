///|
// 渲染器：将 Block AST 渲染为简单 HTML

///|
// 将形如 "3284105..." 这种十进制 ASCII 串，转成 "&#32;&#84;&#105;..." 的 HTML 数字实体序列
fn digits_to_entities(s: String) -> String {
	let mut out: String = ""
	let mut i = 0
	let n = s.length()
	while i < n {
		// 优先尝试 3 位（100..126），否则 2 位（32..99），都不匹配则原样输出当前字符
		if i + 2 < n {
			let a = s[i] - '0'
			let b = s[i + 1] - '0'
			let c = s[i + 2] - '0'
			if a >= 0 && a <= 9 && b >= 0 && b <= 9 && c >= 0 && c <= 9 {
				let code3 = a * 100 + b * 10 + c
				if code3 >= 100 && code3 <= 126 {
					out = out + "&#" + code3.to_string() + ";"
					i += 3
					continue
				}
			}
		}
		if i + 1 < n {
			let a = s[i] - '0'
			let b = s[i + 1] - '0'
			if a >= 0 && a <= 9 && b >= 0 && b <= 9 {
				let code2 = a * 10 + b
				if code2 >= 32 && code2 <= 99 {
					out = out + "&#" + code2.to_string() + ";"
					i += 2
					continue
				}
			}
		}
		// 回退：无法解析为 2/3 位合法编码，按原字符输出
		out = out + s[i].to_string()
		i += 1
	}
	out
}

///|
fn html_escape(s: String) -> String {
	let mut out: String = ""
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
		} else {
			out = out + ch.to_string()
		}
		i += 1
	}
	out
}

///|
fn render_text_heading_or_inline(t: Text) -> String {
	match t {
		Text::Single(s) => digits_to_entities(s)
		Text::Multi(xs) => {
			// 退化为空格连接
			let mut out: String = ""
			let mut i = 0
			while i < xs.length() {
				if i > 0 { out = out + " " }
				out = out + digits_to_entities(xs[i])
				i += 1
			}
			out
		}
	}
}

///|
fn render_text_paragraph(t: Text) -> String {
	match t {
		// 段落保留原数字串（与现有快照一致）
		Text::Single(s) => html_escape(s)
		Text::Multi(xs) => {
			let mut out: String = ""
			let mut i = 0
			while i < xs.length() {
				if i > 0 { out = out + "<br/>\n" }
				out = out + html_escape(xs[i])
				i += 1
			}
			out
		}
	}
}

///|
fn render_text_code(t: Text) -> String {
	// 代码内容：将数字串解析为字符，再用数字实体输出（与快照一致）
	match t {
		Text::Single(s) => digits_to_entities(s)
		Text::Multi(xs) => {
			let mut out: String = ""
			let mut i = 0
			while i < xs.length() {
				if i > 0 { out = out + "\n" }
				out = out + digits_to_entities(xs[i])
				i += 1
			}
			out
		}
	}
}

///|
pub fn render_blocks_html(bs: Array[Block]) -> String {
	let mut out: String = ""
	let mut i = 0
	while i < bs.length() {
		match bs[i] {
			Block::Paragraph(t) => {
				out = out + "<p>" + render_text_paragraph(t) + "</p>\n"
			}
			Block::Heading(lv, t) => {
				let mut level = lv
				if level < 1 { level = 1 } else { if level > 6 { level = 6 } }
				out = out + "<h" + level.to_string() + ">" + render_text_heading_or_inline(t) + "</h" + level.to_string() + ">\n"
			}
			Block::CodeBlock(lang, t) => {
				let cls = if lang.length() > 0 { " class=\"language-" + html_escape(lang) + "\"" } else { "" }
				out = out + "<pre><code" + cls + ">" + render_text_code(t) + "</code></pre>\n"
			}
			Block::BlockQuote => {
				out = out + "<blockquote></blockquote>\n"
			}
			Block::List => {
				// 查看后续的第一个 ListItem 判断类型
				let mut j = i + 1
				let mut is_ordered = false
				if j < bs.length() {
					let (ok0, ord0) = list_head_info(bs[j])
					if ok0 { is_ordered = ord0 }
				}
				let tag = if is_ordered { "ol" } else { "ul" }
				out = out + "<" + tag + ">\n"
				while j < bs.length() {
					match bs[j] {
						Block::ListItem(ord2, t2) => {
							if ord2 != is_ordered { break }
							out = out + "  <li>" + render_text_heading_or_inline(t2) + "</li>\n"
							j += 1
						}
						_ => { break }
					}
				}
				out = out + "</" + tag + ">\n"
				i = j - 1
			}
			Block::ListItem(_, t) => {
				out = out + "<ul>\n  <li>" + render_text_heading_or_inline(t) + "</li>\n</ul>\n"
			}
		}
		i += 1
	}
	out
}

///|
fn list_head_info(b: Block) -> (Bool, Bool) {
	match b {
		Block::ListItem(ord, _) => (true, ord)
		_ => (false, false)
	}
}

///|
pub fn render_html(input: String) -> (String, Option[String]) {
	let (bs, err) = parse(input)
	match err {
		None => (render_blocks_html(bs), None)
		Some(e) => ("", Some(e))
	}
}

///|
// UTF-8 直出版：不做数字实体转换，直接对特殊 HTML 字符转义
fn render_text_inline_utf8(t: Text) -> String {
	match t {
		Text::Single(s) => html_escape(s)
		Text::Multi(xs) => {
			let mut out: String = ""
			let mut i = 0
			while i < xs.length() {
				if i > 0 { out = out + " " }
				out = out + html_escape(xs[i])
				i += 1
			}
			out
		}
	}
}

fn render_text_paragraph_utf8(t: Text) -> String {
	match t {
		Text::Single(s) => html_escape(s)
		Text::Multi(xs) => {
			let mut out: String = ""
			let mut i = 0
			while i < xs.length() {
				if i > 0 { out = out + "<br/>\n" }
				out = out + html_escape(xs[i])
				i += 1
			}
			out
		}
	}
}

fn render_text_code_utf8(t: Text) -> String {
	match t {
		Text::Single(s) => html_escape(s)
		Text::Multi(xs) => {
			let mut out: String = ""
			let mut i = 0
			while i < xs.length() {
				if i > 0 { out = out + "\n" }
				out = out + html_escape(xs[i])
				i += 1
			}
			out
		}
	}
}

pub fn render_blocks_html_utf8(bs: Array[Block]) -> String {
	let mut out: String = ""
	let mut i = 0
	while i < bs.length() {
		match bs[i] {
			Block::Paragraph(t) => { out = out + "<p>" + render_text_paragraph_utf8(t) + "</p>\n" }
			Block::Heading(lv, t) => {
				let mut level = lv
				if level < 1 { level = 1 } else { if level > 6 { level = 6 } }
				out = out + "<h" + level.to_string() + ">" + render_text_inline_utf8(t) + "</h" + level.to_string() + ">\n"
			}
			Block::CodeBlock(lang, t) => {
				let cls = if lang.length() > 0 { " class=\"language-" + html_escape(lang) + "\"" } else { "" }
				out = out + "<pre><code" + cls + ">" + render_text_code_utf8(t) + "</code></pre>\n"
			}
			Block::BlockQuote => { out = out + "<blockquote></blockquote>\n" }
			Block::List => {
				let mut j = i + 1
				let mut is_ordered = false
				if j < bs.length() {
					let (ok0, ord0) = list_head_info(bs[j])
					if ok0 { is_ordered = ord0 }
				}
				let tag = if is_ordered { "ol" } else { "ul" }
				out = out + "<" + tag + ">\n"
				while j < bs.length() {
					match bs[j] {
						Block::ListItem(ord2, t2) => {
							if ord2 != is_ordered { break }
							out = out + "  <li>" + render_text_inline_utf8(t2) + "</li>\n"
							j += 1
						}
						_ => { break }
					}
				}
				out = out + "</" + tag + ">\n"
				i = j - 1
			}
			Block::ListItem(_, t) => { out = out + "<ul>\n  <li>" + render_text_inline_utf8(t) + "</li>\n</ul>\n" }
		}
		i += 1
	}
	out
}

pub fn render_html_utf8(input: String) -> (String, Option[String]) {
	let (bs, err) = parse(input)
	match err {
		None => (render_blocks_html_utf8(bs), None)
		Some(e) => ("", Some(e))
	}
}

