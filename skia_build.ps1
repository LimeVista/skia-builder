$cur_dir = $PSScriptRoot

$ver = 'm85'            # skia 版本
$full_mode = $true     # 是否编译完整版本，带 skia shaper 和 pdf 支持
$enable_pdf = $(If ($full_mode) { "true" } Else { "false" })
$ver_name = "1.$($ver.Substring(1)).1"

$depot_dir = "${cur_dir}/depot_tools"
$skia_args_1 = 'is_official_build=true is_debug=false skia_use_vulkan=true ndk_api=26 '
$skia_args_2 = 'skia_use_system_libjpeg_turbo=false skia_use_system_libpng=false skia_use_system_libwebp=false skia_use_system_zlib=false '
$skia_args_3 = 'skia_use_expat=true skia_use_system_expat=false skia_use_x11=false skia_use_dng_sdk=false skia_use_harfbuzz=true skia_use_system_harfbuzz=false '
$skia_args_4 = 'skia_use_system_freetype2=false skia_enable_fontmgr_android=true skia_gl_standard=\"gles\" '
$skia_args_5 = 'skia_use_icu=true skia_use_system_icu=false skia_use_wuffs=true '

$skia_args_pdf = "skia_use_sfntly=$enable_pdf skia_pdf_subset_harfbuzz=$enable_pdf skia_enable_pdf=$enable_pdf "
$skia_args_ndk = "ndk=\`"$($args[0])\`""
$skia_args_ext = 'skia_enable_skshaper=true skia_enable_skparagraph=true' 

$skia_args = "${skia_args_1}${skia_args_2}${skia_args_3}${skia_args_4}${skia_args_5}${skia_args_pdf} ${skia_args_ndk}"
$skia_args = $(If ($full_mode) { "${skia_args} ${skia_args_ext}" } Else { $skia_args })

Write-Output "检查环境..."

If (-not (Test-Path -Path $depot_dir)) {
    Write-Output "下载编译工具..."
    git clone 'https://chromium.googlesource.com/chromium/tools/depot_tools.git'
}

If (-not (Test-Path -Path "${cur_dir}/skia")) {
    Write-Output "下载 Skia ..."
    git clone -b chrome/$ver 'https://skia.googlesource.com/skia.git'
}

$env:Path += ";${cur_dir}/depot_tools"

Set-Location "${cur_dir}/skia"

Write-Output "检查并同步依赖..."
python tools/git-sync-deps

Write-Output "准备构建arm64位组件..."
gn gen out/arm64-v8a --args="${skia_args} target_cpu=\`"arm64\`""

Write-Output "开始构建arm64位组件"
ninja -C out/arm64-v8a

If ($LASTEXITCODE -ne 0) { Throw "Build Skia Failed." }

Write-Output "准备构建x86_64位组件..."
gn gen out/x86_64 --args="${skia_args} target_cpu=\`"x64\`""

Write-Output "开始构建x86_64位组件"
ninja -C out/x86_64

If ($LASTEXITCODE -ne 0) { Throw "Build Skia Failed." }

# 创建文件夹参数和库名
$out_dir = "${cur_dir}/skia/out/"
$output_dir = "${cur_dir}/skia-$ver_name"
$output_lib = "${output_dir}/prefab/modules/skia/libs"
$output_header = "${output_dir}/prefab/modules/skia/include"
$lib_skia = "libskia.a"

Write-Output "开始整合库..."

Set-Location $cur_dir

If (-not (Test-Path -Path $output_dir)) {
    Copy-Item -Path "$cur_dir/prefab/skia-VERSION" -Destination "$output_dir" -Recurse
    $json_path = "$output_dir/prefab/prefab.json"
    (Get-Content $json_path).replace("VERSION", $ver_name) | Set-Content $json_path
}

If (-not (Test-Path -Path $output_header)) {
    Copy-Item -Force -Recurse "${cur_dir}/skia/include" "$output_header/include"
    $image_priv = "$output_header/include/core/SkImagePriv.h"
    Copy-Item "${cur_dir}/skia/src/core/SkImagePriv.h" $image_priv
}

$abis = @("x86_64", "arm64-v8a")

Foreach ($abi in $abis) {
    Write-Output "Copying the ${abi} library"
    $destination = "$output_lib/android.$abi"
    Copy-Item -Force "${out_dir}$abi/$lib_skia" $destination
    If ($LASTEXITCODE -ne 0) { Throw "Copy Library Failed." }
}

Write-Output "构建AAR..."

# Compress-Archive -Path $output_dir/* -DestinationPath skia.zip -Force
# Move-Item "skia.zip" "skia-${ver_name}.aar" -Force
jar cfM skia-${ver_name}.aar -C $output_dir ./

Write-Output "构建完成。"