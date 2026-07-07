$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $repoRoot '.github/workflows/build-apk.yml'
$projectPath = Join-Path $repoRoot 'SMAPIGameLoader/SMAPIGameLoader.csproj'

$workflow = Get-Content -LiteralPath $workflowPath -Raw
[xml]$project = Get-Content -LiteralPath $projectPath -Raw

function Assert-Contains {
    param(
        [string] $Content,
        [string] $Expected,
        [string] $Message
    )

    if (-not $Content.Contains($Expected)) {
        throw $Message
    }
}

Assert-Contains `
    -Content $workflow `
    -Expected '$DEPENDENCIES_ROOT/src/DependenciesDll/MonoGame.Framework.dll' `
    -Message 'Workflow dependency verification must use DEPENDENCIES_ROOT for MonoGame.Framework.dll.'

Assert-Contains `
    -Content $workflow `
    -Expected '/p:SMAPIAndroidDependenciesRoot="$DEPENDENCIES_ROOT"' `
    -Message 'Workflow must pass SMAPIAndroidDependenciesRoot to MSBuild.'

Assert-Contains `
    -Content $workflow `
    -Expected 'dotnet restore "$PROJECT_PATH" /p:SMAPIAndroidDependenciesRoot="$DEPENDENCIES_ROOT"' `
    -Message 'Workflow restore step must pass SMAPIAndroidDependenciesRoot to MSBuild.'

$property = $project.Project.PropertyGroup.SMAPIAndroidDependenciesRoot | Select-Object -First 1
if (-not $property) {
    throw 'Project must define SMAPIAndroidDependenciesRoot with a local-build default.'
}

$expectedReferences = @{
    'MonoGame.Framework' = '$(SMAPIAndroidDependenciesRoot)/src/DependenciesDll/MonoGame.Framework.dll'
    'StardewValley' = '$(SMAPIAndroidDependenciesRoot)/src/DependenciesDll/StardewValley.dll'
    'StardewValley.GameData' = '$(SMAPIAndroidDependenciesRoot)/src/DependenciesDll/StardewValley.GameData.dll'
}

foreach ($reference in $project.Project.ItemGroup.Reference) {
    $include = [string]$reference.Include
    if ($expectedReferences.ContainsKey($include)) {
        $actualHintPath = [string]$reference.HintPath
        if ($actualHintPath -ne $expectedReferences[$include]) {
            throw "Reference '$include' must use SMAPIAndroidDependenciesRoot. Actual HintPath: $actualHintPath"
        }
    }
}

Write-Host 'CI dependency path configuration is valid.'
