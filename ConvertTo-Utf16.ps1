param (
    [int64]$CodePoint
)

process {
    $h = ($CodePoint -band [convert]::ToInt64("11111111110000000000",2)) -shr 10
    $l =  $CodePoint -band [convert]::ToInt64(          "1111111111",2)

    $hw = [convert]::ToString($h + 0xD800, 16).ToUpper()
    $lw = [convert]::ToString($l + 0xDC00, 16).ToUpper()

    return "\u$hw\u$lw"
}