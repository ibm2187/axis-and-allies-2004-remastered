param([string]$Path)
$b = [IO.File]::ReadAllBytes($Path)
$pe = [BitConverter]::ToInt32($b, 0x3C)
$machine = [BitConverter]::ToUInt16($b, $pe + 4)
$nsec = [BitConverter]::ToUInt16($b, $pe + 6)
$ts = [BitConverter]::ToUInt32($b, $pe + 8)
$optSize = [BitConverter]::ToUInt16($b, $pe + 20)
$chars = [BitConverter]::ToUInt16($b, $pe + 22)
$opt = $pe + 24
$magic = [BitConverter]::ToUInt16($b, $opt)
$dllChars = [BitConverter]::ToUInt16($b, $opt + 70)
"Machine: 0x{0:X}  Magic: 0x{1:X}  Sections: {2}" -f $machine, $magic, $nsec
"Linked: " + ([DateTimeOffset]::FromUnixTimeSeconds($ts).UtcDateTime)
"Characteristics: 0x{0:X} (LARGE_ADDRESS_AWARE={1})" -f $chars, (($chars -band 0x20) -ne 0)
"DllCharacteristics: 0x{0:X}" -f $dllChars
"Subsystem ver: {0}.{1}" -f [BitConverter]::ToUInt16($b, $opt + 48), [BitConverter]::ToUInt16($b, $opt + 50)
$secStart = $opt + $optSize
$secs = @()
for ($i = 0; $i -lt $nsec; $i++) {
  $o = $secStart + 40 * $i
  $name = [Text.Encoding]::ASCII.GetString($b, $o, 8).TrimEnd([char]0)
  $vs = [BitConverter]::ToUInt32($b, $o + 8); $va = [BitConverter]::ToUInt32($b, $o + 12)
  $rs = [BitConverter]::ToUInt32($b, $o + 16); $rp = [BitConverter]::ToUInt32($b, $o + 20)
  $secs += [pscustomobject]@{Name=$name; VA=$va; VSize=$vs; RawSize=$rs; RawPtr=$rp}
}
$secs | Format-Table -AutoSize | Out-String
function RvaToOff($rva) { foreach ($s in $secs) { if ($rva -ge $s.VA -and $rva -lt $s.VA + [Math]::Max($s.VSize, $s.RawSize)) { return $rva - $s.VA + $s.RawPtr } }; return -1 }
function CStr($off) { $e = $off; while ($b[$e] -ne 0) { $e++ }; [Text.Encoding]::ASCII.GetString($b, $off, $e - $off) }
$impRva = [BitConverter]::ToUInt32($b, $opt + 96 + 8)
$d = RvaToOff $impRva
"Imports:"
while ($true) {
  $oft = [BitConverter]::ToUInt32($b, $d); $nameRva = [BitConverter]::ToUInt32($b, $d + 12); $ft = [BitConverter]::ToUInt32($b, $d + 16)
  if ($nameRva -eq 0) { break }
  $dll = CStr (RvaToOff $nameRva)
  $t = RvaToOff ($(if ($oft) { $oft } else { $ft }))
  $fns = @()
  while ($true) { $v = [BitConverter]::ToUInt32($b, $t); if ($v -eq 0) { break }; if ($v -band 0x80000000) { $fns += "#" + ($v -band 0xFFFF) } else { $fns += CStr ((RvaToOff $v) + 2) }; $t += 4 }
  "  {0} ({1}): {2}" -f $dll, $fns.Count, (($fns | Select-Object -First 12) -join ', ')
  $d += 20
}
