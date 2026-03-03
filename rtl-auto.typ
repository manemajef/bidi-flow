
// Walk the content tree and return the first Hebrew/Arabic or Latin character,
// or `none` if none is found.  Stops as soon as a match is found.
#let _first-strong(body) = {
  if type(body) != content { return none }
  let f = body.func()
  if f == math.equation or f == raw { return none }
  if body.has("text") {
    let m = body.text.match(regex("[\p{Hebrew}\p{Arabic}\p{Latin}]"))
    if m != none { return m.text }
    return none
  }
  if body.has("children") {
    for child in body.children {
      let ch = _first-strong(child)
      if ch != none { return ch }
    }
    return none
  }
  if body.has("body") {
    let inner = body.fields().at("body")
    if type(inner) == content { return _first-strong(inner) }
  }
  // styled() wraps strong/emph/link/underline/… in Typst 0.14 — uses "child" not "body"
  if body.has("child") {
    let inner = body.fields().at("child")
    if type(inner) == content { return _first-strong(inner) }
  }
  none
}

// Returns true if the first strong character is RTL (Hebrew or Arabic).
#let _is-rtl(body) = {
  let ch = _first-strong(body)
  ch != none and ch.match(regex("[\p{Hebrew}\p{Arabic}]")) != none
}

#let _first-cell-body(children) = {
  for c in children {
    if c.func() == table.cell {
      return c.body
    }
  }
  none
}
// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Invisible zero-width directional seeds.
/// Typst uses text.dir, not Unicode bidi marks, so these work by injecting
/// a hidden zero-width box that carries the direction into the shaping context.
/// Usage: some text #r() another word
///        some text #l() another word

#let r = text(size: 0pt)[י]
#let l = text(size: 0pt)[i]
/// Inline direction spans.  Use for mixed-direction fragments:
///   #rl[מילה באמצע משפט אנגלי]   #lr[word in Hebrew sentence]
#let rl(body) = [#set text(dir: rtl); #body]
#let lr(body) = [#set text(dir: ltr); #body]

/// Scope-level direction override.  Use with #show:
///   #show: setrl   — rest of current scope is RTL
///   #show: setlr   — rest of current scope is LTR
#let setrl = body => [#set text(dir: rtl); #body]
#let setlr = body => [#set text(dir: ltr); #body]

/// Document wrapper.  Apply once at the top of your entry file:
///   #show: setup
///
/// Auto-detects direction for par, heading, list, and enum
/// based on the first strong (Hebrew/Arabic/Latin) character.
/// RTL blocks get `dir: rtl`; everything else is left as auto.
#let rtl-auto = (
  hebrew-font: "David CLM",
  arab-font: "Libertinus Serif",
  english-font: "New Computer Modern",
  body,
) => {
  set text(font: english-font)
  show regex("\p{Hebrew}"): set text(font: (hebrew-font, "Libertinus Serif"))
  show regex("\p{Arabic}"): set text(font: (arab-font, "Libertinus Serif"))

  show par: it => if _is-rtl(it.body) [
    #set text(dir: rtl)
    #it
  ] else { it }
  show quote.where(block: true): it => if _is-rtl(it.body) [
    #set text(dir: rtl)
    #it
  ] else { it }

  show heading: it => if _is-rtl(it.body) [
    #set text(dir: rtl)
    #it
  ] else { it }


  show list: it => if it.children.len() > 0 and _is-rtl(it.children.at(0).body) [
    #set text(dir: rtl)
    #it
  ] else { it }

  show enum: it => if it.children.len() > 0 and _is-rtl(it.children.at(0).body) [
    #set text(dir: rtl)
    #it
  ] else { it }

  show table: it => {
    let first-cell = _first-cell-body(it.children)
    if first-cell != none and _is-rtl(first-cell) [
      #set text(dir: rtl)
      #it
    ] else {
      it
    }
  }

  body
}
