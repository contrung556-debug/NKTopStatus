# NK Top Status

Mini status/progress overlay for AutoTouch on a rootless jailbreak.

## What it does

- Injects only into SpringBoard.
- Shows a small blurred pill immediately below the status bar / notch.
- Does not block touches.
- Reads status from:
  `/var/mobile/Library/Preferences/com.nk.topstatus.status`
- Auto-hides after 15 seconds without a new update.
- Lua can hide it immediately by writing `HIDE`.

## Package target

- Rootless
- iOS 15+
- `arm64 arm64e`
- SpringBoard tweak

Theos rootless builds place packages under `/var/jb` and use
`iphoneos-arm64` packaging.

## Build without a computer: GitHub Actions

1. Create a new GitHub repository.
2. Upload the contents of this folder to the repository.
3. Open the repo's **Actions** tab.
4. Select **Build NK Top Status**.
5. Tap **Run workflow**.
6. When the run finishes, open it and download the
   `NKTopStatus-rootless` artifact.
7. Unzip the artifact on the iPhone.
8. Install the `.deb` with Sileo / Zebra / Filza.
9. Respring SpringBoard.
10. Run `autotouch/top_status.lua`.

The workflow uses a macOS runner because SpringBoard is a system binary
and arm64e builds need the macOS/Xcode toolchain on current Theos.

## AutoTouch integration

Copy these functions from `autotouch/top_status.lua` into the main script:

```lua
setTopStatus(20, "Đang lấy tên")
setTopStatus(45, "Đang nhập Họ")
setTopStatus(70, "Đang nhập Tên")
setTopStatus(100, "Hoàn tất")
hideTopStatus()
```

Example with your Supabase flow:

```lua
setTopStatus(10, "Đang lấy tên từ Supabase")

local result = getAndMarkUnusedName()

setTopStatus(35, "Đã lấy " .. tostring(result.ho_ten))

setTopStatus(55, "Đang nhập Họ")
tapField(HO_FIELD_X, HO_FIELD_Y)
typeHumanText(result.ho)

setTopStatus(80, "Đang nhập Tên")
tapField(TEN_FIELD_X, TEN_FIELD_Y)
typeHumanText(result.ten)

setTopStatus(100, "Hoàn tất")
```

## Position

In `Tweak.xm`, the vertical position is controlled here:

```objc
CGFloat y = [self topInset] + 4.0;
```

- `+ 4.0` = very close below the status bar.
- Increase it to move the pill lower.
- Setting an absolute `y` near `4.0` would cover the status bar and is not
  recommended.

## Troubleshooting

### Overlay does not appear
- Confirm the `.deb` is installed.
- Respring.
- Run `autotouch/top_status.lua`.
- Check that this file is created:
  `/var/mobile/Library/Preferences/com.nk.topstatus.status`

### Lua says it cannot write the status file
The AutoTouch process may not have permission to write that shared path on
a particular jailbreak. If that happens, the IPC method can be switched to
a small helper command or a Darwin notification bridge.

### SpringBoard crash
Remove the package in Sileo/Zebra and respring. The tweak only injects into
SpringBoard, so test the first build before integrating it into long scripts.
