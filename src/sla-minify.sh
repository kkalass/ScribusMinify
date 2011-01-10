#!/bin/bash
#
# Script zum Verkleinern von Bildern in Scribus Dateien, so dass
# sie nur noch den gegebenen Skalierungsfaktor aufweisen
# 

FILENAME=$1
TARGET_DIR=$2
TARGET_SCALE_FACTOR=$3

TARGET_IMG_DIR=img

if [ -z "$FILENAME" ] || [ -z "$TARGET_DIR" ] || [ -z "$TARGET_SCALE_FACTOR" ]; then
  echo "usage:"
  echo "$0 <FILENAME> <TARGET_DIR> <TARGET_SCALE_FACTOR>"
  echo ""
  echo "example: $0 myfile.sla build/minified/ 0.20"
  echo "  scale: 0.20 ==> 360 dpi"
  echo "  scale: 0.24 ==> 300 dpi"
  exit -1
fi


#
# Get the new, scaled Resolution
#
# $1 - res - The old Resolution
# $2 - scale - the old scale factor
# $3 - targetscale - the target scale factor
# $4 - bcscale - the scale to give to bc
#
# @return: the new, scaled down resolution
#
function scaleResolution {
  local res=$1
  local scale=$2
  local targetscale=$3
  local bcscale=$4
  echo "scale=$bcscale;($res*${scale})/$targetscale" | bc
}

#
# Get the new Geometry String for scaling the given Image to the given factors
#
# $1 - img - the image to scale
# $2 - oldScaleX - the old factor in X dimension
# $3 - oldScaleY - the old factor in Y dimension
# $4 - targetscale
function getNewResolution {
  local img="$1"
  local oldScaleX=$2
  local oldScaleY=$3
  local targetscale=$4
  local resString=`identify "$img"  | cut -f3 -d " "  `
  local oldResX=`echo $resString|cut -d "x" -f1`
  local newResX=`scaleResolution $oldResX $oldScaleX $targetscale 0`
  local oldResY=`echo $resString|cut -d "x" -f2`
  local newResY=`scaleResolution $oldResY $oldScaleY $targetscale 0`
  echo ${newResX}x${newResY}+0+0
}

#
# get the value of the specified attribute name 
# $1 line
# $2 attrname
function getAttribute {
  local line=$1
  local attrname=$2
  echo $line | sed -n "s/.*${attrname}=\"\([^\"]*\).*/\1/gp"
}

function minify {
  local filename=$1
  local targetdir=$2
  local targetscale=$3
  local targetfile="$targetdir/"`basename "$filename"`
  local srcdirname=`dirname "$filename"`

  # prepare filesystem
  [ -d $targetdir ] || mkdir -p $targetdir
  [ -d "$targetdir/$TARGET_IMG_DIR" ]  || mkdir -p $targetdir/$TARGET_IMG_DIR

  echo "Will minify $filename to $targetfile"
  # remove target, if it exists already
  rm -f "$targetfile"

  (while read line ; do 
    if echo $line | grep -q "PFILE=\"[^\"]\+\"" ; then  
      local imgfile=`getAttribute "$line" PFILE`
      local scaleX=`getAttribute "$line" LOCALSCX`
      local scaleY=`getAttribute "$line" LOCALSCY`
      local localX=`getAttribute "$line" LOCALX`
      local localY=`getAttribute "$line" LOCALY`
      local newlocalx=`scaleResolution $localX $scaleX $targetscale 12`
      local newlocaly=`scaleResolution $localY $scaleY $targetscale 12`
      local resString=`getNewResolution "$srcdirname/$imgfile" $scaleX $scaleY $targetscale`
      local newimagename="$TARGET_IMG_DIR/$resString-"`basename "$imgfile"`
     
      echo "Scaling down $imgfile"
      
      convert -scale "$resString" "$srcdirname/$imgfile" "$targetdir/$newimagename"

      echo $line | sed "s#LOCALSCX=\"[^\"]*\"#LOCALSCX=\"${targetscale}\"#g;\
                        s#LOCALSCY=\"[^\"]*\"#LOCALSCY=\"${targetscale}\"#g;\
                        s#LOCALX=\"[^\"]*\"#LOCALX=\"${newlocalx}\"#g;\
                        s#LOCALY=\"[^\"]*\"#LOCALY=\"${newlocaly}\"#g;\
                        s#PFILE=\"[^\"]*\"#PFILE=\"${newimagename}\"#g\
                        " >> "$targetfile"
      #echo "$scaleX  $scaleY  $imgfile "
    else
      echo $line >> "$targetfile"
    fi; 
  done) < "$filename"
}

#
# main
#
minify "$FILENAME" "$TARGET_DIR" $TARGET_SCALE_FACTOR
