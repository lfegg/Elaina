///|
// 渲染器：将 Block AST 渲染为简单 HTML

///|

///|
fn html_escape(s: String) -> String { s }

///|
// 将由 Char.to_string 产生的连续十进制数字串，尽可能转为 HTML 数字实体
// 策略：贪心匹配 6/5/4/3/2 位，取落在 [32, 1114111] 的码点；否则原样输出当前字符
fn digits_to_entities(s: String) -> String {
	let mut out: String = ""
	let mut i = 0
	let n = s.length()
	while i < n {
		let ch = s[i]
		if ch >= '0' && ch <= '9' {
			let mut matched = false
			// 解析接下来 k 位为整数
			fn parse_int(s: String, i: Int, len: Int) -> (Bool, Int) {
				let mut j = 0
				let mut val = 0
				while j < len {
					let d = s[i + j] - '0'
					if d < 0 || d > 9 { return (false, 0) }
					val = val * 10 + d
					j += 1
				}
				(true, val)
			}
			// 优先解析 ASCII（2/3 位），再解析 6/5/4 位的更大码点
			// 2-digit ASCII [32..99]
			if !matched && i + 2 <= n {
				let (ok, v) = parse_int(s, i, 2)
				if ok && v >= 32 && v <= 99 {
					out = out + "&#" + v.to_string() + ";"
					i += 2
					matched = true
				}
			}
			// 3-digit ASCII [100..126]
			if !matched && i + 3 <= n {
				let (ok, v) = parse_int(s, i, 3)
				if ok && v >= 100 && v <= 126 {
					out = out + "&#" + v.to_string() + ";"
					i += 3
					matched = true
				}
			}
			// 6-digit Unicode [100000..1114111]
			if !matched && i + 6 <= n {
				let (ok, v) = parse_int(s, i, 6)
				if ok && v >= 100000 && v <= 1114111 {
					out = out + "&#" + v.to_string() + ";"
					i += 6
					matched = true
				}
			}
			// 5-digit Unicode [10000..99999]
			if !matched && i + 5 <= n {
				let (ok, v) = parse_int(s, i, 5)
				if ok && v >= 10000 && v <= 99999 {
					out = out + "&#" + v.to_string() + ";"
					i += 5
					matched = true
				}
			}
			// 4-digit Unicode [128..9999]（如 EM DASH 8212 等）
			if !matched && i + 4 <= n {
				let (ok, v) = parse_int(s, i, 4)
				if ok && v >= 128 && v <= 9999 {
					out = out + "&#" + v.to_string() + ";"
					i += 4
					matched = true
				}
			}
			if !matched {
				// 非数字或无法解析，逐字符回退
				out = out + ch.to_string()
				i += 1
			}
		} else {
			out = out + ch.to_string()
			i += 1
		}
	}
	out
}

///|
fn render_text_heading_or_inline(t: Text) -> String {
	match t {
		Text::Single(s) => digits_to_entities(s)
		Text::Multi(xs) => {
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
		Text::Single(s) => digits_to_entities(s)
		Text::Multi(xs) => {
			let mut out: String = ""
			let mut i = 0
			while i < xs.length() {
				if i > 0 { out = out + "<br/>\n" }
				out = out + digits_to_entities(xs[i])
				i += 1
			}
			out
		}
	}
}

///|
fn render_text_code(t: Text) -> String {
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
				let cls = if lang.length() > 0 { " class=\"language-" + digits_to_entities(lang) + "\"" } else { "" }
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
		None => {
			let html = render_blocks_html(bs)
			(html, None)
		}
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

