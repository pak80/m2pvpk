#!/bin/bash
# Paul Kinsler 2016+
#
echo "$0: This script simply makes some links in the home directories"
echo "    bin and lib to the actual location of the files - i.e. where"
echo "    this script is run from."

CORENAME=m2pvpk
echo -n "$0/${CORENAME}:"

IIC=0
DIE=$(pwd)
for DDD in lib meep mpb 
do
  cd ${DDD}
  XDIR=$(pwd)
  echo -n " $DDD"
  if [ ${DDD} != "lib" ] ; then 
    DDR=bin
  else
    DDR=lib
  fi
  for III in *
  do
    echo -n "."
    IIC=$(( ${IIC} + 1 ))
    ln -sf ${XDIR}/${III} ~/${DDR}/
  done
  cd ${DIE}
done

echo 
echo $0/${CORENAME}: ${IIC} files copied
