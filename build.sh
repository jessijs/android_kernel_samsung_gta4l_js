#!/bin/bash

# Ensure the script exits on error
set -e

TOOLCHAIN_PATH=$HOME/tc/bin
GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)

if [ ! -d $TOOLCHAIN_PATH ]; then
    echo "TOOLCHAIN_PATH [$TOOLCHAIN_PATH] does not exist."
    echo "Please ensure the toolchain is there, or change TOOLCHAIN_PATH in the script to your toolchain path."
    exit 1
fi

echo "TOOLCHAIN_PATH: [$TOOLCHAIN_PATH]"
export PATH="$TOOLCHAIN_PATH:$PATH"

MAKE_ARGS="ARCH=arm64 O=out CC=clang LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip"

# Check clang is existing.
echo "[clang --version]:"
clang --version

# Export variables
export KBUILD_BUILD_USER="jessijs"
export KBUILD_BUILD_HOST="bloodreaper"
export KBUILD_LAST_COMMIT=${GIT_COMMIT_ID}

echo "Cleaning..."
rm -rf out/
rm -rf error.log

echo "Cloning AnyKernel3 for packing kernel..."
if [ -d "anykernel/.git" ]; then
    echo "AnyKernel3 already cloned. Skipping."
else
    rm -rf anykernel  # ensure clean state
    git clone https://github.com/CuriousNom/AnyKernel3.git -b gta4l --single-branch --depth=1 anykernel
fi

    # ------------- Building for gta4l ---------------
    echo "Clearing [out/] and building for gta4l....."

    # 1. Configura as opções do kernel
    make $MAKE_ARGS gta4l_defconfig

    # --- ROTA 3: BUSCA E DESTRUIÇÃO (O SPOOF DEFINITIVO) ---
    echo "Aplicando injeção agressiva no código fonte do kernel..."
    
    # Em vez de brigar com os arquivos temporários, nós reescrevemos o código em C 
    # que manda a informação para o Android (o cérebro do uname), substituindo 
    # a macro UTS_RELEASE pela nossa string fixa do GKI (6.12.38).
    
    sed -i 's/UTS_RELEASE/"6.12.38-🩸LK_LittleKernel+"/g' init/version.c
    
    # --------------------------------------------------------

    # 2. Continua a compilação pesada
    make $MAKE_ARGS -j$(nproc --all) 2> >(tee -a error.log >&2)

    if [ -f "out/arch/arm64/boot/Image" ]; then
        echo "The file [out/arch/arm64/boot/Image] exists. Build successfully."
    else
        echo "The file [out/arch/arm64/boot/Image] does not exist. Seems build failed."
        exit 1
    fi

    rm -rf anykernel/kernels/
    mkdir -p anykernel/kernels/

    # --- CORREÇÃO: Copiando os arquivos vitais do kernel para a pasta do AnyKernel ---
    echo "Copying compiled kernel to AnyKernel3 directory..."
    cp out/arch/arm64/boot/Image anykernel/ 2>/dev/null || true
    cp out/arch/arm64/boot/Image.gz anykernel/ 2>/dev/null || true
    cp out/arch/arm64/boot/Image.gz-dtb anykernel/ 2>/dev/null || true
    cp out/arch/arm64/boot/dtbo.img anykernel/ 2>/dev/null || true
    # -----------------------------------------------------------------------------------

    cd anykernel

    # --- NOVO: Personalizando o nome no AnyKernel ---
    echo "Personalizando o nome do Kernel..."
    sed -i 's/kernel.string=.*/kernel.string=🩸 LK_LittleKernel (Android 16 GKI spoof) by jessijs/g' anykernel.sh
    # ------------------------------------------------

    ZIP_FILENAME=LK_LittleKernel_GKI16_gta4l_$(date +'%Y%m%d_%H%M%S')_${GIT_COMMIT_ID}.zip
    zip -r9 $ZIP_FILENAME ./* -x .git .gitignore out/ ./*.zip
    mv $ZIP_FILENAME ../
    cd ..

    echo "Build for gta4l finished."

echo "Done. The flashable zip is: [./$ZIP_FILENAME]"
