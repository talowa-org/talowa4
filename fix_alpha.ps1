Param([double]$DefaultAlpha = 0.2)

$ErrorActionPreference = 'Stop'
$pattern = [regex]'withValues\s*\(\s*alpha\s*:\s*\)'
$replace = "withValues(alpha: $DefaultAlpha)"
$changed = 0

Get-ChildItem -Path 'lib' -Recurse -Filter '*.dart' | ForEach-Object {
  $p = $_.FullName
  $c = Get-Content -Raw -LiteralPath $p
  if ($pattern.IsMatch($c)) {
    $n = $pattern.Replace($c, $replace)
    Set-Content -LiteralPath $p -Value $n
    Write-Host "Fixed: $p"
    $changed++
  }
}

Write-Host "Total files fixed: $changed"