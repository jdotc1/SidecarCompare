# SidecarCompare icon

Created 2026-10-14. Native editable source: `SidecarCompare.icon`.

Two blue/cyan glass sidecar panels represent the explicitly selected inputs. Four metadata bars on each panel have corresponding shapes, with the third pair differing in length and alignment. No text, clinical image, equality claim, or validation badge is used. Original SVG artwork lives inside the document; native Icon Composer controls supply material, refraction, specular edges, and shadows.

The document was opened, edited, and saved with /Applications/Icon Composer.app using Design Generation 27. Dark and Mono were inspected in the native app. Default previews were rendered at 1024, 512 and 32 pixels; Dark and TintedLight at 512 pixels using the app's bundled ictool. Final renders are under Previews.

`xcrun actool` compiled successfully for macOS with deployment target 15.0, producing Compiled/Assets.car, SidecarCompare.icns, and IconInfo.plist. The log is compile.log. Compiled/asset-info.json records Aqua, DarkAqua and Tintable native stacks, each with four layers including the background and CompositeImagePresent=false.

The accepted compilation is staged by `script/build.sh`: Assets.car and SidecarCompare.icns are copied into Contents/Resources before the existing ad-hoc signing step. Packaging/Info.plist declares CFBundleIconName and CFBundleIconFile as SidecarCompare. Builds reuse the compiled icon; they do not rerun Icon Composer verification. After editing the .icon source, regenerate its compiled assets before packaging.

Icon validation remains separate from application runtime acceptance. Existing source test receipts are reused.

References:
- https://developer.apple.com/icon-composer/
- https://developer.apple.com/design/human-interface-guidelines/app-icons
- https://developer.apple.com/design/human-interface-guidelines/icons
- https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer
- https://developer.apple.com/documentation/xcode/configuring-your-app-icon
- https://bjango.com/articles/macappiconworkflow/
- https://github.com/bjango/Bjango-Templates
