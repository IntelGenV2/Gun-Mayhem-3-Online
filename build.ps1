param(
    [string]$AirSdk = (Join-Path $PSScriptRoot 'vendor\air-sdk'),
    [string]$Ffdec = (Join-Path $PSScriptRoot 'vendor\ffdec\ffdec.jar'),
    [string]$JavaHome = 'C:\Program Files\Java\jdk-21.0.12',
    [switch]$Package,
    [switch]$DebugBuild
)
$ErrorActionPreference = 'Stop'
$project = $PSScriptRoot
$javaExe = Join-Path $JavaHome 'bin\java.exe'
$javacExe = Join-Path $JavaHome 'bin\javac.exe'
if (!(Test-Path $javaExe)) { $javaExe = (Get-Command java -ErrorAction Stop).Source; $javacExe = (Get-Command javac -ErrorAction Stop).Source }
if (!(Test-Path (Join-Path $AirSdk 'lib\mxmlc-cli.jar'))) { throw 'AIR SDK missing. Install the Windows ActionScript AIR SDK from https://airsdk.harman.com/download, then pass -AirSdk <folder>.' }
$AirSdk = (Resolve-Path $AirSdk).Path
if (!(Test-Path $ffdec)) { throw 'JPEXS FFDec is required in vendor\ffdec (build time only).' }
$build = Join-Path $project 'build'
New-Item -ItemType Directory -Force -Path $build | Out-Null
& $javacExe -cp $ffdec -d $build (Join-Path $project 'tools\PatchGame.java')
if ($LASTEXITCODE -ne 0) { throw 'SWF patcher compilation failed.' }
& $javaExe -cp "$build;$ffdec" PatchGame $project
if ($LASTEXITCODE -ne 0) { throw 'Flash patch failed.' }
& $javaExe "-Dflexlib=$AirSdk\frameworks" -jar "$AirSdk\lib\mxmlc-cli.jar" '+configname=air' "-source-path=$project\src" "-output=$build\Main.swf" "-debug=$($DebugBuild.IsPresent.ToString().ToLowerInvariant())" "$project\src\Main.as"
if ($LASTEXITCODE -ne 0) { throw 'ActionScript desktop shell compilation failed.' }
Copy-Item -LiteralPath (Join-Path $project 'application.xml') -Destination $build -Force
New-Item -ItemType Directory -Force -Path "$build\audio" | Out-Null
Copy-Item -LiteralPath "$project\assets\gm1-menu.mp3" -Destination "$build\audio\gm1-menu.mp3" -Force
Copy-Item -LiteralPath "$project\assets\gm1-setup.mp3" -Destination "$build\audio\gm1-setup.mp3" -Force
& dotnet publish "$project\photon\PhotonBridge.csproj" -c Release -r win-x64 --self-contained true -o "$build\photon" -p:PublishSingleFile=true
if ($LASTEXITCODE -ne 0) { throw 'Photon companion compilation failed.' }
if ($Package) {
    $certificate = Join-Path $build 'development.p12'
    if (!(Test-Path $certificate)) {
        & $javaExe -jar "$AirSdk\lib\adt.jar" -certificate -cn 'Gun Mayhem 3 Online Development' 2048-RSA $certificate gm3-development
        if ($LASTEXITCODE -ne 0) { throw 'Development signing certificate generation failed.' }
    }
    # AIR bundle includes the real Flash runtime. The EXE needs its adjacent files.
    $destination = Join-Path $project 'dist\Gun Mayhem 3 Online'
    if (Test-Path $destination) {
        $resolved = (Resolve-Path $destination).Path
        $expected = [IO.Path]::GetFullPath((Join-Path $project 'dist\Gun Mayhem 3 Online'))
        if ($resolved -ne $expected -or (Get-Item -LiteralPath $resolved).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Unexpected package directory.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    & $javaExe -jar "$AirSdk\lib\adt.jar" -package -storetype pkcs12 -keystore $certificate -storepass gm3-development -tsa none -target bundle -arch x86 $destination "$build\application.xml" -C $build Main.swf game.swf guest.swf audio photon
    if ($LASTEXITCODE -ne 0) { throw 'Windows executable packaging failed.' }
    Copy-Item -LiteralPath "$project\README.md" -Destination $destination
    Copy-Item -LiteralPath "$project\assets\CREDITS.md" -Destination $destination
    Copy-Item -LiteralPath "$project\vendor\photon\license.txt" -Destination "$destination\photon\Photon-license.txt"
    Compress-Archive -LiteralPath $destination -DestinationPath (Join-Path $project 'dist\Gun Mayhem 3 Online.zip') -Force
    Write-Host "Play: $destination\Gun Mayhem 3 Online.exe"
} else { Write-Host "Built Flash files in $build. Use -Package to build the portable Windows EXE." }
