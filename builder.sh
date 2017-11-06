#!/bin/bash

cd ../

# Setting environment
# ###################
ARCHITECTURES=( ar71xx-tiny ar71xx-generic ar71xx-nand brcm2708-bcm2708 brcm2708-bcm2709 mpc85xx-generic x86-64 x86-generic)
#ARCHITECTURES=( ar71xx-tiny )
BRANCH=stable
#BRANCH=unbranded_stable
#BRANCH=experimental
GLUONVERSION=$(git describe --tags | cut -d "-" -f 1)
SITECOMMIT=$(cd site; git log -1 --format="%H")

#DEBUG="V=s"
DEBUG=""


# Days until the autoupdater makes sure that the new vesion gets installed
# (maybe define based on the branch?)
PRIO=2

# prepare site.conf from template
rm site/site.conf
cp site/site.in site/site.conf                                                  
sed  -i -e "s/AUTOUPDATERBRANCH/$BRANCH/g" site/site.conf

# remove old images to make sure we only upload the new shiny stuff
rm -rf output/images

# update toolchain to current release
make update

RELEASENAME=${GLUONVERSION}-$(date '+%Y%m%d')-${BRANCH}

for ARCHITECTURE in "${ARCHITECTURES[@]}"
do
    echo "#######################################"
    echo "#######################################"
    echo Building $ARCHITECTURE
    echo "#######################################"
    echo "#######################################"

    # Preparing build
    # ###############
    make clean GLUON_TARGET=$ARCHITECTURE $DEBUG -j24

    git reset --hard

    # Applying patches
    # ################
    # (aka patching the gluon-build environment that after that patches the OpenWRT...)
    if [ -d site/patches/ ]; then 
      for f in site/patches/*; do 
        echo $f
        git apply $f 
      done
    fi
    
    
    # Doing the Build
    # ###############
    make all GLUON_TARGET=$ARCHITECTURE $DEBUG -j16 GLUON_RELEASE=${RELEASENAME} GLUON_BRANCH=$BRANCH GLUON_PRIORITY=$PRIO
done

# build manifests
# ###############
make manifest GLUON_BRANCH=$BRANCH GLUON_PRIORITY=${PRIO} GLUON_RELEASE=${RELEASENAME}


# write the current site-commit as into-text
# ###############
(cd site/; git show > ../output/images/commit.txt )

# rename files to match the ffbs-naming conventions
# TODO: give explanation or further resources
(cd output/images/factory; for f in *; do sudo mv "$f" "${f#gluon-ffbs-}"; done )
(cd output/images/factory; for f in *raspberry-pi.img.gz; do echo "${f/raspberry-pi.img.gz/raspberry-pi-1.img.gz}"; done )
(cd output/images/factory; for f in *x86-64*; do echo "${f/x86-64/x86-64-generic}"; done )
