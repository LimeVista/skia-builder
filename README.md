# Skia(Vulkan Version) Builder For Android
用于构建 `Vulkan` 版本的 `skia`

## 使用要求
* Android SDK API >= 26
* NDK Ver >= 21
* Android Studio 4.1+

## 使用方式
* 添加源
```groovy
allprojects {
  repositories {
    // ...
    maven { url "https://raw.githubusercontent.com/LimeVista/skia-builder/master/prebuilt" }
  }
}
```
* 引入
```groovy
dependencies {
    implementation 'me.limeice.skia:skia:1.90.1'
}
```
* 启用 `prefab`
```groovy
android {
    buildFeatures {
        prefab true
    }
}
```
* 引入 `CMakeLists.txt`
```cmake
find_package (skia REQUIRED CONFIG)

target_link_libraries(yourLib 
    skia::skia
    vulkan
    GLESv3
    EGL
    jnigraphics
    android
    ${log-lib}
    log)
```

## 构建
详见 `skia_build.ps1` 暂时仅提供 `Windows` 构建脚本
