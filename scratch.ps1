Set-StrictMode -Version Latest

<#
This script is an interim script for building regex patterns for TOML parsing.
Once complete, the various elements will be moved into PowerShell modules, and
this file will no longer be needed. Ideally it will never reach the master branch.
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

# placeholders
$string = 'STRING'
$boolean = 'BOOLEAN'
$array = 'ARRAY'

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
comment-start-symbol = %x23 ; #
non-ascii = %x80-D7FF / %xE000-10FFFF
non-eol = %x09 / %x20-7F / non-ascii

comment = comment-start-symbol *non-eol
#>
$commentStartSymbol = '\x23'
$nonAscii = RxAlternate @('[\x80-\uD7FF]' , '[\uE000-\U0010FFFF]')
$nonEol = RxAlternate @('\x09', '[\x20-\x7F]', $nonAscii)
$comment = $commentStartSymbol + (RxZeroOrMore $nonEol)

<#
key = simple-key / dotted-key
simple-key = quoted-key / unquoted-key
unquoted-key = 1*( ALPHA / DIGIT / %x2D / %x5F ) ; A-Z / a-z / 0-9 / - / _
quoted-key = basic-string / literal-string
dotted-key = simple-key 1*( dot-sep simple-key )
dot-sep   = ws %x2E ws  ; . Period
#>
$quotedKey = RxAlternate @( $basicString, $literalString )
$unquotedKey = RxOneOrMore ( RxAlternate @( '[A-Za-z]', '[0-9]', '\x2D', '\x5F') )
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
