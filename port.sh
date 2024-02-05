#!/bin/bash

# hyperOS_port project

# For A-only and V/A-B (not tested) Devices

# Based on Android 13

# Test Base ROM: A-only Mi 10/PRO/Ultra (MIUI 14 Latset stockrom)

# Test Port ROM: Mi 14/Pro OS1.0.9-1.0.25 Mi 13/PRO OS1.0 23.11.09-23.11.10 DEV


build_user="Bruce Teng"
build_host=$(hostname)

# 底包和移植包为外部参数传入
baserom="$1"
portrom="$2"

work_dir=$(pwd)
tools_dir=${work_dir}/bin/$(uname)/$(uname -m)
py_scripts=${work_dir}/bin/py_scripts
export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH
# 定义颜色输出函数
# Define color output function
error() {
    if [ "$#" -eq 2 ]; then
        
        if [[ "$LANG" == zh_CN* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;31m"$1"\033[0m"
        elif [[ "$LANG" == en* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;31m"$2"\033[0m"
        else
            echo -e \[$(date +%m%d-%T)\] "\033[1;31m"$2"\033[0m"
        fi
    elif [ "$#" -eq 1 ]; then
        echo -e \[$(date +%m%d-%T)\] "\033[1;31m"$1"\033[0m"
    else
        echo "Usage: error <Chinese> <English>"
    fi
}

yellow() {
    if [ "$#" -eq 2 ]; then
        
        if [[ "$LANG" == zh_CN* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;33m"$1"\033[0m"
        elif [[ "$LANG" == en* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;33m"$2"\033[0m"
        else
            echo -e \[$(date +%m%d-%T)\] "\033[1;33m"$2"\033[0m"
        fi
    elif [ "$#" -eq 1 ]; then
        echo -e \[$(date +%m%d-%T)\] "\033[1;33m"$1"\033[0m"
    else
        echo "Usage: yellow <Chinese> <English>"
    fi
}

blue() {
    if [ "$#" -eq 2 ]; then
        
        if [[ "$LANG" == zh_CN* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;34m"$1"\033[0m"
        elif [[ "$LANG" == en* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;34m"$2"\033[0m"
        else
            echo -e \[$(date +%m%d-%T)\] "\033[1;34m"$2"\033[0m"
        fi
    elif [ "$#" -eq 1 ]; then
        echo -e \[$(date +%m%d-%T)\] "\033[1;34m"$1"\033[0m"
    else
        echo "Usage: blue <Chinese> <English>"
    fi
}

green() {
    if [ "$#" -eq 2 ]; then
        if [[ "$LANG" == zh_CN* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;32m"$1"\033[0m"
        elif [[ "$LANG" == en* ]]; then
            echo -e \[$(date +%m%d-%T)\] "\033[1;32m"$2"\033[0m"
        else
            echo -e \[$(date +%m%d-%T)\] "\033[1;32m"$2"\033[0m"
        fi
    elif [ "$#" -eq 1 ]; then
        echo -e \[$(date +%m%d-%T)\] "\033[1;32m"$1"\033[0m"
    else
        echo "Usage: green <Chinese> <English>"
    fi
}
if [ $(uname) != 'Windows_NT' ]; then
shopt -s expand_aliases
fi
if [[ "$OSTYPE" == "darwin"* ]]; then
    yellow "检测到Mac，设置alias" "macOS detected,setting alias"
    alias sed=gsed
    alias tr=gtr
    alias grep=ggrep
    alias du=gdu
    alias date=gdate
    #alias find=gfind
fi
if [ $(uname) = 'Windows_NT' ]; then
  yellow "检测到Windows，设置alias" "Windows detected,setting alias"
  alias aria2c=${tools_dir}/aria2c
  alias 7z=${tools_dir}/7z
  alias zipalign=${tools_dir}/zipalign
  alias python3=python
  alias xmlstarlet=${tools_dir}/xml
  alias sudo=
  alias shopt=echo
fi
#检查必需命令是否缺少
#Check for the existence of the requirements command, proceed if it exists, or abort otherwise.
abort() {
    error "--> Missing $1 abort! please run ./setup.sh first (sudo is required on Linux system)"
    error "--> 命令 $1 缺失!请重新运行setup.sh (Linux系统sudo ./setup.sh)"
    exit 1
}

check() {
    for b in "$@"; do
        command -v "$b" || abort "$b"
    done
}

check aria2c 7z java zipalign python3 zstd bc xmlstarlet

# 向 apk 或 jar 文件中替换 smali 代码，不支持资源补丁
# $1: 目标 apk/jar 文件
# $2: 目标 smali 文件(支持带相对路径的smali文件)
# $3: 被替换值
# $4: 替换值
patch_smali() {
    targetfilefullpath=$(find build/portrom/images -type f -name $1)
    targetfilename=$(basename $targetfilefullpath)
    if [ -f $targetfilefullpath ];then
        yellow "正在修改 $targetfilename" "Modifying $targetfilename"
        foldername=${targetfilename%.*}
        rm -rf tmp/$foldername/
        mkdir -p tmp/$foldername/
        cp -rf $targetfilefullpath tmp/$foldername/
        7z x -y tmp/$foldername/$targetfilename *.dex -otmp/$foldername
        for dexfile in tmp/$foldername/*.dex;do
            smalifname=${dexfile%.*}
            smalifname=$(echo $smalifname | cut -d "/" -f 3)
            java -jar bin/apktool/baksmali.jar d --api ${port_android_sdk} ${dexfile} -o tmp/$foldername/$smalifname || error " Baksmaling 失败" "Baksmaling failed"
        done
        if [[ "$2" == *"/"* ]];then
            targetsmali=$(find tmp/$foldername/*/$(dirname $2) -type f -name $(basename $2))
        else
            targetsmali=$(find tmp/$foldername -type f -name $2)
        fi
        if [ -f $targetsmali ];then
            smalidir=$(echo $targetsmali |cut -d "/" -f 3)
            yellow "I: 开始patch目标 ${smalidir}" "Target ${smalidir} Found"
            search_pattern=$3
            repalcement_pattern=$4
            if [[ "$5" == 'regex' ]];then
                 sed -i "/${search_pattern}/c\\${repalcement_pattern}" $targetsmali
            else
            sed -i "s/$search_pattern/$repalcement_pattern/g" $targetsmali
            fi
            java -jar -Xms512m -Xmx2048m bin/apktool/smali.jar a --api ${port_android_sdk} tmp/$foldername/${smalidir} -o tmp/$foldername/${smalidir}.dex  || error " Smaling 失败" "Smaling failed"
            cd tmp/$foldername/  || exit
            7z a -y -mx0 -tzip $targetfilename ${smalidir}.dex   || error "修改$targetfilename失败" "Failed to modify $targetfilename"
            cd ../.. || exit
            yellow "修补$targetfilename 完成" "Fix $targetfilename completed"
            if [[ $targetfilename == *.apk ]]; then
                yellow "检测到apk，进行zipalign处理。。" "APK file detected, initiating ZipAlign process..."
                rm -rf ${targetfilefullpath}

                # Align moddified APKs, to avoid error "Targeting R+ (version 30 and above) requires the resources.arsc of installed APKs to be stored uncompressed and aligned on a 4-byte boundary" 
                zipalign -p -f -v 4 tmp/$foldername/$targetfilename ${targetfilefullpath}  || error "zipalign错误，请检查原因。" "zipalign error,please check for any issues"
                yellow "apk zipalign处理完成" "APK ZipAlign process completed."
                yellow "复制APK到目标位置：${targetfilefullpath}" "Copying APK to target ${targetfilefullpath}"
            else
                yellow "复制修改文件到目标位置：${targetfilefullpath}" "Copying file to target ${targetfilefullpath}"
                cp -rf tmp/$foldername/$targetfilename ${targetfilefullpath}
            fi
        fi
    fi

}

unlock_device_feature() {
    feature=$2
    if [[ ! -z "$1" ]]; then
        comment=$1
    else
        comment="Whether enable $feature feature"
    fi

    if ! grep -q "$feature" build/portrom/images/product/etc/device_features/${base_rom_code}.xml;then
        sed -i "/<features>/a\\\t<!-- ${comment} -->\n\t<bool name=\"${feature}\">true</bool> " build/portrom/images/product/etc/device_features/${base_rom_code}.xml
    else
        sed -i "s/<bool name=\"$feature\">.*<\/bool>/<bool name=\"$feature\">true<\/bool>/" build/portrom/images/product/etc/device_features/${base_rom_code}.xml
    fi
}

#check if a prperty is avaialble
is_property_exists () {
    if [ $(grep -c "$1" "$2") -ne 0 ]; then
        return 0
    else
        return 1
    fi
}

# 移植的分区，可在 bin/port_config 中更改
port_partition=$(grep "partition_to_port" bin/port_config |cut -d '=' -f 2)
#super_list=$(grep "super_list" bin/port_config |cut -d '=' -f 2)
repackext4=$(grep "repack_with_ext4" bin/port_config |cut -d '=' -f 2)
brightness_fix_method=$(grep "brightness_fix_method" bin/port_config |cut -d '=' -f 2)

compatible_matrix_matches_enabled=$(grep "compatible_matrix_matches_check" bin/port_config | cut -d '=' -f 2)

if [[ "${repackext4}" == "true" ]]; then
    pack_type=EXT
else
    pack_type=EROFS
fi


# 检查为本地包还是链接
if [ ! -f "${baserom}" ] && [ "$(echo $baserom |grep http)" != "" ];then
    blue "底包为一个链接，正在尝试下载" "Download link detected, start downloding.."
    aria2c --max-download-limit=1024M --file-allocation=none -s10 -x10 -j10 ${baserom}
    baserom=$(basename ${baserom} | sed 's/\?t.*//')
    if [ ! -f "${baserom}" ];then
        error "下载错误" "Download error!"
    fi
elif [ -f "${baserom}" ];then
    green "底包: ${baserom}" "BASEROM: ${baserom}"
else
    error "底包参数错误" "BASEROM: Invalid parameter"
    exit
fi

if [ ! -f "${portrom}" ] && [ "$(echo ${portrom} |grep http)" != "" ];then
    blue "移植包为一个链接，正在尝试下载"  "Download link detected, start downloding.."
    aria2c --max-download-limit=1024M --file-allocation=none -s10 -x10 -j10 ${portrom}
    portrom=$(basename ${portrom} | sed 's/\?t.*//')
    if [ ! -f "${portrom}" ];then
        error "下载错误" "Download error!"
    fi
elif [ -f "${portrom}" ];then
    green "移植包: ${portrom}" "PORTROM: ${portrom}"
else
    error "移植包参数错误" "PORTROM: Invalid parameter"
    exit
fi

if [ "$(echo $baserom |grep miui_)" != "" ];then
    device_code=$(basename $baserom |cut -d '_' -f 2)
elif [ "$(echo $baserom |grep xiaomi.eu_)" != "" ];then
    device_code=$(basename $baserom |cut -d '_' -f 3)
else
    device_code="YourDevice"
fi
super_list="vendor mi_ext odm system product system_ext"
blue "正在检测ROM底包" "Validating BASEROM.."
if 7z l ${baserom} | grep -q "payload.bin"; then
    baserom_type="payload"
    super_list="vendor mi_ext odm odm_dlkm system system_dlkm vendor_dlkm product product_dlkm system_ext"
elif 7z l ${baserom} | grep -q "br$";then
    baserom_type="br"
elif 7z l ${baserom} | grep -q "images/super.img*"; then
    is_base_rom_eu=true
else
    error "底包中未发现payload.bin以及br文件，请使用MIUI官方包后重试" "payload.bin/new.br not found, please use HyperOS official OTA zip package."
    exit
fi

blue "开始检测ROM移植包" "Validating PORTROM.."
if 7z l ${portrom} | grep  -q "payload.bin"; then
    green "ROM初步检测通过" "ROM validation passed."
elif [[ ${portrom} == *"xiaomi.eu"* ]];then
    is_eu_rom=true
else
    error "目标移植包没有payload.bin，请用MIUI官方包作为移植包" "payload.bin not found, please use HyperOS official OTA zip package."
fi

green "ROM初步检测通过" "ROM validation passed."

case $portrom in
    SHENNONG|HOUJI)
        is_shennong_houji_port=true
        ;;
    *)
        is_shennong_houji_port=false
        ;;
esac


blue "正在清理文件" "Cleaning up.."
for i in ${port_partition};do
    [ -d ./${i} ] && rm -rf ./${i}
done
sudo rm -rf app
sudo rm -rf tmp
sudo rm -rf config
sudo rm -rf build/baserom/
sudo rm -rf build/portrom/
find . -type d -name 'hyperos_*' |xargs rm -rf

green "文件清理完毕" "Files cleaned up."
mkdir -p build/baserom/images/
mkdir -p build/portrom/images/

# 提取分区
if [[ ${baserom_type} == 'payload' ]];then
    blue "正在提取底包 [payload.bin]" "Extracting files from BASEROM [payload.bin]"
    python3 ${py_scripts}/unzip.py ${baserom} --files payload.bin --out build/baserom ||error "解压底包 [payload.bin] 时出错" "Extracting [payload.bin] error"
    green "底包 [payload.bin] 提取完毕" "[payload.bin] extracted."
elif [[ ${baserom_type} == 'br' ]];then
    blue "正在提取底包 [new.dat.br]" "Extracting files from BASEROM [*.new.dat.br]"
    python3 ${py_scripts}/unzip.py ${baserom} --out build/baserom || error "解压底包 [new.dat.br]时出错" "Extracting [new.dat.br] error"
    green "底包 [new.dat.br] 提取完毕" "[new.dat.br] extracted."
elif [[ "${is_base_rom_eu}" == "true" ]];then
    blue "正在提取底包 [super.img]" "Extracting files from BASETROM [super.img]"
    python3 ${py_scripts}/unzip.py ${baserom} --out build/baserom --files "images/*" ||error "解压移植包 [super.img] 时出错"  "Extracting [super.img] error"
    blue "合并super.img* 到super.img" "Merging super.img.* into super.img"
    simg2img build/baserom/images/super.img.* build/baserom/images/super.img
    rm -rf build/baserom/images/super.img.*
    mv build/baserom/images/super.img build/baserom/super.img
    green "底包 [super.img] 提取完毕" "[super.img] extracted."
    mv build/baserom/images/boot.img build/baserom/
    mkdir -p build/baserom/firmware-update
    mv build/baserom/images/* build/baserom/firmware-update
fi

if [[ "${is_eu_rom}" == "true" ]];then
    blue "正在提取移植包 [super.img]" "Extracting files from PORTROM [super.img]"
    python3 ${py_scripts}/unzip.py ${portrom} --files "images/super.img.*" --out build/portrom ||error "解压移植包 [super.img] 时出错"  "Extracting [super.img] error"
    blue "合并super.img* 到super.img" "Merging super.img.* into super.img"
    simg2img build/portrom/images/super.img.* build/portrom/images/super.img
    rm -rf build/portrom/images/super.img.*
    mv build/portrom/images/super.img build/portrom/super.img
    green "移植包 [super.img] 提取完毕" "[super.img] extracted."
else
    blue "正在提取移植包 [payload.bin]" "Extracting files from PORTROM [payload.bin]"
    python3 ${py_scripts}/unzip.py ${portrom} --files payload.bin --out build/portrom ||error "解压移植包 [payload.bin] 时出错"  "Extracting [payload.bin] error"
    green "移植包 [payload.bin] 提取完毕" "[payload.bin] extracted."
fi

if [[ ${baserom_type} == 'payload' ]];then

    blue "开始分解底包 [payload.bin]" "Unpacking BASEROM [payload.bin]"
    python3 ${py_scripts}/payload_dumper.py build/baserom/payload.bin --out build/baserom/images/ ||error "分解底包 [payload.bin] 时出错" "Unpacking [payload.bin] failed"

elif [[ "${is_base_rom_eu}" == "true" ]];then
     blue "开始分解底包 [super.img]" "Unpacking BASEROM [super.img]"
        for i in ${super_list}; do 
            python3 ${py_scripts}/lpunpack.py -p ${i} build/baserom/super.img build/baserom/images
        done

elif [[ ${baserom_type} == 'br' ]];then
    blue "开始分解底包 [new.dat.br]" "Unpacking BASEROM[new.dat.br]"
        for i in ${super_list}; do
            ${tools_dir}/brotli -d build/baserom/$i.new.dat.br
            sudo python3 ${py_scripts}/sdat2img.py build/baserom/$i.transfer.list build/baserom/$i.new.dat build/baserom/images/$i.img
            rm -rf build/baserom/$i.new.dat* build/baserom/$i.transfer.list build/baserom/$i.patch.*
        done
fi

for part in system system_dlkm system_ext product product_dlkm mi_ext ;do
    if [[ -f build/baserom/images/${part}.img ]];then 
        if [[ $(python3 $py_scripts/gettype.py build/baserom/images/${part}.img) == "ext" ]];then
            blue "正在分解底包 ${part}.img [ext]" "Extracing ${part}.img [ext] from BASEROM"
            sudo python3 ${py_scripts}/imgextractor.py build/baserom/images/${part}.img build/baserom/images/
            blue "分解底包 [${part}.img] 完成" "BASEROM ${part}.img [ext] extracted."
            rm -rf build/baserom/images/${part}.img      
        elif [[ $(python3 $py_scripts/gettype.py build/baserom/images/${part}.img) == "erofs" ]]; then
            pack_type=EROFS
            blue "正在分解底包 ${part}.img [erofs]" "Extracing ${part}.img [erofs] from BASEROM"
            extract.erofs -x -i build/baserom/images/${part}.img -o build/baserom/images/   || error "分解 ${part}.img 失败" "Extracting ${part}.img failed."
            blue "分解底包 [${part}.img][erofs] 完成" "BASEROM ${part}.img [erofs] extracted."
            rm -rf build/baserom/images/${part}.img
        fi
    fi
    
done

for image in vendor odm vendor_dlkm odm_dlkm;do
    [ -f build/baserom/images/${image}.img ] && cp -rf build/baserom/images/${image}.img build/portrom/images/${image}.img
done

# 分解镜像
green "开始提取逻辑分区镜像" "Starting extract partition from img"
echo $super_list
for part in ${super_list};do
  case $part in vendor|odm|vendor_dlkm|odm_dlkm)
    if [[ -f "build/portrom/images/$part.img" ]]; then
      blue "从底包中提取 [${part}]分区 ..." "Extracting [${part}] from BASEROM"
    else
      if [[ "${is_eu_rom}" == "true" ]];then
            blue "PORTROM super.img 提取 [${part}] 分区..." "Extracting [${part}] from PORTROM super.img"
            blue "lpunpack.py PORTROM super.img ${patrt}_a"
            python3 ${py_scripts}/lpunpack.py -p ${part}_a build/portrom/super.img build/portrom/images
            mv build/portrom/images/${part}_a.img build/portrom/images/${part}.img
        else
            blue "payload.bin 提取 [${part}] 分区..." "Extracting [${part}] from PORTROM payload.bin"
            python3 ${py_scripts}/payload_dumper.py --images ${part} --out build/portrom/images/ build/portrom/payload.bin ||error "提取移植包 [${part}] 分区时出错" "Extracting partition [${part}] error."
        fi
    fi
    ;;
  *)
    if [[ "${is_eu_rom}" == "true" ]];then
            blue "PORTROM super.img 提取 [${part}] 分区..." "Extracting [${part}] from PORTROM super.img"
            blue "lpunpack.py PORTROM super.img ${patrt}_a"
            python3 ${py_scripts}/lpunpack.py -p ${part}_a build/portrom/super.img build/portrom/images
            mv build/portrom/images/${part}_a.img build/portrom/images/${part}.img
        else
            blue "payload.bin 提取 [${part}] 分区..." "Extracting [${part}] from PORTROM payload.bin"
            python3 ${py_scripts}/payload_dumper.py --images ${part} --out build/portrom/images/ build/portrom/payload.bin ||error "提取移植包 [${part}] 分区时出错" "Extracting partition [${part}] error."
        fi
        ;;
esac
    if [ -f "${work_dir}/build/portrom/images/${part}.img" ];then
        blue "开始提取 ${part}.img" "Extracting ${part}.img"
        if [[ $(python3 $py_scripts/gettype.py build/portrom/images/${part}.img) == "ext" ]];then
            pack_type=EXT
            python3 ${py_scripts}/imgextractor.py build/portrom/images/${part}.img build/portrom/images/ || error "提取${part}失败" "Extracting partition ${part} failed"
            #rm -rf build/portrom/images/${part}.img
            green "提取 [${part}] [ext]镜像完毕" "Extracting [${part}].img [ext] done"
        elif [[ $(python3 $py_scripts/gettype.py build/portrom/images/${part}.img) == "erofs" ]];then
            pack_type=EROFS
            green "移植包为 [erofs] 文件系统" "PORTROM filesystem: [erofs]. "
            [ "${repackext4}" = "true" ] && pack_type=EXT
            extract.erofs -x -i build/portrom/images/${part}.img -o build/portrom/images/ || error "提取${part}失败" "Extracting ${part} failed"
            #rm -rf build/portrom/images/${part}.img
            green "提取移植包[${part}] [erofs]镜像完毕" "Extracting ${part} [erofs] done."
        fi
    fi
done
rm -rf config

blue "正在获取ROM参数" "Fetching ROM build prop."
# 安卓版本
base_android_version=$(sed -n 's/.*ro.vendor.build.version.release=\(.*\)/\1/p' build/portrom/images/vendor/build.prop)
port_android_version=$(sed -n 's/.*ro.system.build.version.release=\(.*\)/\1/p' build/portrom/images/system/system/build.prop)
green "安卓版本: 底包为[Android ${base_android_version}], 移植包为 [Android ${port_android_version}]" "Android Version: BASEROM:[Android ${base_android_version}], PORTROM [Android ${port_android_version}]"

# SDK版本

base_android_sdk=$(sed -n 's/.*ro.vendor.build.version.sdk=\(.*\)/\1/p' build/portrom/images/vendor/build.prop)
port_android_sdk=$(sed -n 's/.*ro.system.build.version.sdk=\(.*\)/\1/p' build/portrom/images/system/system/build.prop)
green "SDK 版本: 底包为 [SDK ${base_android_sdk}], 移植包为 [SDK ${port_android_sdk}]" "SDK Verson: BASEROM: [SDK ${base_android_sdk}], PORTROM: [SDK ${port_android_sdk}]"

# ROM版本
base_rom_version=$(sed -n 's/.*ro.vendor.build.version.incremental=\(.*\)/\1/p' build/portrom/images/vendor/build.prop)
#HyperOS版本号获取
port_mios_version_incremental=$(sed -n 's/.*ro.mi.os.version.incremental=\(.*\)/\1/p' build/portrom/images/mi_ext/etc/build.prop)
#替换机型代号,比如小米10：UNBCNXM -> UJBCNXM

port_device_code=$(echo $port_mios_version_incremental | cut -d "." -f 5)

if [[ $port_mios_version_incremental == *DEV* ]];then
    yellow "检测到开发板，跳过修改版本代码" "Dev deteced,skip replacing codename"
    port_rom_version=$(echo $port_mios_version_incremental)
else
    base_device_code=U$(echo $base_rom_version | cut -d "." -f 5 | cut -c 2-)
    port_rom_version=$(echo $port_mios_version_incremental | sed "s/$port_device_code/$base_device_code/")
fi
green "ROM 版本: 底包为 [${base_rom_version}], 移植包为 [${port_rom_version}]" "ROM Version: BASEROM: [${base_rom_version}], PORTROM: [${port_rom_version}] "

# 代号
base_rom_code=$(sed -n 's/.*ro.product.vendor.device=\(.*\)/\1/p' build/portrom/images/vendor/build.prop)
port_rom_code=$(sed -n 's/.*ro.product.product.name=\(.*\)/\1/p' build/portrom/images/product/etc/build.prop)
green "机型代号: 底包为 [${base_rom_code}], 移植包为 [${port_rom_code}]" "Device Code: BASEROM: [${base_rom_code}], PORTROM: [${port_rom_code}]"

if grep -q "ro.build.ab_update=true" build/portrom/images/vendor/build.prop;  then
    is_ab_device=true
else
    is_ab_device=false

fi
for i in "AospFrameworkResOverlay.apk" "MiuiFrameworkResOverlay.apk" "DevicesAndroidOverlay.apk" "DevicesOverlay.apk" "SettingsRroDeviceHideStatusBarOverlay.apk" "MiuiBiometricResOverlay.apk"
do
  tmp_base=$(find build/baserom/images/product -type f -name $i)
  tmp_port=$(find build/portrom/images/product -type f -name $i)
  if [ -f "${tmp_base}" ] && [ -f "${tmp_port}" ]; then
    blue "正在替换 $i" "Replacing [$i]"
    cp -rf ${tmp_base} ${tmp_port}
  fi
done

#baseAospWifiResOverlay=$(find build/baserom/images/product -type f -name "AospWifiResOverlay.apk")
##portAospWifiResOverlay=$(find build/portrom/images/product -type f -name "AospWifiResOverlay.apk")
#if [ -f ${baseAospWifiResOverlay} ] && [ -f ${portAospWifiResOverlay} ];then
#    blue "正在替换 [AospWifiResOverlay.apk]"
#    cp -rf ${baseAospWifiResOverlay} ${portAospWifiResOverlay}
#fi


# radio lib
# blue "信号相关"
# for radiolib in $(find build/baserom/images/system/system/lib/ -maxdepth 1 -type f -name "*radio*");do
#     cp -rf $radiolib build/portrom/images/system/system/lib/
# done

# for radiolib in $(find build/baserom/images/system/system/lib64/ -maxdepth 1 -type f -name "*radio*");do
#     cp -rf $radiolib build/portrom/images/system/system/lib64/
# done


# audio lib
# blue "音频相关"
# for audiolib in $(find build/baserom/images/system/system/lib/ -maxdepth 1 -type f -name "*audio*");do
#     cp -rf $audiolib build/portrom/images/system/system/lib/
# done

# for audiolib in $(find build/baserom/images/system/system/lib64/ -maxdepth 1 -type f -name "*audio*");do
#     cp -rf $audiolib build/portrom/images/system/system/lib64/
# done

# # bt lib
# blue "蓝牙相关"
# for btlib in $(find build/baserom/images/system/system/lib/ -maxdepth 1 -type f -name "*bluetooth*");do
#     cp -rf $btlib build/portrom/images/system/system/lib/
# done

# for btlib in $(find build/baserom/images/system/system/lib64/ -maxdepth 1 -type f -name "*bluetooth*");do
#     cp -rf $btlib build/portrom/images/system/system/lib64/
# done


# displayconfig id
rm -rf build/portrom/images/product/etc/displayconfig/display_id*.xml
cp -rf build/baserom/images/product/etc/displayconfig/display_id*.xml build/portrom/images/product/etc/displayconfig/


# device_features
blue "Copying device_features"   
rm -rf build/portrom/images/product/etc/device_features/*
cp -rf build/baserom/images/product/etc/device_features/* build/portrom/images/product/etc/device_features/

#device_info
[[ "${is_eu_rom}" == "true" ]] && cp -rf build/baserom/images/product/etc/device_info.json build/portrom/images/product/etc/device_info.json
# MiSound
#baseMiSound=$(find build/baserom/images/product -type d -name "MiSound")
#portMiSound=$(find build/baserom/images/product -type d -name "MiSound")
#if [ -d ${baseMiSound} ] && [ -d ${portMiSound} ];then
#    blue "正在替换 MiSound"
 #   rm -rf ./${portMiSound}/*
 #   cp -rf ./${baseMiSound}/* ${portMiSound}/
#fi

# MusicFX
#baseMusicFX=$(find build/baserom/images/product build/baserom/images/system -type d -name "MusicFX")
#portMusicFX=$(find build/baserom/images/product build/baserom/images/system -type d -name "MusicFX")
#if [ -d ${baseMusicFX} ] && [ -d ${portMusicFX} ];then
#    blue "正在替换 MusicFX"
##    rm -rf ./${portMusicFX}/*
 #   cp -rf ./${baseMusicFX}/* ${portMusicFX}/
#fi

# 人脸
baseMiuiBiometric=$(find build/baserom/images/product/app -type d -name "MiuiBiometric*")
portMiuiBiometric=$(find build/portrom/images/product/app -type d -name "MiuiBiometric*")
if [ -d "${baseMiuiBiometric}" ] && [ -d "${portMiuiBiometric}" ];then
    yellow "查找MiuiBiometric" "Searching and Replacing MiuiBiometric.."
    rm -rf ./${portMiuiBiometric}/*
    cp -rf ./${baseMiuiBiometric}/* ${portMiuiBiometric}/
else
    if [ -d "${baseMiuiBiometric}" ] && [ ! -d "${portMiuiBiometric}" ];then
        blue "未找到MiuiBiometric，替换为原包" "MiuiBiometric is missing, copying from base..."
        cp -rf ${baseMiuiBiometric} build/portrom/images/product/app/
    fi
fi

# 修复AOD问题
targetDevicesAndroidOverlay=$(find build/portrom/images/product -type f -name "DevicesAndroidOverlay.apk")
if [[ -f $targetDevicesAndroidOverlay ]]; then
    mkdir tmp/  
    filename=$(basename $targetDevicesAndroidOverlay)
    yellow "修复息屏和屏下指纹问题" "Fixing AOD issue: $filename ..."
    targetDir=$(echo "$filename" | sed 's/\..*$//')
    bin/apktool/apktool d $targetDevicesAndroidOverlay -o tmp/$targetDir -f
    search_pattern="com\.miui\.aod\/com\.miui\.aod\.doze\.DozeService"
    replacement_pattern="com\.android\.systemui\/com\.android\.systemui\.doze\.DozeService"
    for xml in $(find tmp/$targetDir -type f -name "*.xml");do
        sed -i "s/$search_pattern/$replacement_pattern/g" $xml
    done
    bin/apktool/apktool b tmp/$targetDir -o tmp/$filename  || error "apktool 打包失败" "apktool mod failed"
    rm -rf $targetDevicesAndroidOverlay
    cat tmp/$filename > $targetDevicesAndroidOverlay
    rm -rf tmp
fi

# Change Default Refresh Rate 
targetFrameworksResCommon=$(find build/portrom/images/product -type f -name "FrameworksResCommon.apk")
if [[ -f $targetFrameworksResCommon ]] && [[ ! -z $targetFrameworksResCommon ]]; then
    
    [[ ! -d tmp ]] && mkdir tmp

    filename=$(basename $targetFrameworksResCommon)
    yellow "Change defaultRefreshRate/defaultPeakRefreshRate: $filename ..."
    targetDir=$(echo "$filename" | sed 's/\..*$//')
    bin/apktool/apktool d $targetFrameworksResCommon -o tmp/$targetDir -f

    defaultMaxRefreshRate=$(xmlstarlet sel -t -v "//integer-array[@name='fpsList']/item" build/portrom/images/product/etc/device_features/${base_rom_code}.xml | sort -nr | head -n 1)
    blue "Max RefreshRate: $defaultMaxRefreshRate"

    for xml in $(find tmp/$targetDir -type f -name "integers.xml");do
        # Change DefaultRefrshRate to 90 
        xmlstarlet ed -L -u "//integer[@name='config_defaultPeakRefreshRate']/text()" -v $defaultMaxRefreshRate $xml
        xmlstarlet ed -L -u "//integer[@name='config_defaultRefreshRate']/text()" -v $defaultMaxRefreshRate $xml
    done
    bin/apktool/apktool b tmp/$targetDir -o tmp/$filename  || error "apktool 打包失败" "apktool mod failed"
    cp -rfv tmp/$filename $targetFrameworksResCommon
fi

#其他机型可能没有default.prop
for prop_file in $(find build/portrom/images/vendor/ -name "*.prop"); do
    vndk_version=$(< "$prop_file" grep "ro.vndk.version" | awk "NR==1" | cut -d '=' -f 2)
    if [ -n "$vndk_version" ]; then
        yellow "ro.vndk.version为$vndk_version" "ro.vndk.version found in $prop_file: $vndk_version"
        break  
    fi
done
base_vndk=$(find build/baserom/images/system_ext/apex -type f -name "com.android.vndk.v${vndk_version}.apex")
port_vndk=$(find build/portrom/images/system_ext/apex -type f -name "com.android.vndk.v${vndk_version}.apex")

if [ ! -f "${port_vndk}" ]; then
    yellow "apex不存在，从原包复制" "target apex is missing, copying from baserom"
    cp -rf "${base_vndk}" "build/portrom/images/system_ext/apex/"
fi

if [ $(grep -c "sm8250" "build/portrom/images/vendor/build.prop") -ne 0 ]; then
    ## Fix the drop frame issus
    echo "ro.surface_flinger.enable_frame_rate_override=false" >> build/portrom/images/vendor/build.prop
    sed -i "s/persist.sys.miui_animator_sched.bigcores=.*/persist.sys.miui_animator_sched.bigcores=4-6/" build/portrom/images/product/etc/build.prop
    sed -i "s/persist.sys.miui_animator_sched.big_prime_cores=.*/persist.sys.miui_animator_sched.big_prime_cores=4-7/" build/portrom/images/product/etc/build.prop
    echo "persist.sys.miui.sf_cores=4-7" >> build/portrom/images/product/etc/build.prop
    echo "persist.sys.minfree_def=73728,92160,110592,154832,482560,579072" >> build/portrom/images/product/etc/build.prop
    echo "persist.sys.minfree_6g=73728,92160,110592,258048,663552,903168" >> build/portrom/images/product/etc/build.prop
    echo "persist.sys.minfree_8g=73728,92160,110592,387072,1105920,1451520" >> build/portrom/images/product/etc/build.prop
    echo "persist.vendor.display.miui.composer_boost=4-7" >> build/portrom/images/product/etc/build.prop

fi
# props from k60
echo "persist.vendor.mi_sf.optimize_for_refresh_rate.enable=1" >> build/portrom/images/vendor/build.prop
echo "ro.vendor.mi_sf.ultimate.perf.support=true"  >> build/portrom/images/vendor/build.prop

#echo "debug.sf.set_idle_timer_ms=1100" >> build/portrom/images/vendor/build.prop

#echo "ro.surface_flinger.set_touch_timer_ms=200" >> build/portrom/images/vendor/build.prop

# https://source.android.com/docs/core/graphics/multiple-refresh-rate
echo "ro.surface_flinger.use_content_detection_for_refresh_rate=false" >> build/portrom/images/vendor/build.prop
echo "ro.surface_flinger.set_touch_timer_ms=0" >> build/portrom/images/vendor/build.prop
echo "ro.surface_flinger.set_idle_timer_ms=0" >> build/portrom/images/vendor/build.prop

#解决开机报错问题
targetVintf=$(find build/portrom/images/system_ext/etc/vintf -type f -name "manifest.xml")
if [ -f "$targetVintf" ]; then
    # Check if the file contains $vndk_version
    if grep -q "<version>$vndk_version</version>" "$targetVintf"; then
        yellow "${vndk_version}已存在，跳过修改" "The file already contains the version $vndk_version. Skipping modification."
    else
        # If it doesn't contain $vndk_version, then add it
        ndk_version="<vendor-ndk>\n     <version>$vndk_version</version>\n </vendor-ndk>"
        sed -i "/<\/vendor-ndk>/a$ndk_version" "$targetVintf"
        yellow "添加成功" "Version $vndk_version added to $targetVintf"
    fi
else
    blue "File $targetVintf not found."
fi


blue "左侧挖孔灵动岛修复" "StrongToast UI fix"
if [[ "$is_shennong_houji_port" == "true" ]];then
    patch_smali "MiuiSystemUI.apk" "MIUIStrongToast\$2.smali" "const\/4 v7\, 0x0" "iget-object v7\, v1\, Lcom\/android\/systemui\/toast\/MIUIStrongToast;->mRLLeft:Landroid\/widget\/RelativeLayout;\\n\\tinvoke-virtual {v7}, Landroid\/widget\/RelativeLayout;->getLeft()I\\n\\tmove-result v7\\n\\tint-to-float v7,v7"
else
    patch_smali "MiuiSystemUI.apk" "MIUIStrongToast\$2.smali" "const\/4 v9\, 0x0" "iget-object v9\, v1\, Lcom\/android\/systemui\/toast\/MIUIStrongToast;->mRLLeft:Landroid\/widget\/RelativeLayout;\\n\\tinvoke-virtual {v9}, Landroid\/widget\/RelativeLayout;->getLeft()I\\n\\tmove-result v9\\n\\tint-to-float v9,v9"
fi



#blue "解除状态栏通知个数限制(默认最大6个)" "Set SystemUI maxStaticIcons to 6 by default."
#patch_smali "MiuiSystemUI.apk" "NotificationIconAreaController.smali" "iput p10, p0, Lcom\/android\/systemui\/statusbar\/phone\/NotificationIconContainer;->mMaxStaticIcons:I" "const\/4 p10, 0x6\n\n\tiput p10, p0, Lcom\/android\/systemui\/statusbar\/phone\/NotificationIconContainer;->mMaxStaticIcons:I"

if [[ "${is_eu_rom}" == "true" ]];then
    patch_smali "miui-services.jar" "SystemServerImpl.smali" ".method public constructor <init>()V/,/.end method" ".method public constructor <init>()V\n\t.registers 1\n\tinvoke-direct {p0}, Lcom\/android\/server\/SystemServerStub;-><init>()V\n\n\treturn-void\n.end method" "regex"

else    
    if [[ "$compatible_matrix_matches_enabled" == "false" ]]; then
        patch_smali "framework.jar" "Build.smali" ".method public static isBuildConsistent()Z" ".method public static isBuildConsistent()Z \n\n\t.registers 1 \n\n\tconst\/4 v0,0x1\n\n\treturn v0\n.end method\n\n.method public static isBuildConsistent_bak()Z"
    fi
    [[ ! -d tmp ]] && mkdir -p tmp/
    blue "开始移除 Android 签名校验" "Disalbe Android 14 Apk Signature Verfier"
    mkdir -p tmp/services/
    cp -rf build/portrom/images/system/system/framework/services.jar tmp/services/services.jar
    
    7z x -y tmp/services/services.jar *.dex -otmp/services
    target_method='getMinimumSignatureSchemeVersionForTargetSdk' 
    for dexfile in tmp/services/*.dex;do
        smali_fname=${dexfile%.*}
        smali_base_folder=$(echo $smali_fname | cut -d "/" -f 3)
        java -jar bin/apktool/baksmali.jar d --api ${port_android_sdk} ${dexfile} -o tmp/services/$smali_base_folder
    done

    old_smali_dir=""

    while read -r smali_file; do
        smali_dir=$(echo "$smali_file" | cut -d "/" -f 3)
        [[ "$smali_dir" != "$old_smali_dir" ]] && smali_dirs="${smali_dirs} ${smali_dir}"
        method_line=$(grep -n "$target_method" "$smali_file" | cut -d ':' -f 1)
        register_number=$(tail -n +"$method_line" "$smali_file" | grep -m 1 "move-result" | tr -dc '0-9')
        move_result_end_line=$(awk -v ML=$method_line 'NR>=ML && /move-result /{print NR; exit}' "$smali_file")
        orginal_line_number=$method_line
        replace_with_command="const/4 v${register_number}, 0x0"
        { sed -i "${orginal_line_number},${move_result_end_line}d" "$smali_file" && sed -i "${orginal_line_number}i\\${replace_with_command}" "$smali_file"; } &&    blue "${smali_file}  修改成功"
        old_smali_dir=$smali_dir
    done < <(find tmp/services -type f -name "*.smali" -exec grep -H "$target_method" {} \; | cut -d ':' -f 1)

    for smali_dir in ${smali_dirs}
    do
        blue "反编译成功，开始回编译 $smali_dir"
        java -jar bin/apktool/smali.jar a --api ${port_android_sdk} tmp/services/${smali_dir} -o tmp/services/${smali_dir}.dex
        cd tmp/services/
        7z a -y -mx0 -tzip services.jar ${smali_dir}.dex
        cd ../..
    done
    rm -rf build/portrom/images/system/system/framework/services.jar
    mv tmp/services/services.jar build/portrom/images/system/system/framework/services.jar
fi

# 主题防恢复
[ -f build/portrom/images/system/system/etc/init/hw/init.rc ] && sed -i '/on boot/a\'$'\n''    chmod 0731 \/data\/system\/theme' build/portrom/images/system/system/etc/init/hw/init.rc


if [[ "${is_eu_rom}" == "true" ]];then
    rm -rf build/portrom/images/product/app/Updater
    baseXGoogle=$(find build/baserom/images/product/ -type d -name "HotwordEnrollmentXGoogleHEXAGON*")
    portXGoogle=$(find build/portrom/images/product/ -type d -name "HotwordEnrollmentXGoogleHEXAGON*")
    if [ -d "${baseXGoogle}" ] && [ -d "${portXGoogle}" ];then
        yellow "查找并替换HotwordEnrollmentXGoogleHEXAGON_WIDEBAND.apk" "Searching and Replacing HotwordEnrollmentXGoogleHEXAGON_WIDEBAND.apk.."
        rm -rf ./${portXGoogle}/*
       cp -rf ./${baseXGoogle}/* ${portXGoogle}/
    else
        if [ -d "${baseXGoogle}" ] && [ ! -d "${portXGoogle}" ];then
            blue "未找到HotwordEnrollmentXGoogleHEXAGON_WIDEBAND.apk，替换为原包" "HotwordEnrollmentXGoogleHEXAGON_WIDEBAND.apk is missing, copying from base..."
            cp -rf ${baseXGoogle} build/portrom/images/product/priv-app/
        fi
    fi

    #baseOKGoogle=$(find build/baserom/images/product/ -type d -name "HotwordEnrollmentOKGoogleHEXAGON*")
    #portOKGoogle=$(find build/portrom/images/product/ -type d -name "HotwordEnrollmentOKGoogleHEXAGON*")
    #if [ -d "${baseOKGoogle}" ] && [ -d "${portOKGoogle}" ];then
    #    yellow "查找并替换HotwordEnrollmentOKGoogleHEXAGON_WIDEBAND.apk" "Searching and Replacing HotwordEnrollmentOKGoogleHEXAGON_WIDEBAND.apk.."
    #    rm -rf ./${portOKGoogle}/*
    #    cp -rf ./${baseOKGoogle}/* ${portOKGoogle}/
    #else
    #    if [ -d "${baseOKGoogle}" ] && [ ! -d "${portOKGoogle}" ];then
    #        blue "未找到HotwordEnrollmentOKGoogleHEXAGON_WIDEBAND.apk，替换为原包" "HotwordEnrollmentOKGoogleHEXAGON_WIDEBAND.apk is missing, copying from base..."
    #        cp -rf ${baseOKGoogle} build/portrom/images/product/priv-app/
    #    fi
    #fi

else
    yellow "删除多余的App" "Debloating..." 
    # List of apps to be removed
    for debloat_app in "MSA" "mab" "Updater" "MiuiUpdater" "MiService" "MIService" "SoterService" "Hybrid" "AnalyticsCore"; do
        # Find the app directory
        app_dir=$(find build/portrom/images/product -type d -name "*$debloat_app*")
        
        # Check if the directory exists before removing
        if [[ -d "$app_dir" ]] && [[ ! -z "$app_dir" ]]; then
            yellow "删除目录: $app_dir" "Removing directory: $app_dir"
            rm -rf "$app_dir"
        fi
    done
    rm -rf build/portrom/images/product/etc/auto-install*
    rm -rf build/portrom/images/product/data-app/*GalleryLockscreen*
    mkdir -p tmp/app
    for app in "DownloadProviderUi" "VirtualSim" "ThirdAppAssistant" "GameCenter" "Video" "Weather" "DeskClock" "Gallery" "SoundRecorder" "ScreenRecorder" "Calculator" "CleanMaster" "Calendar" "Compass" "Notes" "MediaEditor" "Scanner" "SpeechEngine" "wps-lite"; do
      [ -d build/portrom/images/product/data-app/*"${app}"* ] && mv build/portrom/images/product/data-app/*"${app}"* tmp/app/
    done

    rm -rf build/portrom/images/product/data-app/*
    cp -rf tmp/app/* build/portrom/images/product/data-app
    rm -rf tmp/app
    rm -rf build/portrom/images/system/verity_key
    rm -rf build/portrom/images/vendor/verity_key
    rm -rf build/portrom/images/product/verity_key
    rm -rf build/portrom/images/system/recovery-from-boot.p
    rm -rf build/portrom/images/vendor/recovery-from-boot.p
    rm -rf build/portrom/images/product/recovery-from-boot.p
    rm -rf build/portrom/images/product/media/theme/miui_mod_icons/com.google.android.apps.nbu*
    rm -rf build/portrom/images/product/media/theme/miui_mod_icons/dynamic/com.google.android.apps.nbu*
fi
# build.prop 修改
blue "正在修改 build.prop" "Modifying build.prop"
#
#change the locale to English
export LC_ALL=en_US.UTF-8
buildDate=$(date -u +"%a %b %d %H:%M:%S UTC %Y")
buildUtc=$(date +%s)
for i in $(find build/portrom/images -type f -name "build.prop");do
    blue "正在处理 ${i}" "modifying ${i}"
    sed -i "s/ro.build.date=.*/ro.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.build.date.utc=.*/ro.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.odm.build.date=.*/ro.odm.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.odm.build.date.utc=.*/ro.odm.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.vendor.build.date=.*/ro.vendor.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.vendor.build.date.utc=.*/ro.vendor.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.system.build.date=.*/ro.system.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.system.build.date.utc=.*/ro.system.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.product.build.date=.*/ro.product.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.product.build.date.utc=.*/ro.product.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.system_ext.build.date=.*/ro.system_ext.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.system_ext.build.date.utc=.*/ro.system_ext.build.date.utc=${buildUtc}/g" ${i}
   
    sed -i "s/ro.product.device=.*/ro.product.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.product.name=.*/ro.product.product.name=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.odm.device=.*/ro.product.odm.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.vendor.device=.*/ro.product.vendor.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.system.device=.*/ro.product.system.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.board=.*/ro.product.board=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.system_ext.device=.*/ro.product.system_ext.device=${base_rom_code}/g" ${i}
    sed -i "s/persist.sys.timezone=.*/persist.sys.timezone=Asia\/Shanghai/g" ${i}
    #全局替换device_code
    [[ "$port_mios_version_incremental" != *"DEV"* ]] && sed -i "s/$port_device_code/$base_device_code/g" ${i}
    # 添加build user信息
    sed -i "s/ro.build.user=.*/ro.build.user=${build_user}/g" ${i}
    if [[ "${is_eu_rom}" == "true" ]];then
        sed -i "s/ro.product.mod_device=.*/ro.product.mod_device=${base_rom_code}_xiaomieu_global/g" ${i}
        sed -i "s/ro.build.host=.*/ro.build.host=xiaomi.eu/g" ${i}

    else
        sed -i "s/ro.product.mod_device=.*/ro.product.mod_device=${base_rom_code}/g" ${i}
        sed -i "s/ro.build.host=.*/ro.build.host=${build_host}/g" ${i}
    fi
    sed -i "s/ro.build.characteristics=tablet/ro.build.characteristics=nosdcard/g" ${i}
    sed -i "s/ro.config.miui_multi_window_switch_enable=true/ro.config.miui_multi_window_switch_enable=false/g" ${i}
    sed -i "s/ro.config.miui_desktop_mode_enabled=true/ro.config.miui_desktop_mode_enabled=false/g" ${i}
    sed -i "/ro.miui.density.primaryscale=.*/d" ${i}
    sed -i "/persist.wm.extensions.enabled=true/d" ${i}
done

#sed -i -e '$a\'$'\n''persist.adb.notify=0' build/portrom/images/system/system/build.prop
#sed -i -e '$a\'$'\n''persist.sys.usb.config=mtp,adb' build/portrom/images/system/system/build.prop
#sed -i -e '$a\'$'\n''persist.sys.disable_rescue=true' build/portrom/images/system/system/build.prop
#sed -i -e '$a\'$'\n''persist.miui.extm.enable=0' build/portrom/images/system/system/build.prop

# 屏幕密度修修改
for prop in $(find build/baserom/images/product build/baserom/images/system -type f -name "build.prop");do
    base_rom_density=$(< "$prop" grep "ro.sf.lcd_density" |awk 'NR==1' |cut -d '=' -f 2)
    if [ "${base_rom_density}" != "" ];then
        green "底包屏幕密度值 ${base_rom_density}" "Screen density: ${base_rom_density}"
        break
    else
      # 未在底包找到则默认440,如果是其他值可自己修改
      base_rom_density=440
    fi
done

found=0
for prop in $(find build/portrom/images/product build/portrom/images/system -type f -name "build.prop");do
    if grep -q "ro.sf.lcd_density" ${prop};then
        sed -i "s/ro.sf.lcd_density=.*/ro.sf.lcd_density=${base_rom_density}/g" ${prop}
        found=1
    fi
    sed -i "s/persist.miui.density_v2=.*/persist.miui.density_v2=${base_rom_density}/g" ${prop}
done

if [ $found -eq 0  ]; then
        blue "未找到ro.fs.lcd_density，build.prop新建一个值$base_rom_density" "ro.fs.lcd_density not found, create a new value ${base_rom_density} "
        echo "ro.sf.lcd_density=${base_rom_density}" >> build/portrom/images/product/etc/build.prop
fi

echo "ro.miui.cust_erofs=0" >> build/portrom/images/product/etc/build.prop

#vendorprop=$(find build/portrom/images/vendor -type f -name "build.prop")
#odmprop=$(find build/baserom/images/odm -type f -name "build.prop" |awk 'NR==1')
#if [ "$(< $vendorprop grep "sys.haptic" |awk 'NR==1')" != "" ];then
#    blue "复制 haptic prop 到 odm"
#    < $vendorprop grep "sys.haptic" >>${odmprop}
#fi

#Fix： mi10 boot stuck at the first screen
sed -i "s/persist\.sys\.millet\.cgroup1/#persist\.sys\.millet\.cgroup1/" build/portrom/images/vendor/build.prop

#Fix：Fingerprint issue encountered on OS V1.0.18
echo "vendor.perf.framepacing.enable=false" >> build/portrom/images/vendor/build.prop


# Millet fix
blue "修复Millet" "Fix Millet"
# Function to update netlink in build.prop
update_netlink() {
  local netlink_version=$1
  local prop_file=$2

  if grep -q "ro.millet.netlink" "$prop_file"; then
    blue "找到ro.millet.netlink修改值为$netlink_version" "millet_netlink propery found, changing value to $netlink_version"
    sed -i "s/ro.millet.netlink=.*/ro.millet.netlink=$netlink_version/" "$prop_file"
  else
    blue "PORTROM未找到ro.millet.netlink值,添加为$netlink_version" "millet_netlink not found in portrom, adding new value $netlink_version"
    echo -e "ro.millet.netlink=$netlink_version\n" >> "$prop_file"
  fi
}

millet_netlink_version=$(grep "ro.millet.netlink" build/baserom/images/product/etc/build.prop | cut -d "=" -f 2)

if [[ -n "$millet_netlink_version" ]]; then
  update_netlink "$millet_netlink_version" "build/portrom/images/product/etc/build.prop"
else
  blue "原包未发现ro.millet.netlink值，请手动赋值修改(默认为29)" "ro.millet.netlink property value not found, change it manually(29 by default)."
  millet_netlink_version=29
  update_netlink "$millet_netlink_version" "build/portrom/images/product/etc/build.prop"
fi
# add advanced texture
if ! is_property_exists persist.sys.background_blur_supported build/portrom/images/product/etc/build.prop; then
    echo "persist.sys.background_blur_supported=true" >> build/portrom/images/product/etc/build.prop
    echo "persist.sys.background_blur_version=2" >> build/portrom/images/product/etc/build.prop
else
    sed -i "s/persist.sys.background_blur_supported=.*/persist.sys.background_blur_supported=true/" build/portrom/images/product/etc/build.prop
fi

unlock_device_feature "Whether support AI Display" "support_AI_display"
unlock_device_feature "device support screen enhance engine" "support_screen_enhance_engine"
unlock_device_feature "Whether suppot Android Flashlight Controller" "support_android_flashlight"
unlock_device_feature "Whether support SR for image display" "support_SR_for_image_display"

# Unlock MEMC; unlocking the screen enhance engine is a prerequisite.
# This feature add additional frames to videos to make content appear smooth and transitions lively.
if  grep -q "ro.vendor.media.video.frc.support" build/portrom/images/vendor/build.prop ;then
    sed -i "s/ro.vendor.media.video.frc.support=.*/ro.vendor.media.video.frc.support=true/" build/portrom/images/vendor/build.prop
else
    echo "ro.vendor.media.video.frc.support=true" >> build/portrom/images/vendor/build.prop
fi

#自定义替换

if [[ ${port_rom_code} == "dagu_cn" ]];then
    echo "ro.control_privapp_permissions=log" >> build/portrom/images/product/etc/build.prop
    
    rm -rf build/portrom/images/product/overlay/MiuiSystemUIResOverlay.apk
    rm -rf build/portrom/images/product/overlay/SettingsRroDeviceSystemUiOverlay.apk

    targetAospFrameworkTelephonyResOverlay=$(find build/portrom/images/product -type f -name "AospFrameworkTelephonyResOverlay.apk")
    if [[ -f $targetAospFrameworkTelephonyResOverlay ]]; then
        mkdir tmp/  
        filename=$(basename $targetAospFrameworkTelephonyResOverlay)
        yellow "Enable Phone Call and SMS feature in Pad port."
        targetDir=$(echo "$filename" | sed 's/\..*$//')
        bin/apktool/apktool d $targetAospFrameworkTelephonyResOverlay -o tmp/$targetDir -f
        for xml in $(find tmp/$targetDir -type f -name "*.xml");do
            sed -i 's|<bool name="config_sms_capable">false</bool>|<bool name="config_sms_capable">true</bool>|' $xml
            sed -i 's|<bool name="config_voice_capable">false</bool>|<bool name="config_voice_capable">true</bool>|' $xml
        done
        bin/apktool/apktool b tmp/$targetDir -o tmp/$filename  || error "apktool 打包失败" "apktool mod failed"
        cp -rfv tmp/$filename $targetAospFrameworkTelephonyResOverlay
        #rm -rf tmp
    fi
    blue "Replace Pad Software"
    if [[ -d devices/pad/overlay/product/priv-app ]];then

        for app in $(ls devices/pad/overlay/product/priv-app); do
            
            sourceApkFolder=$(find devices/pad/overlay/product/priv-app -type d -name *"$app"* )
            targetApkFolder=$(find build/portrom/images/product/priv-app -type d -name *"$app"* )
            if  [[ -d $targetApkFolder ]];then
                    rm -rfv $targetApkFolder
                    cp -rfv $sourceApkFolder build/portrom/images/product/priv-app
            else
                cp -rfv $sourceApkFolder build/portrom/images/product/priv-app
            fi

        done
    fi

    if [[ -d devices/pad/overlay/product/app ]];then
        for app in $(ls devices/pad/overlay/product/app); do
            targetAppfolder=$(find build/portrom/images/product/app -type d -name *"$app"* )
            if [ -d $targetAppfolder ]; then
                rm -rfv $targetAppfolder
            fi
            cp -rfv devices/pad/overlay/product/app/$app build/portrom/images/product/app/
        done
    fi

    if [[ -d devices/pad/overlay/system_ext ]]; then
        cp -rfv devices/pad/overlay/system_ext/* build/portrom/images/system_ext/
    fi

    blue "Add permissions" 
    sed -i 's|</permissions>|\t<privapp-permissions package="com.android.mms"> \n\t\t<permission name="android.permission.WRITE_APN_SETTINGS" />\n\t\t<permission name="android.permission.START_ACTIVITIES_FROM_BACKGROUND" />\n\t\t<permission name="android.permission.READ_PRIVILEGED_PHONE_STATE" />\n\t\t<permission name="android.permission.CALL_PRIVILEGED" /> \n\t\t<permission name="android.permission.GET_ACCOUNTS_PRIVILEGED" /> \n\t\t<permission name="android.permission.WRITE_SECURE_SETTINGS" />\n\t\t<permission name="android.permission.SEND_SMS_NO_CONFIRMATION" /> \n\t\t<permission name="android.permission.SEND_RESPOND_VIA_MESSAGE" />\n\t\t<permission name="android.permission.UPDATE_APP_OPS_STATS" />\n\t\t<permission name="android.permission.MODIFY_PHONE_STATE" /> \n\t\t<permission name="android.permission.WRITE_MEDIA_STORAGE" /> \n\t\t<permission name="android.permission.MANAGE_USERS" /> \n\t\t<permission name="android.permission.INTERACT_ACROSS_USERS" />\n\t\t <permission name="android.permission.SCHEDULE_EXACT_ALARM" /> \n\t</privapp-permissions>\n</permissions>|'  build/portrom/images/product/etc/permissions/privapp-permissions-product.xml
    sed -i 's|</permissions>|\t<privapp-permissions package="com.miui.contentextension">\n\t\t<permission name="android.permission.WRITE_SECURE_SETTINGS" />\n\t</privapp-permissions>\n</permissions>|' build/portrom/images/product/etc/permissions/privapp-permissions-product.xml

fi

if [[ -d "devices/common" ]];then
    commonCamera=$(find devices/common -type f -name "MiuiCamera.apk")
    targetCamera=$(find build/portrom/images/product -type d -name "MiuiCamera")
    bootAnimationZIP=$(find devices/common -type f -name "bootanimation_${base_rom_density}.zip")
    targetAnimationZIP=$(find build/portrom/images/product -type f -name "bootanimation.zip")
    MiLinkCirculateMIUI15=$(find devices/common -type d -name *"MiLinkCirculate"* )
    targetMiLinkCirculateMIUI15=$(find build/portrom/images/product -type d -name *"MiLinkCirculate"*)
    targetNQNfcNci=$(find build/portrom/images/system/system build/portrom/images/product build/portrom/images/system_ext -type d -name "NQNfcNci*")

    if [[ $base_android_version == "13" ]];then
        rm -rf $targetNQNfcNci
        cp -rfv devices/common/overlay/system/* build/portrom/images/system/
        cp -rfv devices/common/overlay/system_ext/framework/* build/portrom/images/system_ext/framework/

    fi
    if [[ $base_android_version == "13" ]] && [[ -f $commonCamera ]];then
        yellow "替换相机为10S HyperOS A13 相机，MI10可用, thanks to 酷安 @PedroZ" "Replacing a compatible MiuiCamera.apk verson 4.5.003000.2"
        if [[ -d $targetCamera ]];then
            rm -rf $targetCamera/*
        fi
        cp -rfv $commonCamera $targetCamera
    fi
    if [[ -f "$bootAnimationZIP" ]];then
        yellow "替换开机第二屏动画" "Repacling bootanimation.zip"
        cp -rfv $bootAnimationZIP $targetAnimationZIP
    fi

    if [[ -d "$targetMiLinkCirculateMIUI15" ]]; then
        rm -rf $targetMiLinkCirculateMIUI15/*
        cp -rfv $MiLinkCirculateMIUI15 $targetMiLinkCirculateMIUI15
    else
        mkdir -p build/portrom/images/product/app/MiLinkCirculateMIUI15
        cp -rfv $MiLinkCirculateMIUI15 build/portrom/images/product/app/
    fi
fi

#Devices/机型代码/overaly 按照镜像的目录结构，可直接替换目标。
if [[ -d "devices/${base_rom_code}/overlay" ]]; then
    blue "replace files in here"
else
    yellow "devices/${base_rom_code}/overlay 未找到" "devices/${base_rom_code}/overlay not found" 
fi

#添加erofs文件系统fstab
if [ ${pack_type} == "EROFS" ];then
    yellow "检查 vendor fstab.qcom是否需要添加erofs挂载点" "Validating whether adding erofs mount points is needed."
    if ! grep -q "erofs" build/portrom/images/vendor/etc/fstab.qcom ; then
               for pname in system odm vendor product mi_ext system_ext; do
                     sed -i "/\/${pname}[[:space:]]\+ext4/{p;s/ext4/erofs/;}" build/portrom/images/vendor/etc/fstab.qcom
                     added_line=$(sed -n "/\/${pname}[[:space:]]\+erofs/p" build/portrom/images/vendor/etc/fstab.qcom)
    
                    if [ -n "$added_line" ]; then
                        yellow "添加$pname" "Adding mount point $pname"
                    else
                        error "添加失败，请检查" "Adding faild, please check."
                        exit 1
                        
                    fi
                done
    fi
fi

# 去除avb校验
blue "去除avb校验" "Disable avb verification."
for fstab in $(find build/portrom/images/ -type f -name "fstab.*");do
    blue "Target: $fstab"
    sed -i "s/,avb_keys=.*avbpubkey//g" $fstab
    sed -i "s/,avb=vbmeta_system//g" $fstab
    sed -i "s/,avb=vbmeta_vendor//g" $fstab
    sed -i "s/,avb=vbmeta//g" $fstab
    sed -i "s/,avb//g" $fstab
done

# data 加密
remove_data_encrypt=$(grep "remove_data_encryption" bin/port_config |cut -d '=' -f 2)
if [ ${remove_data_encrypt} = "true" ];then
    blue "去除data加密"
    for fstab in $(find build/portrom/images -type f -name "fstab.*");do
		blue "Target: $fstab"
		sed -i "s/,fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts:aes-256-cts:v2+emmc_optimized+wrappedkey_v0//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts:aes-256-cts:v2//g" $fstab
		sed -i "s/,metadata_encryption=aes-256-xts:wrappedkey_v0//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts:wrappedkey_v0//g" $fstab
		sed -i "s/,metadata_encryption=aes-256-xts//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts//g" $fstab
    sed -i "s/,fileencryption=ice//g" $fstab
		sed -i "s/fileencryption/encryptable/g" $fstab
	done
fi

for pname in ${port_partition};do
    rm -rf build/portrom/images/${pname}.img
done
GetSuperSize() {
case $1 in
	#13 13Pro 13Ultra
	FUXI | NUWA |ISHTAR) size=9663676416;;
	#RedmiNote12Turbo |K60Pro |MIXFold
	MARBLE |SOCRATES|BABYLON) size=9663676416;;
	#Redmi Note 12 5G
	SUNSTONE) size=9122611200;;
	#PAD6Max
	YUDI) size=11811160064;;
	#Others
	*) size=9126805504;;
esac
echo $size

#pipa 9126805504 |Pad6
#liuqin 9126805504 |Pad6Pro
#sunstone 9126805504 or 9122611200 |Note 12 5G
#rembrandt 9126805504 |K60E
#redwood 9126805504 |Note12ProSpeed
#mondrian 9126805504 |K60
#yunluo 9126805504 |RedmiPad
#ruby 9126805504 |Note 12 Pro
}
superSize=$(GetSuperSize $device_code)
green "Super大小为${superSize}" "Super image size: ${superSize}"
green "开始打包镜像" "Packing super.img"
for pname in ${super_list};do
    if [ -d "build/portrom/images/$pname" ];then
        if [[ "$OSTYPE" == "darwin"* ]];then
            thisSize=$(find build/portrom/images/${pname} | xargs stat -f%z | awk ' {s+=$1} END { print s }' )
        else
            thisSize=$(du -sb build/portrom/images/${pname} |tr -cd 0-9)
        fi
        case $pname in
            mi_ext) addSize=4194304 ;;
            odm) addSize=34217728 ;;
            system|vendor|system_ext) addSize=84217728 ;;
            product) addSize=104217728 ;;
            *) addSize=8554432 ;;
        esac
        if [ "$pack_type" = "EXT" ];then
            for fstab in $(find build/portrom/images/${pname}/ -type f -name "fstab.*");do
                #sed -i '/overlay/d' $fstab
                sed -i '/system * erofs/d' $fstab
                sed -i '/system_ext * erofs/d' $fstab
                sed -i '/vendor * erofs/d' $fstab
                sed -i '/product * erofs/d' $fstab
            done
            thisSize=$(echo "$thisSize + $addSize" |bc)
            blue 以[$pack_type]文件系统打包[${pname}.img]大小[$thisSize] "Packing [${pname}.img]:[$pack_type] with size [$thisSize]"
            python3 ${py_scripts}/fspatch.py build/portrom/images/${pname} build/portrom/images/config/${pname}_fs_config
            python3 ${py_scripts}/contextpatch.py build/portrom/images/${pname} build/portrom/images/config/${pname}_file_contexts
            make_ext4fs -J -T $(date +%s) -S build/portrom/images/config/${pname}_file_contexts -l $thisSize -C build/portrom/images/config/${pname}_fs_config -L ${pname} -a ${pname} build/portrom/images/${pname}.img build/portrom/images/${pname}
            if [ -f "build/portrom/images/${pname}.img" ];then
                green "成功以大小 [$thisSize] 打包 [${pname}.img] [${pack_type}] 文件系统" "Packing [${pname}.img] with [${pack_type}], size: [$thisSize] success"
                #rm -rf build/baserom/images/${pname}
            else
                error "以 [${pack_type}] 文件系统打包 [${pname}] 分区失败" "Packing [${pname}] with[${pack_type}] filesystem failed!"
            fi
        else
            
                blue 以[$pack_type]文件系统打包[${pname}.img] "Packing [${pname}.img] with [$pack_type] filesystem"
                python3 ${py_scripts}/fspatch.py build/portrom/images/${pname} build/portrom/images/config/${pname}_fs_config
                python3 ${py_scripts}/contextpatch.py build/portrom/images/${pname} build/portrom/images/config/${pname}_file_contexts
                #sudo perl -pi -e 's/\\@/@/g' build/portrom/config/${pname}_file_contexts
                mkfs.erofs --mount-point ${pname} --fs-config-file build/portrom/images/config/${pname}_fs_config --file-contexts build/portrom/images/config/${pname}_file_contexts build/portrom/images/${pname}.img build/portrom/images/${pname}
                if [ -f "build/portrom/images/${pname}.img" ];then
                    green "成功以 [erofs] 文件系统打包 [${pname}.img]" "Packing [${pname}.img] successfully with [erofs] format"
                    #rm -rf build/portrom/images/${pname}
                else
                    error "以 [${pack_type}] 文件系统打包 [${pname}] 分区失败" "Faield to pack [${pname}]"
                    exit 1
                fi
        fi
        unset fsType
        unset thisSize
    fi
done

# 打包 super.img

if [[ "$is_ab_device" == false ]];then
    blue "打包A-only super.img" "Packing super.img for A-only device"
    lpargs="-F --output build/portrom/images/super.img --metadata-size 65536 --super-name super --metadata-slots 2 --block-size 4096 --device super:$superSize --group=qti_dynamic_partitions:$superSize"
    for pname in odm mi_ext system system_ext product vendor;do
        if [ -f "build/portrom/images/${pname}.img" ];then
            if [[ "$OSTYPE" == "darwin"* ]];then
               subsize=$(find build/portrom/images/${pname}.img | xargs stat -f%z | awk ' {s+=$1} END { print s }')
            else
                subsize=$(du -sb build/portrom/images/${pname}.img |tr -cd 0-9)
            fi
            green "Super 子分区 [$pname] 大小 [$subsize]" "Super sub-partition [$pname] size: [$subsize]"
            args="--partition ${pname}:none:${subsize}:qti_dynamic_partitions --image ${pname}=build/portrom/images/${pname}.img"
            lpargs="$lpargs $args"
            unset subsize
            unset args
        fi
    done
else
    blue "打包V-A/B机型 super.img" "Packing super.img for V-AB device"
    lpargs="-F --virtual-ab --output build/portrom/images/super.img --metadata-size 65536 --super-name super --metadata-slots 3 --device super:$superSize --group=qti_dynamic_partitions_a:$superSize --group=qti_dynamic_partitions_b:$superSize"

    for pname in ${super_list};do
        if [ -f "build/portrom/images/${pname}.img" ];then
            subsize=$(du -sb build/portrom/images/${pname}.img |tr -cd 0-9)
            green "Super 子分区 [$pname] 大小 [$subsize]" "Super sub-partition [$pname] size: [$subsize]"
            args="--partition ${pname}_a:none:${subsize}:qti_dynamic_partitions_a --image ${pname}_a=build/portrom/images/${pname}.img --partition ${pname}_b:none:0:qti_dynamic_partitions_b"
            lpargs="$lpargs $args"
            unset subsize
            unset args
        fi
    done
fi
lpmake $lpargs
#echo "lpmake $lpargs"
if [ -f "build/portrom/images/super.img" ];then
    green "成功打包 super.img" "Pakcing super.img done."
else
    error "无法打包 super.img"  "Unable to pack super.img."
    exit 1
fi
for pname in ${super_list};do
    rm -rf build/portrom/images/${pname}.img
done
os_type="hyperos"
[[ "${is_eu_rom}" == "true" ]] && os_type="xiaomi.eu"
blue "正在压缩 super.img" "Comprising super.img"
zstd --rm build/portrom/images/super.img -o build/portrom/images/super.zst
mkdir -p out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/
mkdir -p out/${os_type}_${device_code}_${port_rom_version}/bin/windows/

blue "正在生成刷机脚本" "Generating flashing script"
if [[ "$is_ab_device" == false ]];then

    mv -f build/portrom/images/super.zst out/${os_type}_${device_code}_${port_rom_version}/
    #firmware
    cp -rf bin/flash/platform-tools-windows/* out/${os_type}_${device_code}_${port_rom_version}/bin/windows/
    cp -rf bin/flash/mac_linux_flash_script.sh out/${os_type}_${device_code}_${port_rom_version}/
    cp -rf bin/flash/windows_flash_script.bat out/${os_type}_${device_code}_${port_rom_version}/
    sed -i "s/_ab//g" out/${os_type}_${device_code}_${port_rom_version}/mac_linux_flash_script.sh
    sed -i "s/_ab//g" out/${os_type}_${device_code}_${port_rom_version}/windows_flash_script.bat
    sed -i '/^# SET_ACTION_SLOT_A_BEGIN$/,/^# SET_ACTION_SLOT_A_END$/d' out/${os_type}_${device_code}_${port_rom_version}/mac_linux_flash_script.sh
    sed -i '/^REM SET_ACTION_SLOT_A_BEGIN$/,/^REM SET_ACTION_SLOT_A_END$/d' out/${os_type}_${device_code}_${port_rom_version}/windows_flash_script.bat

    if [ -d build/baserom/firmware-update ];then
        mkdir -p out/${os_type}_${device_code}_${port_rom_version}/firmware-update
        cp -rf build/baserom/firmware-update/*  out/${os_type}_${device_code}_${port_rom_version}/firmware-update

         for fwimg in $(ls out/${os_type}_${device_code}_${port_rom_version}/firmware-update | grep -v "cust");do
            if [[ ${fwimg} == "uefi_sec.mbn" ]];then
                part="uefisecapp"
            elif [[ ${fwimg} == "qupv3fw.elf" ]];then
                part="qupfw"
            elif [[ ${fwimg} == "NON-HLOS.bin" ]];then
                part="modem"
            elif [[ ${fwimg} == "km4.mbn" ]];then
                part="keymaster"
            elif [[ ${fwimg} == "BTFM.bin" ]];then
                part="bluetooth"
            elif [[ ${fwimg} == "dspso.bin" ]];then
                part="dsp"
            else
                part=${fwimg%.*}                
            fi
            sed -i "/# firmware/a fastboot flash ${part} firmware-update/${fwimg}" out/${os_type}_${device_code}_${port_rom_version}/mac_linux_flash_script.sh
            sed -i "/REM firmware/a bin\\\windows\\\fastboot.exe flash ${part} %~dp0firmware-update\/${fwimg}" out/${os_type}_${device_code}_${port_rom_version}/windows_flash_script.bat
         done

    fi

    #disable vbmeta
    for img in $(find out/${os_type}_${device_code}_${port_rom_version}/firmware-update -type f -name "vbmeta*.img");do
        python3 ${py_scripts}/patch-vbmeta.py ${img}
    done
    cp -f build/baserom/boot.img out/${os_type}_${device_code}_${port_rom_version}/boot_official.img
    cp -rf bin/flash/a-only/update-binary out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/
    cp -rf bin/flash/zstd out/${os_type}_${device_code}_${port_rom_version}/META-INF/
    custom_bootimg_file=$(find devices/$base_rom_code/ -type f -name "boot*.img")

    if [[ -f "$custom_bootimg_file" ]];then
        bootimg=$(basename "$custom_bootimg_file")
        sed -i "s/boot_tv.img/$bootimg/g" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary
        sed -i "s/boot_tv.img/$bootimg/g" out/${os_type}_${device_code}_${port_rom_version}/windows_flash_script.bat
        sed -i "s/boot_tv.img/$bootimg/g" out/${os_type}_${device_code}_${port_rom_version}/mac_linux_flash_script.sh
        cp -rf $custom_bootimg_file out/${os_type}_${device_code}_${port_rom_version}/
    fi
    busybox unix2dos out/${os_type}_${device_code}_${port_rom_version}/windows_flash_script.bat
    sed -i "s/portversion/${port_rom_version}/g" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/baseversion/${base_rom_version}/g" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/andVersion/${port_android_version}/g" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/device_code/${base_rom_code}/g" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary

else
    mkdir -p out/${os_type}_${device_code}_${port_rom_version}/images/
    mv -f build/portrom/images/super.zst out/${os_type}_${device_code}_${port_rom_version}/images/
    cp -rf bin/flash/vab/update-binary out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/
    cp -rf bin/flash/platform-tools-windows out/${os_type}_${device_code}_${port_rom_version}/META-INF/
    cp -rf bin/flash/vab/flash_update.bat out/${os_type}_${device_code}_${port_rom_version}/
    cp -rf bin/flash/vab/flash_and_format.bat out/${os_type}_${device_code}_${port_rom_version}/
   
    cp -rf bin/flash/zstd out/${os_type}_${device_code}_${port_rom_version}/META-INF/
    for fwImg in $(ls out/${os_type}_${device_code}_${port_rom_version}/images/ |cut -d "." -f 1 |grep -vE "super|cust|preloader");do
        if [ "$(echo ${fwimg} |grep vbmeta)" != "" ];then
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "${fwimg}"_b images\/"${fwimg}".img" out/${os_type}_${device_code}_${port_rom_version}/flash_update.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "${fwimg}"_a images\/"${fwimg}".img" out/${os_type}_${device_code}_${port_rom_version}/flash_update.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "${fwimg}"_b images\/"${fwimg}".img" out/${os_type}_${device_code}_${port_rom_version}/flash_and_format.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "${fwimg}"_a images\/"${fwimg}".img" out/${os_type}_${device_code}_${port_rom_version}/flash_and_format.bat
            sed -i "/#firmware/a package_extract_file \"images/"${fwimg}".img\" \"/dev/block/bootdevice/by-name/"${fwimg}"_b\"" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary
            sed -i "/#firmware/a package_extract_file \"images/"${fwimg}".img\" \"/dev/block/bootdevice/by-name/"${fwimg}"_a\"" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary
        else
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "${fwimg}"_b images\/"${fwimg}".img" out/${os_type}_${device_code}_${port_rom_version}/flash_update.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "${fwimg}"_a images\/"${fwimg}".img" out/${os_type}_${device_code}_${port_rom_version}/flash_update.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "${fwimg}"_b images\/"${fwimg}".img" out/${os_type}_${device_code}_${port_rom_version}/flash_and_format.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "${fwimg}"_a images\/"${fwimg}".img" out/${os_type}_${device_code}_${port_rom_version}/flash_and_format.bat
            sed -i "/#firmware/a package_extract_file \"images/"${fwimg}".img\" \"/dev/block/bootdevice/by-name/"${fwimg}"_b\"" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary
            sed -i "/#firmware/a package_extract_file \"images/"${fwimg}".img\" \"/dev/block/bootdevice/by-name/"${fwimg}"_a\"" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary
        fi
    done

    sed -i "s/portversion/${port_rom_version}/g" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/baseversion/${base_rom_version}/g" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/andVersion/${port_android_version}/g" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/device_code/${base_rom_code}/g" out/${os_type}_${device_code}_${port_rom_version}/META-INF/com/google/android/update-binary

    busybox unix2dos out/${os_type}_${device_code}_${port_rom_version}/flash_update.bat
    busybox unix2dos out/${os_type}_${device_code}_${port_rom_version}/flash_and_format.bat

fi

find out/${os_type}_${device_code}_${port_rom_version} |xargs touch
cd out/${os_type}_${device_code}_${port_rom_version}/ || exit
7z a -tzip ${os_type}_${device_code}_${port_rom_version}.zip ./*
mv ${os_type}_${device_code}_${port_rom_version}.zip ../
cd ../.. || exit
pack_timestamp=$(date +"%m%d%H%M")
hash=$(md5sum out/${os_type}_${device_code}_${port_rom_version}.zip |head -c 10)
if [[ $pack_type == "EROFS" ]];then
    pack_type="ROOT_"${pack_type}
    yellow "检测到打包类型为EROFS,请确保官方内核支持，或者在devices机型目录添加有支持EROFS的内核，否者将无法开机！" "EROFS filesystem detected. Ensure compatibility with the official boot.img or ensure a supported boot_tv.img is placed in the device folder."
fi
mv out/${os_type}_${device_code}_${port_rom_version}.zip out/${os_type}_${device_code}_${port_rom_version}_${hash}_${port_android_version}_${port_rom_code}_${pack_timestamp}_${pack_type}.zip
green "移植完毕" "Porting completed"    
green "输出包路径：" "Output: "
green "$(pwd)/out/${os_type}_${device_code}_${port_rom_version}_${hash}_${port_android_version}_${port_rom_code}_${pack_timestamp}_${pack_type}.zip"
