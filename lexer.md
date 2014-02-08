---
project: lexer
tagline: scintillua lexer
---

This is scintillua 3.3.9-1 from http://foicica.com/scintillua/download (MIT license)

> __NOTE:__ What follows is an experiment in integrating documentation from external projects into luapower. \
> Check out the [original document][lexer doc].

## `local lexer = require'lexer'`

## Overview

Lexers highlight the syntax of source code. Scintilla (the editing component
behind [Textadept][] and [SciTE][]) traditionally uses static, compiled C++
lexers which are notoriously difficult to create and/or extend. On the other
hand, Lua makes it easy to to rapidly create new lexers, extend existing
ones, and embed lexers within one another. Lua lexers tend to be more
readable than C++ lexers too.

Lexers are Parsing Expression Grammars, or PEGs, composed with the Lua
[LPeg library][]. The following table comes from the LPeg documentation and
summarizes all you need to know about constructing basic LPeg patterns. This
module provides convenience functions for creating and working with other
more advanced patterns and concepts.

Operator             | Description
---------------------|------------
`lpeg.P(string)`     | Matches `string` literally.
`lpeg.P(`_`n`_`)`    | Matches exactly _`n`_ characters.
`lpeg.S(string)`     | Matches any character in set `string`.
`lpeg.R("`_`xy`_`")` | Matches any character between range `x` and `y`.
`patt^`_`n`_         | Matches at least _`n`_ repetitions of `patt`.
`patt^-`_`n`_        | Matches at most _`n`_ repetitions of `patt`.
`patt1 * patt2`      | Matches `patt1` followed by `patt2`.
`patt1 + patt2`      | Matches `patt1` or `patt2` (ordered choice).
`patt1 - patt2`      | Matches `patt1` if `patt2` does not match.
`-patt`              | Equivalent to `("" - patt)`.
`#patt`              | Matches `patt` but consumes no input.

The first part of this document deals with rapidly constructing a simple
lexer. The next part deals with more advanced techniques, such as custom
coloring and embedding lexers within one another. Following that is a
discussion about code folding, or being able to tell Scintilla which code
blocks are "foldable" (temporarily hideable from view). After that are
instructions on how to use LPeg lexers with the aforementioned Textadept and
SciTE editors. Finally there are comments on lexer performance and
limitations.

[LPeg library]: http://www.inf.puc-rio.br/~roberto/lpeg/lpeg.html
[Textadept]: http://foicica.com/textadept
[SciTE]: http://scintilla.org/SciTE.html

## Lexer Basics

