param(
    [string]$Godot = 'C:/Users/sjkim/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$assetRoot = $PSScriptRoot
$repoRoot = Split-Path (Split-Path $assetRoot -Parent) -Parent
$validationRoot = Join-Path ([IO.Path]::GetTempPath()) ('JAMO_ASSET02_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$validationRoot/art/monsters", "$validationRoot/materials" -Force | Out-Null
Set-Content -LiteralPath "$validationRoot/project.godot" -Encoding utf8 -Value "config_version=5`n[application]`nconfig/name=`"JAMO asset validation`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`""
Copy-Item -Path "$assetRoot/*.glb" -Destination "$validationRoot/art/monsters"
Copy-Item -LiteralPath "$assetRoot/asset_stats.json", "$assetRoot/verify_jamo.gd" -Destination "$validationRoot/art/monsters"
Copy-Item -LiteralPath "$repoRoot/materials/jamo_gold.tres", "$repoRoot/materials/jamo_special_fast.tres" -Destination "$validationRoot/materials"
& $Godot --headless --editor --path $validationRoot --import *> "$assetRoot/godot_isolated_import.log"
$importExit = $LASTEXITCODE
& $Godot --headless --path $validationRoot --script art/monsters/verify_jamo.gd *> "$assetRoot/godot_isolated_verify.log"
$verifyExit = $LASTEXITCODE
$errors = Select-String -Path "$assetRoot/godot_isolated_import.log", "$assetRoot/godot_isolated_verify.log" -Pattern 'ERROR:|SCRIPT ERROR|JAMO_ASSET_FAIL'
$receipt = [ordered]@{ godot = $Godot; validation_project = $validationRoot; import_exit = $importExit; verify_exit = $verifyExit; error_count = @($errors).Count }
$receipt | ConvertTo-Json | Set-Content -LiteralPath "$assetRoot/validation_receipt.json" -Encoding utf8
$receipt | ConvertTo-Json
if ($importExit -ne 0 -or $verifyExit -ne 0 -or @($errors).Count -ne 0) { exit 1 }
Write-Output 'ISOLATED_IMPORT_PASS'
