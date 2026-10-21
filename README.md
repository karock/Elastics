# Elastics

Monitor your AWS EC2 instances from your Mac menubar.

This is an unofficial, updated fork of [Elastics](https://github.com/tundrabot/Elastics)
by Dmitri Goutnik (Tundra Bot), which is no longer maintained. Questions and issues
about this fork belong [here](https://github.com/karock/Elastics/issues), not with
the original author.

Changes from Elastics 1.6:

- Native Apple Silicon (universal) build for macOS 13 and later; builds with
  current Xcode without CocoaPods; Mac App Store receipt validation removed
- AWS Signature Version 4, current EC2 API version, current region list
- Instance details: lifecycle, state reason, private IP, storage (EBS volumes and
  instance store)
- Instance search at the top of the menu (focused when the menu opens)
- Dark Mode fixes and modern menu bar icon

## Building

```
xcodebuild -project Elastics.xcodeproj -target Elastics -configuration Release \
  SYMROOT="$PWD/build" OBJROOT="$PWD/build/obj"
```

The app is built to `build/Release/Elastics.app` and signed to run locally.

## License

MIT, see [LICENSE](LICENSE).
