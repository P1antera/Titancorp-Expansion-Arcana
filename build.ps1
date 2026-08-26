[CmdletBinding()]
param(
  [string]$AssetPacker,
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($AssetPacker)) {
  $AssetPacker = Join-Path $PSScriptRoot '..\..\..\win32\asset_packer.exe'
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $PSScriptRoot 'build\Titancorp-Expansion-Arcana.pak'
}

$AssetPacker = [System.IO.Path]::GetFullPath($AssetPacker)
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

if (-not (Test-Path -LiteralPath $AssetPacker -PathType Leaf)) {
  throw "asset_packer.exe was not found: $AssetPacker"
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$stagingDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("titancorp-expansion-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $stagingDirectory | Out-Null

try {
  # Stage the asset root outside the project so output files and Git data cannot enter the package.
  & robocopy $PSScriptRoot $stagingDirectory /E /XD .git build .agents /XF .gitignore README.md build.ps1 | Out-Null
  if ($LASTEXITCODE -gt 7) {
    throw "robocopy failed with exit code $LASTEXITCODE"
  }

  & $AssetPacker $stagingDirectory $OutputPath
  if ($LASTEXITCODE -ne 0) {
    throw "asset_packer.exe failed with exit code $LASTEXITCODE"
  }

  Write-Host "Built $OutputPath"
}
finally {
  Remove-Item -LiteralPath $stagingDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
