Set-StrictMode -Version Latest

<#
This script is an interim script for building regex patterns for TOML parsing.
Once complete, the various elements will be moved into PowerShell modules, and
this file will no longer be needed. Ideally it will never reach the master branch.

ABNF for TOML: https://github.com/toml-lang/toml/blob/master/toml.abnf
#>

# Some utility regex functions

function RxAlternate( [string[]]$x ) {
    $ret = '(?:'
    $ret += $x -join '|'
    $ret += ')'
    return $ret
}

function RxOptional( [string]$s) {
    return '(?:' + $s + ')?'
}

function RxZeroOrMore( [string]$s ) {
    return '(?:' + $s + ')*'
}

function RxOneOrMore( [string] $s ) {
    return '(?:' +$s + ')+'
}

function RxSeparatedList( [string]$s, [string]$sep) {
    return $s + (RxOneOrMore ($sep + $s))
}

function RxMultiple([int]$m, [string]$s) {
    return '(?:' + $s + '){' + $m + '}'
}



<#
ALPHA = %x41-5A / %x61-7A ; A-Z / a-z
DIGIT = %x30-39 ; 0-9
HEXDIG = DIGIT / "A" / "B" / "C" / "D" / "E" / "F"
#>
$ALPHA = '[A-Za-z]'
$DIGIT = '[0-9]'
$HEXDIG ='[0-9A-F]'


<#
ws = *wschar
wschar =  %x20  ; Space
wschar =/ %x09  ; Horizontal tab
#>
$wschar = RxAlternate @(
    '\x20',
    '\x09'
)
$ws = RxZeroOrMore $wschar


<#
escape = %x5C                   ; \
escape-seq-char =  %x22         ; "    quotation mark  U+0022
escape-seq-char =/ %x5C         ; \    reverse solidus U+005C
escape-seq-char =/ %x62         ; b    backspace       U+0008
escape-seq-char =/ %x66         ; f    form feed       U+000C
escape-seq-char =/ %x6E         ; n    line feed       U+000A
escape-seq-char =/ %x72         ; r    carriage return U+000D
escape-seq-char =/ %x74         ; t    tab             U+0009
escape-seq-char =/ %x75 4HEXDIG ; uXXXX                U+XXXX
escape-seq-char =/ %x55 8HEXDIG ; UXXXXXXXX            U+XXXXXXXX
#>
$escapeSeqChar = RxAlternate @(
    '\x22',
    '\x5C',
    '\x62',
    '\x66',
    '\x6E',
    '\x72',
    '\x74',
    '\x75' + (RxMultiple 4 $HEXDIG),
    '\x55' + (RxMultiple 7 $HEXDIG)
)
$escape = '\x5C'



<#
comment-start-symbol = %x23 ; #
non-ascii = %x80-D7FF / %xE000-10FFFF
    IW - .NET Regex cannot handle higher than \uFFFF
non-eol = %x09 / %x20-7F / non-ascii

comment = comment-start-symbol *non-eol
#>
$commentStartSymbol = '\x23'
$nonAscii = '[\u0080-\uDFFF\uE000-\uFFFF]'
$nonEol = RxAlternate @('[\x09\x20-\x7F]', $nonAscii)
$comment = $commentStartSymbol + (RxZeroOrMore $nonEol)



<#
basic-char = basic-unescaped / escaped
basic-unescaped = wschar / %x21 / %x23-5B / %x5D-7E / non-ascii
escaped = escape escape-seq-char
#>
$escaped = $escape + $escapeSeqChar
$basicUnescaped = RxAlternate @($wschar, '[\x21\x23-\x5B\x5D-\x7E]', $nonAscii)
$basicChar = RxAlternate @($basicUnescaped, $escaped)



<#
quotation-mark = %x22            ; "
literal-string = apostrophe *literal-char apostrophe
apostrophe = %x27 ; ' apostrophe
literal-char = %x09 / %x20-26 / %x28-7E / non-ascii
#>
$literalChar = RxAlternate @('[\x09\x20-\x26\x28\x7E]', $nonAscii)
$apostrophe = '\x27'
$literalString = $apostrophe + (RxZeroOrMore $literalChar) + $apostrophe
$quotationMark = '\x22'



<#
ml-literal-string = ml-literal-string-delim ml-literal-body ml-literal-string-delim
ml-literal-string-delim = 3apostrophe
ml-literal-body = *( ml-literal-char / newline )
ml-literal-char = %x09 / %x20-7E / non-ascii
#>
$mlLiteralChar = RxAlternate @('\x09[\x20-\x7E]', $nonAscii)
$mlLiteralBody = RxZeroOrMore (RxAlternate @($mlLiteralChar, $newline))
$mlLiteralStringDelim = RxMultiple 3 $apostrophe
$mlLiteralString = $mlLiteralStringDelim + $mlLiteralBody + $mlLiteralStringDelim



<#
ml-basic-string = ml-basic-string-delim ml-basic-body ml-basic-string-delim
ml-basic-string-delim = 3quotation-mark
ml-basic-body = *( ml-basic-char / newline / ( escape ws newline ) )
ml-basic-char = ml-basic-unescaped / escaped
ml-basic-unescaped = wschar / %x21-5B / %x5D-7E / non-ascii
#>
$mlBasicUnescaped = RxAlternate @($wschar, '[\x21-\x5B\x5D-\x7E]', $nonAscii)
$mlBasicChar = RxAlternate @($mlBasicUnescaped, $escaped)
$mlBasicBody = RxZeroOrMore (RxAlternate @($mlBasicChar, $newline, ($escape + $ws + $newline) ) )
$mlBasicStringDelim = RxMultiple 3 $quotationMark
$mlBasicString = $mlBasicStringDelim + $mlBasicBody + $mlBasicStringDelim



