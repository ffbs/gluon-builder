#!/bin/bash

set -e

cd ../

# Setting environment
# ###################
ARCHITECTURES=( ar71xx-tiny ar71xx-generic ar71xx-nand brcm2708-bcm2708 brcm2708-bcm2709 mpc85xx-generic x86-64 x86-generic)
#ARCHITECTURES=( ar71xx-tiny )
#BRANCH=stable
#BRANCH=unbranded_stable
BRANCH=experimental
#BRANCH=beta

# prepare needed strings
GLUONVERSION=$(git describe --tags | cut -d "-" -f 1)
SITECOMMIT=$(cd site; git log -1 --format="%H")
ARCHSTRING=multiarch
if [ "${#ARCHITECTURES[@]}" -eq "1" ]; then
  ARCHSTRING=${ARCHITECTURES[0]}
fi
RELEASENAME=${GLUONVERSION}-$(date '+%Y%m%d%H%M')-${BRANCH}
RELEASETAG=ffbs_${GLUONVERSION}_${BRANCH}_${ARCHSTRING}_$(date '+%Y%m%d-%H%M')_${SITECOMMIT}

echo $RELEASETAG

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
    make all GLUON_TARGET=$ARCHITECTURE $DEBUG -j16 GLUON_RELEASE=${RELEASENAME} GLUON_BRANCH=$BRANCH GLUON_PRIORITY=$PRIO GLUON_ATH10K_MESH=ibss

    echo Exiting with Code $?
done

# build manifests
# ###############
make manifest GLUON_BRANCH=$BRANCH GLUON_PRIORITY=${PRIO} GLUON_RELEASE=${RELEASENAME}


# write the current site-commit as into-text
# ###############
(cd site/; git show > ../output/images/commit.txt )

# shorten resulting image names for some TP-Link routers
(cd output/images/factory; for f in *; do mv "$f" "${f#gluon-ffbs-}"; done )

# rename files to match the ffbs-naming conventions
# TODO: give explanation or further resources
(cd output/images/factory; for f in *raspberry-pi.img.gz; do mv "$f" "${f/raspberry-pi.img.gz/raspberry-pi-1.img.gz}"; done )

(cd output/images/factory; for f in *x86-64.vmdk; do mv "$f" "${f/.vmdk/-vmware.vmdk}"; done )
(cd output/images/factory; for f in *x86-64.vdi; do mv "$f" "${f/.vdi/-virtualbox.vdi}"; done )
(cd output/images/factory; for f in *x86-64.img.gz; do mv "$f" "${f/.img.gz/-generic.img.gz}"; done )

(cd output/images/factory; for f in *x86-generic.vmdk; do mv "$f" "${f/x86-generic/x86-vmware}"; done )
(cd output/images/factory; for f in *x86-generic.vdi; do mv "$f" "${f/x86-generic/x86-virtualbox}"; done )

# rename image dir to represent build
mv output/images "output/${RELEASETAG}"
