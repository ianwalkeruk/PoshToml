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

<#
ws = *wschar
wschar =  %x20  ; Space
wschar =/ %x09  ; Horizontal tab
#>
$rxWschar = RxAlternate @(
    '\x20',
    '\x09'
)
$rxWs = RxZeroOrMore $rxWschar

<#
comment-start-symbol = %x23 ; #
non-ascii = %x80-D7FF / %xE000-10FFFF
non-eol = %x09 / %x20-7F / non-ascii

comment = comment-start-symbol *non-eol
#>
$rxCommentStartSymbol = '\x23'
$rxNonAscii = RxAlternate @('[\x80-\uD7FF]' , '[\uE000-\uFFFF]')
$rxNonEol = RxAlternate @('\x09', '[\x20-\x7F]', $rxNonAscii)
$rxComment = $rxCommentStartSymbol + (RxZeroOrMore $rxNonEol)

<#
keyval = key keyval-sep val

key = simple-key / dotted-key
simple-key = quoted-key / unquoted-key

unquoted-key = 1*( ALPHA / DIGIT / %x2D / %x5F ) ; A-Z / a-z / 0-9 / - / _
quoted-key = basic-string / literal-string
dotted-key = simple-key 1*( dot-sep simple-key )

dot-sep   = ws %x2E ws  ; . Period
keyval-sep = ws %x3D ws ; =

val = string / boolean / array / inline-table / date-time / float / integer
#>
$rxKeyval = $rxKey + $rxKeyvalSep + $rxVal 


<#
expression =  ws [ comment ]
expression =/ ws keyval ws [ comment ]
expression =/ ws table ws [ comment ]
#>
$rxExpression = RxAlternate @(
    $rxWs + (RxOptional $rxComment),
    $rxWs + $rxKeyval + $rxWs + (RxOptional $rxComment),
    $rxWs + $rxTable + $rxWs + (RxOptional $rxComment)
)

<#
toml = expression *( newline expression )
#>
$rxToml = $rxExpression + ( RxZeroOrMore $rxNewline + $rxExpression )
$rxToml