The *lexers/* directory contains all lexers, including your new one. Before
attempting to write one from scratch though, first determine if your
programming language is similar to any of the 80+ languages supported. If so,
you may be able to copy and modify that lexer, saving some time and effort.
The filename of your lexer should be the name of your programming language in
lower case followed by a *.lua* extension. For example, a new Lua lexer has
the name *lua.lua*.

Note: Try to refrain from using one-character language names like "b", "c",
or "d". For example, Scintillua uses "b_lang", "cpp", and "dmd",
respectively.

### New Lexer Template

There is a *lexers/template.txt* file that contains a simple template for a
new lexer. Feel free to use it, replacing the '?'s with the name of your
lexer:

    -- ? LPeg lexer.

    local l = require('lexer')
    local token, word_match = l.token, l.word_match
    local P, R, S = lpeg.P, lpeg.R, lpeg.S

    local M = {_NAME = '?'}

    -- Whitespace.
    local ws = token(l.WHITESPACE, l.space^1)

    M._rules = {
      {'whitespace', ws},
    }

    M._tokenstyles = {

    }

    return M

The first 4 lines of code simply define often used convenience variables. The
5th and last lines define and return the lexer object Scintilla uses; they
are very important and must be part of every lexer. The sixth line defines
something called a "token", an essential building block of lexers. You will
learn about tokens shortly. The rest of the code defines a set of grammar
rules and token styles. You will learn about those later. Note, however, the
`M.` prefix in front of `_rules` and `_tokenstyles`: not only do these tables
belong to their respective lexers, but any non-local variables need the `M.`
prefix too so-as not to affect Lua's global environment. All in all, this is
a minimal, working lexer that you can build on.

### Tokens

Take a moment to think about your programming language's structure. What kind
of key elements does it have? In the template shown earlier, one predefined
element all languages have is whitespace. Your language probably also has
elements like comments, strings, and keywords. Lexers refer to these elements
as "tokens". Tokens are the fundamental "building blocks" of lexers. Lexers
break down source code into tokens for coloring, which results in the syntax
highlighting familiar to you. It is up to you how specific your lexer is when
it comes to tokens. Perhaps only distinguishing between keywords and
identifiers is necessary, or maybe recognizing constants and built-in
functions, methods, or libraries is desirable. The Lua lexer, for example,
defines 11 tokens: whitespace, comments, strings, numbers, keywords, built-in
functions, constants, built-in libraries, identifiers, labels, and operators.
Even though constants, built-in functions, and built-in libraries are subsets
of identifiers, Lua programmers find it helpful for the lexer to distinguish
between them all. It is perfectly acceptable to just recognize keywords and
identifiers.

In a lexer, tokens consist of a token name and an LPeg pattern that matches a
sequence of characters recognized as an instance of that token. Create tokens
using the [`token()`](#token) function. Let us examine the "whitespace" token
defined in the template shown earlier:

    local ws = token(l.WHITESPACE, l.space^1)

At first glance, the first argument does not appear to be a string name and
the second argument does not appear to be an LPeg pattern. Perhaps you
expected something like:

    local ws = token('whitespace', S('\t\v\f\n\r ')^1)

The `lexer` (`l`) module actually provides a convenient list of common token
names and common LPeg patterns for you to use. Token names include
[`DEFAULT`](#DEFAULT), [`WHITESPACE`](#WHITESPACE), [`COMMENT`](#COMMENT),
[`STRING`](#STRING), [`NUMBER`](#NUMBER), [`KEYWORD`](#KEYWORD),
[`IDENTIFIER`](#IDENTIFIER), [`OPERATOR`](#OPERATOR), [`ERROR`](#ERROR),
[`PREPROCESSOR`](#PREPROCESSOR), [`CONSTANT`](#CONSTANT),
[`VARIABLE`](#VARIABLE), [`FUNCTION`](#FUNCTION), [`CLASS`](#CLASS),
[`TYPE`](#TYPE), [`LABEL`](#LABEL), [`REGEX`](#REGEX), and
[`EMBEDDED`](#EMBEDDED). Patterns include [`any`](#any), [`ascii`](#ascii),
[`extend`](#extend), [`alpha`](#alpha), [`digit`](#digit), [`alnum`](#alnum),
[`lower`](#lower), [`upper`](#upper), [`xdigit`](#xdigit), [`cntrl`](#cntrl),
[`graph`](#graph), [`print`](#print), [`punct`](#punct), [`space`](#space),
[`newline`](#newline), [`nonnewline`](#nonnewline),
[`nonnewline_esc`](#nonnewline_esc), [`dec_num`](#dec_num),
[`hex_num`](#hex_num), [`oct_num`](#oct_num), [`integer`](#integer),
[`float`](#float), and [`word`](#word). You may use your own token names if
none of the above fit your language, but an advantage to using predefined
token names is that your lexer's tokens will inherit the universal syntax
highlighting color theme used by your text editor.

#### Example Tokens

So, how might you define other tokens like comments, strings, and keywords?
Here are some examples.

**Comments**

Line-style comments with a prefix character(s) are easy to express with LPeg:

    local shell_comment = token(l.COMMENT, '#' * l.nonnewline^0)
    local c_line_comment = token(l.COMMENT, '//' * l.nonnewline_esc^0)

The comments above start with a '#' or "//" and go to the end of the line.
The second comment recognizes the next line also as a comment if the current
line ends with a '\' escape character.

C-style "block" comments with a start and end delimiter are also easy to
express:

    local c_comment = token(l.COMMENT, '/*' * (l.any - '*/')^0 * P('*/')^-1)

This comment starts with a "/\*" sequence and contains anything up to and
including an ending "\*/" sequence. The ending "\*/" is optional so the lexer
can recognize unfinished comments as comments and highlight them properly.

**Strings**

It is tempting to think that a string is not much different from the block
comment shown above in that both have start and end delimiters:

    local dq_str = '"' * (l.any - '"')^0 * P('"')^-1
    local sq_str = "'" * (l.any - "'")^0 * P("'")^-1
    local simple_string = token(l.STRING, dq_str + sq_str)

