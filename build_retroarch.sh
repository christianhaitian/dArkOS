#!/bin/bash

# Build and install Retroarch
if [ -f "Arkbuild_package_cache/${CHIPSET}/retroarch_${UNIT}.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/retroarch_${UNIT}.commit)" == "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/retroarch.sh | grep -oP '(?<=tag=").*?(?=")')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/retroarch_${UNIT}.tar.gz
else
	retroarch_tries=0
	while true
	do
	  call_chroot "cd /home/ark &&
		cd ${CHIPSET}_core_builds &&
		chmod 777 builds-alt.sh &&
		[ -d retroarch ] && rm -rf retroarch* || echo \"Cloning into retroarch\" &&
		eatmydata ./builds-alt.sh retroarch
		"
	  if [[ "$?" -ne "0" ]]; then
		retroarch_tries=$((retroarch_tries + 1))
		if [ "${retroarch_tries}" -ge 5 ]; then
		  echo "RetroArch build failed after ${retroarch_tries} attempts; continuing"
		  break
		fi
		sleep 30
		continue
	  else
		break
	  fi
	done

	sudo mkdir -p Arkbuild/opt/retroarch/bin
	sudo mkdir -p Arkbuild/home/ark/.config/retroarch/filters/video
	sudo mkdir -p Arkbuild/home/ark/.config/retroarch/filters/audio
	sudo mkdir -p Arkbuild/home/ark/.config/retroarch/autoconfig/udev
	if [ "$UNIT" == "rgb10" ] || [ "$UNIT" == "rk2020" ]; then
	  sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch64/retroarch.${CHIPSET}.rot Arkbuild/opt/retroarch/bin/retroarch
	elif [ "$UNIT" == "miniloong" ]; then
	  sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch64/retroarch-rgarotated Arkbuild/opt/retroarch/bin/retroarch
	elif [ "$CHIPSET" == "rk3566" ]; then
	  sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch64/retroarch Arkbuild/opt/retroarch/bin/retroarch
	else
	  sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch64/retroarch.${CHIPSET}.unrot Arkbuild/opt/retroarch/bin/retroarch
	fi
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch/gfx/video_filters/*.so Arkbuild/home/ark/.config/retroarch/filters/video/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch/gfx/video_filters/*.filt Arkbuild/home/ark/.config/retroarch/filters/video/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch/libretro-common/audio/dsp_filters/*.so Arkbuild/home/ark/.config/retroarch/filters/audio/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch/libretro-common/audio/dsp_filters/*.dsp Arkbuild/home/ark/.config/retroarch/filters/audio/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/retroarch_${UNIT}.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/retroarch_${UNIT}.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/retroarch_${UNIT}.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/retroarch_${UNIT}.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/retroarch_${UNIT}.tar.gz Arkbuild/opt/retroarch/bin/retroarch Arkbuild/home/ark/.config/retroarch/
	sudo curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/retroarch.sh | grep -oP '(?<=tag=").*?(?=")' > Arkbuild_package_cache/${CHIPSET}/retroarch_${UNIT}.commit
fi
sudo rm -rf Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch/
sudo cp retroarch/configs/retroarch.cfg.${UNIT} Arkbuild/home/ark/.config/retroarch/retroarch.cfg
sudo cp retroarch/configs/retroarch.cfg.spectate Arkbuild/home/ark/.config/retroarch/retroarch.cfg.spectate
sudo cp retroarch/configs/retroarch.cfg.vert Arkbuild/home/ark/.config/retroarch/retroarch.cfg.vert
sudo cp retroarch/configs/retroarch.cfg.bak.${UNIT} Arkbuild/home/ark/.config/retroarch/retroarch.cfg.bak
sudo cp retroarch/configs/retroarch-core-options.cfg.${UNIT} Arkbuild/home/ark/.config/retroarch/retroarch-core-options.cfg
sudo cp retroarch/configs/retroarch-core-options.cfg.bak.${UNIT} Arkbuild/home/ark/.config/retroarch/retroarch-core-options.cfg.bak
sudo cp retroarch/configs/controller/*.cfg Arkbuild/home/ark/.config/retroarch/autoconfig/udev/
sudo cp retroarch/scripts/retroarch Arkbuild/usr/local/bin/
sudo mkdir -p Arkbuild/opt/cmds
sudo cp retroarch/scripts/retroarch.sh Arkbuild/opt/cmds
#sudo cp retroarch/scripts/retroarch32.sh Arkbuild/opt/cmds
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/cmds/*
sudo chmod 777 Arkbuild/usr/local/bin/retroarch
sudo chmod 777 Arkbuild/opt/retroarch/bin/*
# Add cores requested from retroarch_cores
if [ "$CHIPSET" == "rk3326" ]; then
  CORE_REPO="master"
else
  CORE_REPO="rg503"
fi
ARCH="aarch64"
sudo mkdir -p Arkbuild/home/ark/.config/retroarch/cores
while read RETROARCH_CORE; do
  if [[ ! "$RETROARCH_CORE" =~ ^# ]]; then
    echo -e "Adding ${RETROARCH_CORE} libretro core\n"
    wget --retry-connrefused --retry-on-http-error=429 --waitretry=20 -t 65 -T 30 --no-check-certificate https://github.com/christianhaitian/retroarch-cores/raw/"$CORE_REPO"/"$ARCH"/"$RETROARCH_CORE"_libretro.so.zip -O /dev/shm/"$RETROARCH_CORE"_libretro.so.zip
    if [ $? -eq 0 ]; then
      sudo unzip -o /dev/shm/"$RETROARCH_CORE"_libretro.so.zip -d Arkbuild/home/ark/.config/retroarch/cores/
      rm -f /dev/shm/"$RETROARCH_CORE"_libretro.so.zip
      printf "\n  ${RETROARCH_CORE} libretro has now been added!\n"
    else
      printf "\n  ${RETROARCH_CORE} libretro was not added!\n"
    fi
    sudo wget --retry-connrefused --retry-on-http-error=429 --waitretry=20 -t 65 -T 30 --no-check-certificate https://github.com/libretro/libretro-core-info/raw/refs/heads/master/"$RETROARCH_CORE"_libretro.info -O Arkbuild/home/ark/.config/retroarch/cores/"$RETROARCH_CORE"_libretro.info
    if [ $? -ne 0 ]; then
      if [ -f "core_info_files/${RETROARCH_CORE}_libretro.info" ]; then
	    sudo cp core_info_files/"$RETROARCH_CORE"_libretro.info Arkbuild/home/ark/.config/retroarch/cores/"$RETROARCH_CORE"_libretro.info
      fi
    fi
  fi
  sleep 5
done <retroarch_cores.txt

# Copy other core info files not available from libretro's repo
sudo cp core_info_files/* Arkbuild/home/ark/.config/retroarch/cores/

# Download and add retroarch assets
sudo git clone --depth=1 https://github.com/libretro/retroarch-assets.git Arkbuild/home/ark/.config/retroarch/assets/
sudo find Arkbuild/home/ark/.config/retroarch/assets/ -maxdepth 1 ! -name assets \
                                                                  ! -name glui \
                                                                  ! -name nxrgui \
                                                                  ! -name ozone \
                                                                  ! -name pkg \
                                                                  ! -name rgui \
                                                                  ! -name sounds \
                                                                  ! -name switch \
                                                                  ! -name xmb \
                                                                  ! -name COPYING -type d,f -not -path '.' -exec rm -rf {} +
# Download and add retroarch shaders
sudo mkdir -p Arkbuild/home/ark/.config/retroarch/shaders/shaders_glsl
sudo git clone --depth=1 https://github.com/libretro/glsl-shaders.git Arkbuild/home/ark/.config/retroarch/shaders/shaders_glsl/
sudo rm -f Arkbuild/home/ark/.config/retroarch/shaders/shaders_glsl/{configure,Makefile}
sudo mkdir -p Arkbuild/home/ark/.config/retroarch/shaders/shaders_glsl/Sharp-Shimmerless
sudo git clone --depth=1 https://github.com/Woohyun-Kang/Sharp-Shimmerless-Shader.git Arkbuild/home/ark/.config/retroarch/shaders/shaders_glsl/Sharp-Shimmerless/
sudo rm -rf Arkbuild/home/ark/.config/retroarch/shaders/shaders_glsl/Sharp-Shimmerless/shaders_slang/
sudo mv Arkbuild/home/ark/.config/retroarch/shaders/shaders_glsl/Sharp-Shimmerless/shaders_glsl/* Arkbuild/home/ark/.config/retroarch/shaders/shaders_glsl/Sharp-Shimmerless/
sudo rm -rf Arkbuild/home/ark/.config/retroarch/shaders/shaders_glsl/Sharp-Shimmerless/shaders_glsl/

# Build libretro easyrpg from scratch since there is usually a need for a matching liblcf file for a new build
if [ -f "Arkbuild_package_cache/${CHIPSET}/easyrpg.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/easyrpg.commit)" = "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/easyrpg.sh | grep -oP '(?<=tag=").*?(?=")')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/easyrpg.tar.gz
else
	easyrpg_tries=0
	while true
	do
	  call_chroot "cd /home/ark &&
		cd ${CHIPSET}_core_builds &&
		[ -d Player ] && rm -rf Player || echo \"Cloning into Player\" &&
		eatmydata ./builds-alt.sh easyrpg
		"
	  if [[ "$?" -ne "0" ]]; then
		easyrpg_tries=$((easyrpg_tries + 1))
		if [ "${easyrpg_tries}" -ge 5 ]; then
		  echo "EasyRPG build failed after ${easyrpg_tries} attempts; continuing"
		  break
		fi
		sleep 30
		continue
	  else
		break
	  fi
	done
	sudo cp Arkbuild/home/ark/${CHIPSET}_core_builds/cores64/easyrpg_libretro.so Arkbuild/home/ark/.config/retroarch/cores/
	sudo cp Arkbuild/home/ark/${CHIPSET}_core_builds/cores64/liblcf.so.0 Arkbuild/usr/lib/aarch64-linux-gnu/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/easyrpg.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/easyrpg.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/easyrpg.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/easyrpg.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/easyrpg.tar.gz Arkbuild/home/ark/.config/retroarch/cores/easyrpg_libretro.so Arkbuild/usr/lib/aarch64-linux-gnu/liblcf.so.0
	sudo curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/easyrpg.sh | grep -oP '(?<=tag=").*?(?=")' > Arkbuild_package_cache/${CHIPSET}/easyrpg.commit
fi

# Build freej2me-lr.jar and freej2me-plus-lr.jar
if [ -f "Arkbuild_package_cache/${CHIPSET}/freej2me-plus.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/freej2me-plus.commit)" = "$(curl --silent https://api.github.com/repos/TASEmulators/freej2me-plus/releases | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/freej2me-plus.tar.gz
else
   call_chroot "cd /home/ark &&
		cd ${CHIPSET}_core_builds &&
		[ -d freej2me-plus ] && rm -rf freej2me-plus || echo \"Cloning into freej2me-plus\" &&
		git clone --recursive https://github.com/TASEmulators/freej2me-plus.git &&
		cd freej2me-plus &&
		sed -i 's/freej2me-lr.jar/freej2me-plus-lr.jar/' build.xml &&
		sed -i 's/1.6/1.8/' build.xml &&
		ant
		"
   sudo mkdir -p Arkbuild/usr/local/bin/freej2me_files/
   sudo cp Arkbuild/home/ark/${CHIPSET}_core_builds/freej2me-plus/build/freej2me-plus-lr.jar Arkbuild/usr/local/bin/freej2me_files/
   if [ -f "Arkbuild_package_cache/${CHIPSET}/freej2me-plus.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/freej2me-plus.tar.gz
   fi
   if [ -f "Arkbuild_package_cache/${CHIPSET}/freej2me-plus.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/freej2me-plus.commit
   fi
   sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/freej2me-plus.tar.gz Arkbuild/usr/local/bin/freej2me_files/freej2me-plus-lr.jar
   sudo curl --silent https://api.github.com/repos/TASEmulators/freej2me-plus/releases | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' > Arkbuild_package_cache/${CHIPSET}/freej2me-plus.commit
fi
if [ -f "Arkbuild_package_cache/${CHIPSET}/freej2me.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/freej2me.commit)" == "$(curl -s https://api.github.com/repos/hex007/freej2me/commits/master | jq -r '.sha')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/freej2me.tar.gz
else
   call_chroot "cd /home/ark &&
		cd ${CHIPSET}_core_builds &&
		[ -d freej2me ] && rm -rf freej2me || echo \"Cloning into freej2me\" &&
		git clone --recursive https://github.com/hex007/freej2me.git &&
		cd freej2me &&
		ant
		"
   sudo mkdir -p Arkbuild/usr/local/bin/freej2me_files/
   sudo cp Arkbuild/home/ark/${CHIPSET}_core_builds/freej2me/build/freej2me-lr.jar Arkbuild/usr/local/bin/freej2me_files/
   if [ -f "Arkbuild_package_cache/${CHIPSET}/freej2me.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/freej2me.tar.gz
   fi
   if [ -f "Arkbuild_package_cache/${CHIPSET}/freej2me.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/freej2me.commit
   fi
   sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/freej2me.tar.gz Arkbuild/usr/local/bin/freej2me_files/freej2me-lr.jar
   sudo curl -s https://api.github.com/repos/hex007/freej2me/commits/master | jq -r '.sha' > Arkbuild_package_cache/${CHIPSET}/freej2me.commit
fi

if [[ "${BUILD_ARMHF}" == "y" ]]; then
	if [ -f "Arkbuild_package_cache/${CHIPSET}/retroarch32_${UNIT}.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/retroarch32_${UNIT}.commit)" == "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/retroarch.sh | grep -oP '(?<=tag=").*?(?=")')" ]; then
      sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/retroarch32_${UNIT}.tar.gz
	else
		setup_arkbuild32
		sudo chroot Arkbuild32/ mkdir -p /home/ark
		retroarch32_tries=0
		while true
		do
		  call_chroot32 "cd /home/ark &&
			if [ ! -d ${CHIPSET}_core_builds ]; then git clone https://github.com/christianhaitian/${CHIPSET}_core_builds.git; fi &&
			cd ${CHIPSET}_core_builds &&
			chmod 777 builds-alt.sh &&
			[ -d retroarch ] && rm -rf retroarch* || echo \"Cloning into retroarch\" &&
			./builds-alt.sh retroarch
			"
		  if [[ "$?" -ne "0" ]]; then
			retroarch32_tries=$((retroarch32_tries + 1))
			if [ "${retroarch32_tries}" -ge 5 ]; then
			  echo "retroarch32 build failed after ${retroarch32_tries} attempts; continuing"
			  break
			fi
			sleep 30
			continue
		  else
			break
		  fi
		done
		sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/filters/video
		sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/filters/audio
		sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/autoconfig/udev
		if [ "$UNIT" == "rgb10" ] || [ "$UNIT" == "rk2020" ]; then
		  sudo cp Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch32/retroarch32.${CHIPSET}.rot Arkbuild/opt/retroarch/bin/retroarch32
		elif [ "$UNIT" == "miniloong" ]; then
		  sudo cp Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch32/retroarch32-rgarotated Arkbuild/opt/retroarch/bin/retroarch32
		elif [ "$CHIPSET" == "rk3566" ]; then
		  sudo cp Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch32/retroarch32 Arkbuild/opt/retroarch/bin/retroarch32
		else
		  sudo cp Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch32/retroarch32.${CHIPSET}.unrot Arkbuild/opt/retroarch/bin/retroarch32
		fi
		sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch/gfx/video_filters/*.so Arkbuild/home/ark/.config/retroarch32/filters/video/
		sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch/gfx/video_filters/*.filt Arkbuild/home/ark/.config/retroarch32/filters/video/
		sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch/libretro-common/audio/dsp_filters/*.so Arkbuild/home/ark/.config/retroarch32/filters/audio/
		sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch/libretro-common/audio/dsp_filters/*.dsp Arkbuild/home/ark/.config/retroarch32/filters/audio/
		if [ -f "Arkbuild_package_cache/${CHIPSET}/retroarch32_${UNIT}.tar.gz" ]; then
	      sudo rm -f Arkbuild_package_cache/${CHIPSET}/retroarch32_${UNIT}.tar.gz
		fi
		if [ -f "Arkbuild_package_cache/${CHIPSET}/retroarch32_${UNIT}.commit" ]; then
	      sudo rm -f Arkbuild_package_cache/${CHIPSET}/retroarch32_${UNIT}.commit
		fi
		sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/retroarch32_${UNIT}.tar.gz Arkbuild/opt/retroarch/bin/retroarch32 Arkbuild/home/ark/.config/retroarch32/ Arkbuild/usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.${extension} Arkbuild/usr/lib/arm-linux-gnueabihf/librga.so* Arkbuild/usr/lib/arm-linux-gnueabihf/libgo2.so* Arkbuild/usr/lib/arm-linux-gnueabihf/${whichmali} Arkbuild/usr/lib/arm-linux-gnueabihf/{libEGL.so,libEGL.so.1,libEGL.so.1.1.0,libGLES_CM.so,libGLES_CM.so.1,libGLESv1_CM.so,libGLESv1_CM.so.1,libGLESv1_CM.so.1.1.0,libGLESv2.so,libGLESv2.so.2,libGLESv2.so.2.0.0,libGLESv2.so.2.1.0,libGLESv3.so,libGLESv3.so.3,libgbm.so,libgbm.so.1,libgbm.so.1.0.0,libmali.so,libmali.so.1,libMaliOpenCL.so,libOpenCL.so,libwayland-egl.so,libwayland-egl.so.1,libwayland-egl.so.1.0.0,libMali.so}
		sudo curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/retroarch.sh | grep -oP '(?<=tag=").*?(?=")' > Arkbuild_package_cache/${CHIPSET}/retroarch32_${UNIT}.commit
	fi
	sudo cp retroarch32/configs/retroarch.cfg.${UNIT} Arkbuild/home/ark/.config/retroarch32/retroarch.cfg
	sudo cp retroarch32/configs/retroarch.cfg.spectate Arkbuild/home/ark/.config/retroarch32/retroarch.cfg.spectate
	sudo cp retroarch32/configs/retroarch.cfg.bak.${UNIT} Arkbuild/home/ark/.config/retroarch32/retroarch.cfg.bak
	sudo cp retroarch32/configs/retroarch-core-options.cfg.${UNIT} Arkbuild/home/ark/.config/retroarch32/retroarch-core-options.cfg
	sudo cp retroarch32/configs/retroarch-core-options.cfg.bak.${UNIT} Arkbuild/home/ark/.config/retroarch32/retroarch-core-options.cfg.bak
	sudo cp retroarch32/configs/controller/*.cfg Arkbuild/home/ark/.config/retroarch32/autoconfig/udev/
	sudo cp retroarch32/scripts/retroarch32 Arkbuild/usr/local/bin/
	sudo cp retroarch32/scripts/retroarch32.sh Arkbuild/opt/cmds
	call_chroot "chown -R ark:ark /opt/"
	sudo chmod 777 Arkbuild/opt/cmds/*
	sudo chmod 777 Arkbuild/usr/local/bin/retroarch32
	sudo chmod 777 Arkbuild/opt/retroarch/bin/*
	# Add cores requested from retroarch_cores32
	if [ "$CHIPSET" == "rk3326" ]; then
	  CORE_REPO="master"
	else
	  CORE_REPO="rg503"
	fi
	ARCH="arm7hf"
	sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/cores
	while read RETROARCH_CORE32; do
	  if [[ ! "$RETROARCH_CORE32" =~ ^# ]]; then
		echo -e "Adding ${RETROARCH_CORE32} libretro core\n"
		wget --retry-connrefused --retry-on-http-error=429 --waitretry=20 -t 65 -T 30 --no-check-certificate https://github.com/christianhaitian/retroarch-cores/raw/"$CORE_REPO"/"$ARCH"/"$RETROARCH_CORE32"_libretro.so.zip -O /dev/shm/"$RETROARCH_CORE32"_libretro.so.zip
		if [ $? -eq 0 ]; then
		  sudo unzip -o /dev/shm/"$RETROARCH_CORE32"_libretro.so.zip -d Arkbuild/home/ark/.config/retroarch32/cores/
		  rm -f /dev/shm/"$RETROARCH_CORE32"_libretro.so.zip
		  printf "\n  ${RETROARCH_CORE32} libretro has now been added!\n"
		else
		  printf "\n  ${RETROARCH_CORE32} libretro was not added!\n"
		fi
		sudo wget --retry-connrefused --retry-on-http-error=429 --waitretry=20 -t 65 -T 30 --no-check-certificate https://github.com/libretro/libretro-core-info/raw/refs/heads/master/"$RETROARCH_CORE32"_libretro.info -O Arkbuild/home/ark/.config/retroarch32/cores/"$RETROARCH_CORE32"_libretro.info
		if [ $? -ne 0 ]; then
		  if [ -f "core_info_files/${RETROARCH_CORE32}_libretro.info" ]; then
			sudo cp core_info_files/"$RETROARCH_CORE32"_libretro.info Arkbuild/home/ark/.config/retroarch32/cores/"$RETROARCH_CORE32"_libretro.info
		  fi
		fi
	  fi
	  sleep 5
	done <retroarch_cores32.txt

	# Copy other core info files not available from libretro's repo
	sudo cp core_info_files/* Arkbuild/home/ark/.config/retroarch32/cores/

	# Download and add retroarch assets
	sudo git clone --depth=1 https://github.com/libretro/retroarch-assets.git Arkbuild/home/ark/.config/retroarch32/assets/
	sudo find Arkbuild/home/ark/.config/retroarch32/assets/ -maxdepth 1 ! -name assets \
																	  ! -name glui \
																	  ! -name nxrgui \
																	  ! -name ozone \
																	  ! -name pkg \
																	  ! -name rgui \
																	  ! -name sounds \
																	  ! -name switch \
																	  ! -name xmb \
																	  ! -name COPYING -type d,f -not -path '.' -exec rm -rf {} +

	# Download and add retroarch shaders
	sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/shaders/shaders_glsl
	sudo git clone --depth=1 https://github.com/libretro/glsl-shaders.git Arkbuild/home/ark/.config/retroarch32/shaders/shaders_glsl/
	sudo rm -f Arkbuild/home/ark/.config/retroarch32/shaders/shaders_glsl/{configure,Makefile}
	sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/shaders/shaders_glsl/Sharp-Shimmerless
	sudo git clone --depth=1 https://github.com/Woohyun-Kang/Sharp-Shimmerless-Shader.git Arkbuild/home/ark/.config/retroarch32/shaders/shaders_glsl/Sharp-Shimmerless/
	sudo rm -rf Arkbuild/home/ark/.config/retroarch32/shaders/shaders_glsl/Sharp-Shimmerless/shaders_slang/
	sudo mv Arkbuild/home/ark/.config/retroarch32/shaders/shaders_glsl/Sharp-Shimmerless/shaders_glsl/* Arkbuild/home/ark/.config/retroarch32/shaders/shaders_glsl/Sharp-Shimmerless/
	sudo rm -rf Arkbuild/home/ark/.config/retroarch32/shaders/shaders_glsl/Sharp-Shimmerless/shaders_glsl/
fi
call_chroot "chown -R ark:ark /home/ark/.config/"