<#
string = ml-basic-string / basic-string / ml-literal-string / literal-string
basic-string = quotation-mark *basic-char quotation-mark
#>
$basicString = $quotationMark + (RxZeroOrMore $basicChar) + $quotationMark
$string = RxAlternate @($mlBasicString, $basicString, $mlLiteralString, $literalString)






<#
key = simple-key / dotted-key
simple-key = quoted-key / unquoted-key
unquoted-key = 1*( ALPHA / DIGIT / %x2D / %x5F ) ; A-Z / a-z / 0-9 / - / _
quoted-key = basic-string / literal-string
dotted-key = simple-key 1*( dot-sep simple-key )
dot-sep   = ws %x2E ws  ; . Period
#>
$quotedKey = RxAlternate @( $basicString, $literalString )
$unquotedKey = RxOneOrMore ( '[A-Za-z0-9\x2D\x5F]' )
$simpleKey = RxAlternate @( $quotedKey, $unquotedKey )
$dotSep    = $ws + '\x2E' + $ws
$dottedKey = $simpleKey + ( RxOneOrMore ($dotSep + $simpleKey) )
$simpleKey = RxAlternate @( $quotedKey, $unquotedKey )
$key = RxAlternate @( $simpleKey, $dottedKey )



<#
table = std-table / array-table
std-table = std-table-open key std-table-close
std-table-open  = %x5B ws     ; [ Left square bracket
std-table-close = ws %x5D     ; ] Right square bracket
inline-table = inline-table-open [ inline-table-keyvals ] inline-table-close
inline-table-open  = %x7B ws     ; {
inline-table-close = ws %x7D     ; }
inline-table-sep   = ws %x2C ws  ; , Comma
inline-table-keyvals = key keyval-sep val [ inline-table-sep inline-table-keyvals ]
array-table = array-table-open key array-table-close
array-table-open  = %x5B.5B ws  ; [[ Double left square bracket
array-table-close = ws %x5D.5D  ; ]] Double right square bracket
#>
$arrayTableClose = $ws + '\x5D\x5D'
$arrayTableOpen = '\x5B\x5B' + $ws
$arrayTable = $arrayTableOpen + $key + $arrayTableClose
$inlineTableSep = $ws + '\x2C' + $ws
$inlineTableKeyvals = RxSeparatedList ($key + $keyvalSep + $val) $inlineTableSep
$inlineTableClose = $ws + '\x7D'
$inlineTableOpen = '\x7B' + $ws
$inlineTable = $inlineTableOpen + (RxOptional $inlineTableKeyvals) + $inlineTableClose
$stdTableClose = $ws + '\x5D'
$stdTableOpen = '\x5B' + $ws
$stdTable = $stdTableOpen + $key + $stdTableClose
$table = RxAlternate @($stdTable, $arrayTable)



<#
keyval = key keyval-sep val
keyval-sep = ws %x3D ws ; =
val = string / boolean / array / inline-table / date-time / float / integer
#>
$val = RxAlternate @( $string, $boolean, $array, $inlineTable, $dateTime, $float, $integer )
$keyvalSep = $ws + '\x3D' + $ws
$keyval = $key + $keyvalSep + $val 



<#
expression =  ws [ comment ]
expression =/ ws keyval ws [ comment ]
expression =/ ws table ws [ comment ]
#>
$expression = RxAlternate @(
    $ws + (RxOptional $comment),
    $ws + $keyval + $ws + (RxOptional $comment),
    $ws + $table + $ws + (RxOptional $comment)
)



<#
table = std-table / array-table
std-table = std-table-open key std-table-close
std-table-open  = %x5B ws     ; [ Left square bracket
std-table-close = ws %x5D     ; ] Right square bracket
inline-table = inline-table-open [ inline-table-keyvals ] inline-table-close
inline-table-open  = %x7B ws     ; {
inline-table-close = ws %x7D     ; }
inline-table-sep   = ws %x2C ws  ; , Comma
inline-table-keyvals = key keyval-sep val [ inline-table-sep inline-table-keyvals ]
array-table = array-table-open key array-table-close
array-table-open  = %x5B.5B ws  ; [[ Double left square bracket
array-table-close = ws %x5D.5D  ; ]] Double right square bracket
#>
$arrayTableClose = $ws + '\x5D\x5D'
$arrayTableOpen = '\x5B\x5B' + $ws
$arrayTable = $arrayTableOpen + $key + $arrayTableClose
$inlineTableSep = $ws + '\x2C' + $ws
$inlineTableKeyvals = RxSeparatedList ($key + $keyvalSep + $val) $inlineTableSep
$inlineTableClose = $ws + '\x7D'
$inlineTableOpen = '\x7B' + $ws
$inlineTable = $inlineTableOpen + (RxOptional $inlineTableKeyvals) + $inlineTableClose
$stdTableClose = $ws + '\x5D'
$stdTableOpen = '\x5B' + $ws
$stdTable = $stdTableOpen + $key + $stdTableClose
$table = RxAlternate @($stdTable, $arrayTable)

<#
newline =  %x0A     ; LF
newline =/ %x0D.0A  ; CRLF
#>
$newline = RxAlternate @(
    '\x0A',
    '\x0D\x0A'
)



<#
toml = expression *( newline expression )
#>
$toml = $expression + ( RxZeroOrMore ($newLine + $expression) )
$toml
[regex]::new($toml)