However, most programming languages allow escape sequences in strings such
that a sequence like "\\&quot;" in a double-quoted string indicates that the
'&quot;' is not the end of the string. The above token incorrectly matches
such a string. Instead, use the [`delimited_range()`](#delimited_range)
convenience function.

    local dq_str = l.delimited_range('"')
    local sq_str = l.delimited_range("'")
    local string = token(l.STRING, dq_str + sq_str)

In this case, the lexer treats '\' as an escape character in a string
sequence.

**Keywords**

Instead of matching _n_ keywords with _n_ `P('keyword_`_`n`_`')` ordered
choices, use another convenience function: [`word_match()`](#word_match). It
is much easier and more efficient to write word matches like:

    local keyword = token(l.KEYWORD, l.word_match{
      'keyword_1', 'keyword_2', ..., 'keyword_n'
    })

    local case_insensitive_keyword = token(l.KEYWORD, l.word_match({
      'KEYWORD_1', 'keyword_2', ..., 'KEYword_n'
    }, nil, true))

    local hyphened_keyword = token(l.KEYWORD, l.word_match({
      'keyword-1', 'keyword-2', ..., 'keyword-n'
    }, '-'))

By default, characters considered to be in keywords are in the set of
alphanumeric characters and underscores. The last token demonstrates how to
allow '-' (hyphen) characters to be in keywords as well.

**Numbers**

Most programming languages have the same format for integer and float tokens,
so it might be as simple as using a couple of predefined LPeg patterns:

    local number = token(l.NUMBER, l.float + l.integer)

However, some languages allow postfix characters on integers.

    local integer = P('-')^-1 * (l.dec_num * S('lL')^-1)
    local number = token(l.NUMBER, l.float + l.hex_num + integer)

Your language may need other tweaks, but it is up to you how fine-grained you
want your highlighting to be. After all, you are not writing a compiler or
interpreter!

### Rules

Programming languages have grammars, which specify valid token structure. For
example, comments usually cannot appear within a string. Grammars consist of
rules, which are simply combinations of tokens. Recall from the lexer
template the `_rules` table, which defines all the rules used by the lexer
grammar:

    M._rules = {
      {'whitespace', ws},
    }

Each entry in a lexer's `_rules` table consists of a rule name and its
associated pattern. Rule names are completely arbitrary and serve only to
identify and distinguish between different rules. Rule order is important: if
text does not match the first rule, the lexer tries the second rule, and so
on. This simple grammar says to match whitespace tokens under a rule named
"whitespace".

To illustrate the importance of rule order, here is an example of a
simplified Lua grammar:

    M._rules = {
      {'whitespace', ws},
      {'keyword', keyword},
      {'identifier', identifier},
      {'string', string},
      {'comment', comment},
      {'number', number},
      {'label', label},
      {'operator', operator},
    }

Note how identifiers come after keywords. In Lua, as with most programming
languages, the characters allowed in keywords and identifiers are in the same
set (alphanumerics plus underscores). If the lexer specified the "identifier"
rule before the "keyword" rule, all keywords would match identifiers and thus
incorrectly highlight as identifiers instead of keywords. The same idea
applies to function, constant, etc. tokens that you may want to distinguish
between: their rules should come before identifiers.

So what about text that does not match any rules? For example in Lua, the '!'
character is meaningless outside a string or comment. Normally the lexer
skips over such text. If instead you want to highlight these "syntax errors",
add an additional end rule:

    M._rules = {
      {'whitespace', ws},
      {'error', token(l.ERROR, l.any)},
    }

This identifies and highlights any character not matched by an existing
rule as an `ERROR` token.

Even though the rules defined in the examples above contain a single token,
rules may consist of multiple tokens. For example, a rule for an HTML tag
could consist of a tag token followed by an arbitrary number of attribute
tokens, allowing the lexer to highlight all tokens separately. The rule might
look something like this:

    {'tag', tag_start * (ws * attributes)^0 * tag_end^-1}

Note however that lexers with complex rules like these are more prone to lose
track of their state.

### Summary

Lexers primarily consist of tokens and grammar rules. At your disposal are a
number of convenience patterns and functions for rapidly creating a lexer. If
you choose to use predefined token names for your tokens, you do not have to
define how the lexer highlights them. The tokens will inherit the default
syntax highlighting color theme your editor uses.

## Advanced Techniques

### Styles and Styling

The most basic form of syntax highlighting is assigning different colors to
different tokens. Instead of highlighting with just colors, Scintilla allows
for more rich highlighting, or "styling", with different fonts, font sizes,
font attributes, and foreground and background colors, just to name a few.
The unit of this rich highlighting is called a "style". Styles are simply
strings of comma-separated property settings. By default, lexers associate
predefined token names like `WHITESPACE`, `COMMENT`, `STRING`, etc. with
particular styles as part of a universal color theme. These predefined styles
include [`STYLE_CLASS`](#STYLE_CLASS), [`STYLE_COMMENT`](#STYLE_COMMENT),
[`STYLE_CONSTANT`](#STYLE_CONSTANT), [`STYLE_ERROR`](#STYLE_ERROR),
[`STYLE_EMBEDDED`](#STYLE_EMBEDDED), [`STYLE_FUNCTION`](#STYLE_FUNCTION),
[`STYLE_IDENTIFIER`](#STYLE_IDENTIFIER), [`STYLE_KEYWORD`](#STYLE_KEYWORD),
[`STYLE_LABEL`](#STYLE_LABEL), [`STYLE_NUMBER`](#STYLE_NUMBER),
[`STYLE_OPERATOR`](#STYLE_OPERATOR),
[`STYLE_PREPROCESSOR`](#STYLE_PREPROCESSOR), [`STYLE_REGEX`](#STYLE_REGEX),
[`STYLE_STRING`](#STYLE_STRING), [`STYLE_TYPE`](#STYLE_TYPE),
[`STYLE_VARIABLE`](#STYLE_VARIABLE), and
[`STYLE_WHITESPACE`](#STYLE_WHITESPACE). Like with predefined token names
and LPeg patterns, you may define your own styles. At their core, styles are
just strings, so you may create new ones and/or modify existing ones. Each
style consists of the following comma-separated settings:

Setting        | Description
---------------|------------
font:_name_    | The name of the font the style uses.
size:_int_     | The size of the font the style uses.
[not]bold      | Whether or not the font face is bold.
[not]italics   | Whether or not the font face is italic.
[not]underlined| Whether or not the font face is underlined.
fore:_color_   | The foreground color of the font face.
back:_color_   | The background color of the font face.
[not]eolfilled | Does the background color extend to the end of the line?
case:_char_    | The case of the font ('u': upper, 'l': lower, 'm': normal).
[not]visible   | Whether or not the text is visible.
[not]changeable| Whether the text is changeable or read-only.
[not]hotspot   | Whether or not the text is clickable.

Specify font colors in either "#RRGGBB" format, "0xBBGGRR" format, or the
decimal equivalent of the latter. As with token names, LPeg patterns, and
styles, there is a set of predefined color names, but they vary depending on
the current color theme in use. Therefore, it is generally not a good idea to
manually define colors within styles in your lexer since they might not fit
into a user's chosen color theme. Try to refrain from even using predefined
colors in a style because that color may be theme-specific. Instead, the best
practice is to either use predefined styles or derive new color-agnostic
styles from predefined ones. For example, Lua "longstring" tokens use the
existing `STYLE_STRING` style instead of defining a new one.

#### Example Styles

Defining styles is pretty straightforward. An empty style that inherits the
default theme settings is simply an empty string:

    local style_nothing = ''

A similar style but with a bold font face looks like this:

    local style_bold = 'bold'

If you want the same style, but also with an italic font face, define the new
style in terms of the old one:

    local style_bold_italic = style_bold..',italics'

This allows you to derive new styles from predefined ones without having to
rewrite them. This operation leaves the old style unchanged. Thus if you
had a "static variable" token whose style you wanted to base off of
`STYLE_VARIABLE`, it would probably look like:

    local style_static_var = l.STYLE_VARIABLE..',italics'

The color theme files in the *lexers/themes/* folder give more examples of
style definitions.

### Token Styles

Lexers use the `_tokenstyles` table to assign tokens to particular styles.
Recall the token definition and `_tokenstyles` table from the lexer template:

    local ws = token(l.WHITESPACE, l.space^1)

    ...

    M._tokenstyles = {

    }

Why is a style not assigned to the `WHITESPACE` token? As mentioned earlier,
lexers automatically associate tokens that use predefined token names with a
particular style. Only tokens with custom token names need manual style
associations. As an example, consider a custom whitespace token:

    local ws = token('custom_whitespace', l.space^1)

Assigning a style to this token looks like:

    M._tokenstyles = {
      custom_whitespace = l.STYLE_WHITESPACE
    }

Do not confuse token names with rule names. They are completely different
entities. In the example above, the lexer assigns the "custom_whitespace"
token the existing style for `WHITESPACE` tokens. If instead you want to
color the background of whitespace a shade of grey, it might look like:

    local custom_style = l.STYLE_WHITESPACE..',back:$(color.grey)'
    M._tokenstyles = {
      custom_whitespace = custom_style
    }

Notice that the lexer peforms Scintilla/SciTE-style "$()" property expansion.
You may also use "%()". Remember to refrain from assigning specific colors in
styles, but in this case, all user color themes probably define the
"color.grey" property.

### Line Lexers

By default, lexers match the arbitrary chunks of text passed to them by
Scintilla. These chunks may be a full document, only the visible part of a
document, or even just portions of lines. Some lexers need to match whole
lines. For example, a lexer for the output of a file "diff" needs to know if
the line started with a '+' or '-' and then style the entire line
accordingly. To indicate that your lexer matches by line, use the
`_LEXBYLINE` field:

    M._LEXBYLINE = true

Now the input text for the lexer is a single line at a time. Keep in mind
that line lexers do not have the ability to look ahead at subsequent lines.

### Embedded Lexers

Lexers embed within one another very easily, requiring minimal effort. In the
following sections, the lexer being embedded is called the "child" lexer and
the lexer a child is being embedded in is called the "parent". For example,
consider an HTML lexer and a CSS lexer. Either lexer stands alone for styling
their respective HTML and CSS files. However, CSS can be embedded inside
HTML. In this specific case, the CSS lexer is the "child" lexer with the HTML
lexer being the "parent". Now consider an HTML lexer and a PHP lexer. This
sounds a lot like the case with CSS, but there is a subtle difference: PHP
_embeds itself_ into HTML while CSS is _embedded in_ HTML. This fundamental
difference results in two types of embedded lexers: a parent lexer that
embeds other child lexers in it (like HTML embedding CSS), and a child lexer
that embeds itself within a parent lexer (like PHP embedding itself in HTML).

#### Parent Lexer

Before embedding a child lexer into a parent lexer, the parent lexer needs to
load the child lexer. This is done with the [`load()`](#load) function. For
example, loading the CSS lexer within the HTML lexer looks like:

    local css = l.load('css')

The next part of the embedding process is telling the parent lexer when to
switch over to the child lexer and when to switch back. The lexer refers to
these indications as the "start rule" and "end rule", respectively, and are
just LPeg patterns. Continuing with the HTML/CSS example, the transition from
HTML to CSS is when the lexer encounters a "style" tag with a "type"
attribute whose value is "text/css":

    local css_tag = P('<style') * P(function(input, index)
      if input:find('^[^>]+type="text/css"', index) then
        return index
      end
    end)

This pattern looks for the beginning of a "style" tag and searches its
attribute list for the text "`type="text/css"`". (In this simplified example,
the Lua pattern does not consider whitespace between the '=' nor does it
consider that using single quotes is valid.) If there is a match, the
functional pattern returns a value instead of `nil`. In this case, the value
returned does not matter because we ultimately want to style the "style" tag
as an HTML tag, so the actual start rule looks like this:

    local css_start_rule = #css_tag * tag

Now that the parent knows when to switch to the child, it needs to know when
to switch back. In the case of HTML/CSS, the switch back occurs when the
lexer encounters an ending "style" tag, though the lexer should still style
the tag as an HTML tag:

    local css_end_rule = #P('</style>') * tag

Once the parent loads the child lexer and defines the child's start and end
rules, it embeds the child with the [`embed_lexer()`](#embed_lexer) function:

    l.embed_lexer(M, css, css_start_rule, css_end_rule)

The first parameter is the parent lexer object to embed the child in, which
in this case is `M`. The other three parameters are the child lexer object
loaded earlier followed by its start and end rules.

#### Child Lexer

The process for instructing a child lexer to embed itself into a parent is
very similar to embedding a child into a parent: first, load the parent lexer
into the child lexer with the [`load()`](#load) function and then create
start and end rules for the child lexer. However, in this case, swap the
lexer object arguments to [`embed_lexer()`](#embed_lexer). For example, in
the PHP lexer:

    local html = l.load('html')
    local php_start_rule = token('php_tag', '<?php ')
    local php_end_rule = token('php_tag', '?>')
    l.embed_lexer(html, M, php_start_rule, php_end_rule)

## Code Folding

When reading source code, it is occasionally helpful to temporarily hide
blocks of code like functions, classes, comments, etc. This is the concept of
"folding". In the Textadept and SciTE editors for example, little indicators
in the editor margins appear next to code that can be folded at places called
"fold points". When the user clicks an indicator, the editor hides the code
associated with the indicator until the user clicks the indicator again. The
lexer specifies these fold points and what code exactly to fold.

The fold points for most languages occur on keywords or character sequences.
Examples of fold keywords are "if" and "end" in Lua and examples of fold
character sequences are '{', '}', "/\*", and "\*/" in C for code block and
comment delimiters, respectively. However, these fold points cannot occur
just anywhere. For example, lexers should not recognize fold keywords that
appear within strings or comments. The lexer's `_foldsymbols` table allows
you to conveniently define fold points with such granularity. For example,
consider C:

    M._foldsymbols = {
      [l.OPERATOR] = {['{'] = 1, ['}'] = -1},
      [l.COMMENT] = {['/*'] = 1, ['*/'] = -1},
      _patterns = {'[{}]', '/%*', '%*/'}
    }

The first assignment states that any '{' or '}' that the lexer recognized as
an `OPERATOR` token is a fold point. The integer `1` indicates the match is
a beginning fold point and `-1` indicates the match is an ending fold point.
Likewise, the second assignment states that any "/\*" or "\*/" that the lexer
recognizes as part of a `COMMENT` token is a fold point. The lexer does not
consider any occurences of these characters outside their defined tokens
(such as in a string) as fold points. Finally, every `_foldsymbols` table
must have a `_patterns` field that contains a list of [Lua patterns][] that
match fold points. If the lexer encounters text that matches one of those
patterns, the lexer looks up the matched text in its token's table to
determine whether or not the text is a fold point. In the example above, the
first Lua pattern matches any '{' or '}' characters. When the lexer comes
across one of those characters, it checks if the match is an `OPERATOR`
token. If so, the lexer identifies the match as a fold point. The same idea
applies for the other patterns. (The '%' is in the other patterns because
'\*' is a special character in Lua patterns that needs escaping.) How do you
specify fold keywords? Here is an example for Lua:

    M._foldsymbols = {
      [l.KEYWORD] = {
        ['if'] = 1, ['do'] = 1, ['function'] = 1,
        ['end'] = -1, ['repeat'] = 1, ['until'] = -1
      },
      _patterns = {'%l+'}
    }

Any time the lexer encounters a lower case word, if that word is a `KEYWORD`
token and in the associated list of fold points, the lexer identifies the
word as a fold point.

If your lexer needs to do some additional processing to determine if a match
is a fold point, assign a function that returns an integer. Returning `1` or
`-1` indicates the match is a fold point. Returning `0` indicates it is not.
For example:

    local function fold_strange_token(text, pos, line, s, match)
      if ... then
        return 1 -- beginning fold point
      elseif ... then
        return -1 -- ending fold point
      end
      return 0
    end

    M._foldsymbols = {
      ['strange_token'] = {['|'] = fold_strange_token},
      _patterns = {'|'}
    }

Any time the lexer encounters a '|' that is a "strange_token", it calls the
`fold_strange_token` function to determine if '|' is a fold point. The lexer
calls these functions with the following arguments: the text to identify fold
points in, the beginning position of the current line in the text to fold,
the current line's text, the position in the current line the matched text
starts at, and the matched text itself.

[Lua patterns]: http://www.lua.org/manual/5.2/manual.html#6.4.1

## Using Lexers

### Textadept

Put your lexer in your *~/.textadept/lexers/* directory so you do not
overwrite it when upgrading Textadept. Also, lexers in this directory
override default lexers. Thus, Textadept loads a user *lua* lexer instead of
the default *lua* lexer. This is convenient for tweaking a default lexer to
your liking. Then add a [file type][] for your lexer if necessary.

[file type]: _M.textadept.file_types.html

### SciTE

Create a *.properties* file for your lexer and `import` it in either your
*SciTEUser.properties* or *SciTEGlobal.properties*. The contents of the
*.properties* file should contain:

    file.patterns.[lexer_name]=[file_patterns]
    lexer.$(file.patterns.[lexer_name])=[lexer_name]

where `[lexer_name]` is the name of your lexer (minus the *.lua* extension)
and `[file_patterns]` is a set of file extensions to use your lexer for.

Please note that Lua lexers ignore any styling information in *.properties*
files. Your theme file in the *lexers/themes/* directory contains styling
information.

## Considerations

### Performance

There might be some slight overhead when initializing a lexer, but loading a
file from disk into Scintilla is usually more expensive. On modern computer
systems, I see no difference in speed between LPeg lexers and Scintilla's C++
ones. Optimize lexers for speed by re-arranging rules in the `_rules` table
so that the most common rules match first. Do keep in mind that order matters
for similar rules.

### Limitations

Embedded preprocessor languages like PHP cannot completely embed in their
parent languages in that the parent's tokens do not support start and end
rules. This mostly goes unnoticed, but code like

    <div id="<?php echo $id; ?>">

or

    <div <?php if ($odd) { echo 'class="odd"'; } ?>>

will not style correctly.

### Troubleshooting

Errors in lexers can be tricky to debug. Lexers print Lua errors to
`io.stderr` and `_G.print()` statements to `io.stdout`. Running your editor
from a terminal is the easiest way to see errors as they occur.

### Risks

Poorly written lexers have the ability to crash Scintilla (and thus its
containing application), so unsaved data might be lost. However, I have only
observed these crashes in early lexer development, when syntax errors or
pattern errors are present. Once the lexer actually starts styling text
(either correctly or incorrectly, it does not matter), I have not observed
any crashes.

### Acknowledgements

Thanks to Peter Odding for his [lexer post][] on the Lua mailing list
that inspired me, and thanks to Roberto Ierusalimschy for LPeg.

[lexer post]: http://lua-users.org/lists/lua-l/2007-04/msg00116.html

LEXERPATH (string)
:    The path used to search for a lexer to load.
:    Identical in format to Lua's `package.path` string.
:    The default value is `package.path`.
DEFAULT (string)
:    The token name for default tokens.
WHITESPACE (string)
:    The token name for whitespace tokens.
COMMENT (string)
:    The token name for comment tokens.
STRING (string)
:    The token name for string tokens.
NUMBER (string)
:    The token name for number tokens.
KEYWORD (string)
:    The token name for keyword tokens.
IDENTIFIER (string)
:    The token name for identifier tokens.
OPERATOR (string)
:    The token name for operator tokens.
ERROR (string)
:    The token name for error tokens.
PREPROCESSOR (string)
:    The token name for preprocessor tokens.
CONSTANT (string)
:    The token name for constant tokens.
VARIABLE (string)
:    The token name for variable tokens.
FUNCTION (string)
:    The token name for function tokens.
CLASS (string)
:    The token name for class tokens.
TYPE (string)
:    The token name for type tokens.
LABEL (string)
:    The token name for label tokens.
REGEX (string)
:    The token name for regex tokens.
STYLE_CLASS (string)
:    The style typically used for class definitions.
STYLE_COMMENT (string)
:    The style typically used for code comments.
STYLE_CONSTANT (string)
:    The style typically used for constants.
STYLE_ERROR (string)
:    The style typically used for erroneous syntax.
STYLE_FUNCTION (string)
:    The style typically used for function definitions.
STYLE_KEYWORD (string)
:    The style typically used for language keywords.
STYLE_LABEL (string)
:    The style typically used for labels.
STYLE_NUMBER (string)
:    The style typically used for numbers.
STYLE_OPERATOR (string)
:    The style typically used for operators.
STYLE_REGEX (string)
:    The style typically used for regular expression strings.
STYLE_STRING (string)
:    The style typically used for strings.
STYLE_PREPROCESSOR (string)
:    The style typically used for preprocessor statements.
STYLE_TYPE (string)
:    The style typically used for static types.
STYLE_VARIABLE (string)
:    The style typically used for variables.
STYLE_WHITESPACE (string)
:    The style typically used for whitespace.
STYLE_EMBEDDED (string)
:    The style typically used for embedded code.
STYLE_IDENTIFIER (string)
:    The style typically used for identifier words.
STYLE_DEFAULT (string)
:    The style all styles are based off of.
STYLE_LINENUMBER (string)
:    The style used for all margins except fold margins.
STYLE_BRACELIGHT (string)
:    The style used for highlighted brace characters.
STYLE_BRACEBAD (string)
:    The style used for unmatched brace characters.
STYLE_CONTROLCHAR (string)
:    The style used for control characters.
:    Color attributes are ignored.
STYLE_INDENTGUIDE (string)
:    The style used for indentation guides.
STYLE_CALLTIP (string)
:    The style used by call tips if `buffer.call_tip_use_style` is set.
:    Only the font name, size, and color attributes are used.
any (pattern)
:    A pattern that matches any single character.
ascii (pattern)
:    A pattern that matches any ASCII character (codes 0 to 127).
extend (pattern)
:    A pattern that matches any ASCII extended character (codes 0 to 255).
alpha (pattern)
:    A pattern that matches any alphabetic character ('A'-'Z', 'a'-'z').
digit (pattern)
:    A pattern that matches any digit ('0'-'9').
alnum (pattern)
:    A pattern that matches any alphanumeric character ('A'-'Z', 'a'-'z',
:      '0'-'9').
lower (pattern)
:    A pattern that matches any lower case character ('a'-'z').
upper (pattern)
:    A pattern that matches any upper case character ('A'-'Z').
xdigit (pattern)
:    A pattern that matches any hexadecimal digit ('0'-'9', 'A'-'F', 'a'-'f').
cntrl (pattern)
:    A pattern that matches any control character (ASCII codes 0 to 31).
graph (pattern)
:    A pattern that matches any graphical character ('!' to '~').
print (pattern)
:    A pattern that matches any printable character (' ' to '~').
punct (pattern)
:    A pattern that matches any punctuation character ('!' to '/', ':' to '@',
:    '[' to ''', '{' to '~').
space (pattern)
:    A pattern that matches any whitespace character ('\t', '\v', '\f', '\n',
:    '\r', space).
newline (pattern)
:    A pattern that matches any set of end of line characters.
nonnewline (pattern)
:    A pattern that matches any single, non-newline character.
nonnewline_esc (pattern)
:    A pattern that matches any single, non-newline character or any set of end
:    of line characters escaped with '\'.
dec_num (pattern)
:    A pattern that matches a decimal number.
hex_num (pattern)
:    A pattern that matches a hexadecimal number.
oct_num (pattern)
:    A pattern that matches an octal number.
integer (pattern)
:    A pattern that matches either a decimal, hexadecimal, or octal number.
float (pattern)
:    A pattern that matches a floating point number.
word (pattern)
:    A pattern that matches a typical word. Words begin with a letter or
:    underscore and consist of alphanumeric and underscore characters.
FOLD_BASE (number)
:    The initial (root) fold level.
FOLD_BLANK (number)
:    Flag indicating that the line is blank.
FOLD_HEADER (number)
:    Flag indicating the line is fold point.
fold_level (table, Read-only)
:    Table of fold level bit-masks for line numbers starting from zero.
:    Fold level masks are composed of an integer level combined with any of the
:    following bits:
:    * `lexer.FOLDBASE`
:      The initial fold level.
:    * `lexer.FOLD_BLANK`
:      The line is blank.
:    * `lexer.FOLD_HEADER`
:      The line is a header, or fold point.
indent_amount (table, Read-only)
:    Table of indentation amounts in character columns, for line numbers
:    starting from zero.
property (table)
:    Map of key-value string pairs.
property_expanded (table, Read-only)
:    Map of key-value string pairs with `$()` and `%()` variable replacement
:    performed in values.
property_int (table, Read-only)
:    Map of key-value pairs with values interpreted as numbers, or `0` if not
:    found.
style_at (table, Read-only)
:    Table of style names at positions in the buffer starting from zero.



[lexer doc]: http://foicica.com/scintillua/api/lexer.html
