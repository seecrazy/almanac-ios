#!/bin/zsh
# 宜历 Almanac - 核心包构建与验证
# 用法: ./build.sh [test]
#   完整 Xcode 环境 → SwiftPM (swift build/swift test)
#   仅 Command Line Tools → swiftc 直编 + *Sanity 可执行验证
set -e
cd "$(dirname "$0")"
PKGS=(LunarKit HolidayData RecurrenceEngine)
MC=/tmp/swift-module-cache
mkdir -p "$MC"

if xcrun --find xctest >/dev/null 2>&1; then
  echo "==> 构建路径: SwiftPM (完整 Xcode)"
  for pkg in $PKGS; do
    echo "==> swift build  $pkg"
    (cd Packages/$pkg && swift build)
  done
  if [ "$1" = "test" ]; then
    for pkg in $PKGS; do
      echo "==> swift test   $pkg"
      (cd Packages/$pkg && swift test)
    done
  fi
  echo "✅ 全部通过 (SwiftPM)"
  exit 0
fi

echo "==> 构建路径: swiftc 直编 (Command Line Tools)"
for pkg in $PKGS; do
  echo "==> $pkg"
  (cd Packages/$pkg
   mkdir -p .bin
   swiftc -parse-as-library -emit-library -emit-module \
     -module-name $pkg -module-cache-path $MC \
     -emit-module-path .bin/$pkg.swiftmodule \
     -o .bin/lib$pkg.dylib Sources/$pkg/*.swift
   local -a sanity=(Sources/*Sanity/main.swift)
   if [ -f "$sanity[1]" ]; then
     swiftc -module-cache-path $MC -I .bin -L .bin -l$pkg \
       -Xlinker -rpath -Xlinker @executable_path \
       -o .bin/$pkg-sanity "$sanity[1]"
   fi
  )
done

if [ "$1" = "test" ]; then
  for pkg in $PKGS; do
    echo "==> 验证 $pkg"
    (cd Packages/$pkg && .bin/$pkg-sanity)
  done
fi
echo "✅ 全部通过"
