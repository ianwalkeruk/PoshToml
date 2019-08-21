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


# placeholders
$basicString = '#basicString'
$dottedKey   = '#dottedKey'
$keyvalSep   = '#keyvalSep'
$table       = '#table'
$newLine     = '#newLine'
$literalString = '#literalString'
$val         = '#val'


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
$nonAscii = RxAlternate @('[\x80-\uD7FF]' , '[\uE000-\uFFFF]')
$nonEol = RxAlternate @('\x09', '[\x20-\x7F]', $nonAscii)
$comment = $commentStartSymbol + (RxZeroOrMore $nonEol)



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

$quotedKey = RxAlternate @( $basicString, $literalString )
$unquotedKey = RxOneOrMore (RxAlternate @( '[A-Za-z]', '[0-9]', '\x2D', '\x5F'))
$simpleKey = RxAlternate @( $quotedKey, $unquotedKey )
$key = RxAlternate @( $simpleKey, $dottedKey )
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
toml = expression *( newline expression )
#>
$toml = $expression + ( RxZeroOrMore $newLine + $expression )
$toml

