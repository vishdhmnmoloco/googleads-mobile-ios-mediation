#!/bin/bash
# Combine iOS Device and Simulator libraries for the various architectures
# into a single dynamic framework.

# Remove build directories if exist.
if [ -d "${BUILT_PRODUCTS_DIR}" ]; then
  rm -rf "${BUILT_PRODUCTS_DIR}"
fi

# Remove framework if exists.
if [ -d "${OUTPUT_FOLDER}/${FRAMEWORK_NAME}.xcframework" ]; then
  rm -rf "${OUTPUT_FOLDER}/${FRAMEWORK_NAME}.xcframework"
fi

# Public headers directory.
export PUBLIC_HEADERS_FOLDER_PATH="${SRCROOT}/Public/Headers"

# Create output directory.
mkdir -p "${OUTPUT_FOLDER}"

# Export framework at path.
export FRAMEWORK_LOCATION="${BUILT_PRODUCTS_DIR}/${FRAMEWORK_NAME}.xcframework"

createFramework() {
  TEMP_FRAMEWORK_LOCATION="${BUILD_DIR}/${CONFIGURATION}-$1/${FRAMEWORK_NAME}.framework"

  # Create the path to the framework headers and copy the public headers inside.
  mkdir -p "${TEMP_FRAMEWORK_LOCATION}/Headers"
  ditto "${PUBLIC_HEADERS_FOLDER_PATH}" "${TEMP_FRAMEWORK_LOCATION}/Headers"

  # Build the static library for the specified sdk and architecture.
  xcodebuild -target Adapter \
  -configuration "${CONFIGURATION}" \
  -sdk "${1}" \
  ARCHS="${2}" \
  BUILD_DIR="${BUILD_DIR}" \
  BUILD_ROOT="${BUILD_ROOT}" \
  OBJROOT="${OBJROOT}/${1}" \
  ONLY_ACTIVE_ARCH=NO \
  SYMROOT="${SYMROOT}" \
  "${ACTION}"

  # Create framework using lipo.
  lipo -create "${BUILD_DIR}/${CONFIGURATION}-$1/${LIB_NAME}.a" -output "${TEMP_FRAMEWORK_LOCATION}/${FRAMEWORK_NAME}"

  # Create Modules directory and copy the module map inside.
  mkdir -p "${TEMP_FRAMEWORK_LOCATION}/Modules"
  /bin/cp -a "${MODULE_MAP_PATH}/module.modulemap" "${TEMP_FRAMEWORK_LOCATION}/Modules/module.modulemap"

  # Static library does not automatically generate an Info.plist file. Create
  # a fake framework to generate the Info.plist and then copy it into the
  # static library. Info.plist is required to allow embedding static frameworks
  # in Xcode 15.
  TEMP_INFO_PLIST_FRAMEWORK_LOCATION="${BUILD_DIR}/framework"
  xcodebuild -target NendAdapter \
  -configuration "${CONFIGURATION}" \
  -sdk "${1}" \
  ARCHS="${2}" \
  BUILD_DIR="${TEMP_INFO_PLIST_FRAMEWORK_LOCATION}" \
  "build"

  install -m 0444 "${TEMP_INFO_PLIST_FRAMEWORK_LOCATION}/${CONFIGURATION}-$1/${FRAMEWORK_NAME}.framework/Info.plist" "${TEMP_FRAMEWORK_LOCATION}/Info.plist"
}

createFramework "iphoneos" "arm64"
createFramework "iphonesimulator" "arm64 x86_64"

# Create dynamic framework using the frameworks generated above.
xcodebuild -create-xcframework \
-framework "${BUILD_DIR}/${CONFIGURATION}-iphoneos/${FRAMEWORK_NAME}.framework" \
-framework "${BUILD_DIR}/${CONFIGURATION}-iphonesimulator/${FRAMEWORK_NAME}.framework" \
-output "${FRAMEWORK_LOCATION}/${FRAMEWORK_NAME}.xcframework"

# Copy the finalized xcframework to the Library directory.
ditto "${FRAMEWORK_LOCATION}" "${OUTPUT_FOLDER}"
