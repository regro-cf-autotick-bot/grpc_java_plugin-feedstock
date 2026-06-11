#!/bin/bash

set -euxo pipefail

# Prepare systemlibs defintions
mkdir -p third_party/systemlibs
cp -ap "${PREFIX}/share/bazel/systemlibs/absl" third_party/systemlibs/
cp -ap "${PREFIX}/share/bazel/systemlibs/protobuf" third_party/systemlibs/
cp -ap "${PREFIX}/share/bazel/protobuf/bazel" third_party/systemlibs/protobuf/


export ABSEIL_VERSION="$(grep '"version"' ${PREFIX}/conda-meta/libabseil-*.json | awk -F'"' '{print $(NF-1)}' | head -1)"
export PROTOC_VERSION="$(grep '"version"' ${PREFIX}/conda-meta/libprotobuf-*.json | awk -F'"' '{print $(NF-1)}' | head -1 | sed -E 's/^[0-9]+\.([0-9]+\.[0-9]+)$/\1/')"
sed -i "s:ABSEIL_VERSION:${ABSEIL_VERSION}:" \
    MODULE.bazel \
    third_party/systemlibs/protobuf/MODULE.bazel
sed -i "s:PROTOC_VERSION:${PROTOC_VERSION}:" \
    MODULE.bazel

if [[ "${target_platform}" == osx-* ]]; then
    # See https://conda-forge.org/docs/maintainer/knowledge_base.html#newer-c-features-with-old-sdk
    export CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY"
fi

source gen-bazel-toolchain

pushd compiler
chmod +x ../bazel
../bazel build \
    --logging=6 \
    --subcommands \
    --verbose_failures \
    --crosstool_top=//bazel_toolchain:toolchain \
    --define=PROTOC_PREFIX=${BUILD_PREFIX} \
    --define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include \
    --platforms=//bazel_toolchain:target_platform \
    --host_platform=//bazel_toolchain:build_platform \
    --extra_toolchains=//bazel_toolchain:cc_cf_toolchain \
    --extra_toolchains=//bazel_toolchain:cc_cf_host_toolchain \
    --cpu ${TARGET_CPU} \
    grpc_java_plugin
popd
mkdir -p $PREFIX/bin
cp bazel-bin/compiler/grpc_java_plugin $PREFIX/bin
