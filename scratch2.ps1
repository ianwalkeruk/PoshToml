Set-StrictMode -Version Latest

class Toml {
    static [string]$regex = '(.*)(?:\x0D?\x0A(.*))'

    # non-capturing simple expressions
    static [string]$ws       = '[\x09\x20]*'
    static [string]$nonAscii = '[\u0080-\uFFFF]'
    static [string]$comment  = "\x23(?:[\x09\x20-\x7F]|$nonAscii)*"

    [TomlExpression[]]$expressions

    static [Toml]parse([string]$expr) {
        $ret = [Toml]::new()
        if ($expr -match [Toml]::regex) {
            for ($i = 1; $i -lt $Matches.Count; $i++) {
                $ret.expressions += @([TomlExpression]::parse( $Matches[$i] ))
            }
        } else {
            throw "Not valid TOML: $expr"
        }
        return $ret
    }
}

class TomlExpression {
    static [TomlExpression]parse([string]$expr) {
        if ($expr -match [TomlBlankExpression]::regex) {
            Write-Host $Matches[0]
        }
        return [TomlExpression]::new()
    }
}

class TomlBlankExpression : TomlExpression {
    static [string]$regex = [Toml]::ws + [Toml]::comment
}

$t = @"
This is a test
This is a second test
"@
$x = [Toml]::parse($t)
[Toml]::comment
