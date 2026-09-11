param(
    [string]$Godot = 'C:/Users/sjkim/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$assetRoot = $PSScriptRoot
$validationRoot = Join-Path ([IO.Path]::GetTempPath()) ('JAMO_ASSET04_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$validationRoot/art/arena" -Force | Out-Null
Set-Content -LiteralPath "$validationRoot/project.godot" -Encoding utf8 -Value "config_version=5`n[application]`nconfig/name=`"JAMO desk asset validation`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`""
Copy-Item -Path "$assetRoot/*.glb" -Destination "$validationRoot/art/arena"
Copy-Item -LiteralPath "$assetRoot/asset_stats.json", "$assetRoot/verify_arena.gd" -Destination "$validationRoot/art/arena"
& $Godot --version | Set-Content -LiteralPath "$assetRoot/godot_version.log"
& $Godot --headless --editor --path $validationRoot --import *> "$assetRoot/godot_isolated_import.log"
$importExit = $LASTEXITCODE
& $Godot --headless --path $validationRoot --script art/arena/verify_arena.gd *> "$assetRoot/godot_isolated_verify.log"
$verifyExit = $LASTEXITCODE
$errors = Select-String -Path "$assetRoot/godot_isolated_import.log", "$assetRoot/godot_isolated_verify.log" -Pattern 'ERROR:|SCRIPT ERROR|ARENA_FAIL'
$receipt = [ordered]@{ godot = $Godot; validation_project = $validationRoot; import_exit = $importExit; verify_exit = $verifyExit; error_count = @($errors).Count }
$receipt | ConvertTo-Json | Set-Content -LiteralPath "$assetRoot/validation_receipt.json" -Encoding utf8
$receipt | ConvertTo-Json
if ($importExit -ne 0 -or $verifyExit -ne 0 -or @($errors).Count -ne 0) { exit 1 }
Write-Output 'ISOLATED_IMPORT_PASS'
