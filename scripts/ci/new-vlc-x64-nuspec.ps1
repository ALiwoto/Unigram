param(
  [Parameter(Mandatory = $true)]
  [string]$InputPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath
)

$content = Get-Content $InputPath
$filtered = $content | Where-Object {
  $_ -notmatch 'winarm64-uwp' -and $_ -notmatch 'build/win10-arm64'
}

Set-Content -Path $OutputPath -Value $filtered
