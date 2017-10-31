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

rm site/site.conf
cp site/site.in site/site.conf                                                  
sed  -i -e "s/AUTOUPDATERBRANCH/$BRANCH/g" site/site.conf

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
