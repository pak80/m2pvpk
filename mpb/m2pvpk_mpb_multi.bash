#!/bin/bash
#-----------------------------------------------------------------------------
# Paul Kinsler 2016+ 
# see https://github.com/pak80/m2pvpk/raw/master/README
# GPLv3.0 see https://github.com/pak80/m2pvpk/raw/master/LICENSE
#-----------------------------------------------------------------------------

safex_cat() {
  XXFILE=$1
  if [ -f "${XXFILE}" ] ; then
    cat ${XXFILE} | sed "s/[[:cntrl:][:punct:]]//g"
  else
    echo $2
  fi
}

safex_treecat() {
  # arg 1 is file to look for
  # arg 2 is default value used when file is not found
  XXFILE=$1
  if [ ! -f "${XXFILE}" ] ; then 
    XXFILE=../${XXFILE}
  fi 
  if [ -f "${XXFILE}" ] ; then 
    cat ${XXFILE} | sed "s/[[:cntrl:][:punct:]]//g"
  else
    echo $2
  fi
}

safe_treecat() {
  # arg 1 is file to look for
  # arg 2 is default value used when file is not found
  XXFILE=$1
  if [ ! -f "${XXFILE}" ] ; then 
    XXFILE=../${XXFILE}
  fi 
  if [ -f "${XXFILE}" ] ; then 
    cat ${XXFILE} | sed "s/[[:cntrl:]]//g"
  else
    echo $2
  fi
}

safex_tree() {
  # arg 1 is file to look for
  # arg 2 is default filename used when file is not found
  XXFILE=$1
  if [ ! -f "${XXFILE}" ] ; then 
    XXFILE=../${XXFILE}
  fi 
  if [ -f "${XXFILE}" ] ; then 
    echo ${XXFILE}
  else
    echo $2 
  fi
}

#-----------------------------------------------------------------------------

locate_data() {
  QFILE=$1
  QNAME=$2
  QTIME=$3
  QTBAK=$4
  SFILE=${QFILE}.${QNAME}.${QTIME}.h5
  if [ -f "${SFILE}" ] ; then 
    # there is a time specific data set so all is ok
    DASET=${QNAME}
  else
    # there is NO time specific data set so look for a static one
    SFILE=${QFILE}.${QNAME}.${QTBAK}.h5
    if [ -f "${SFILE}" ] ; then 
      DASET=${QNAME}
    else
      # there is NO timed or static data set, so set zero
      SFILE=geom.h5
      DASET=zero
    fi
  fi
  echo $SFILE $DASET
}

locate_template() {
  QFILE=$1
  if [ -f "${QFILE}" ] ; then 
    echo $QFILE
  elif [ -f "../${QFILE}" ] ; then 
    echo ../$QFILE
  else
    # (even) if this isn't there, the error wll be caught later
    echo ${HOME}/lib/${QFILE}
  fi
}

    
#-----------------------------------------------------------------------------


echo


CORENAME=m2pvpk
HFILE=e

XSELECT=$1
XCHOICE=$2
XPOSTFIX=$3

if [ -z "${XSELECT}" ] ; then 
  XSELECT=k
  echo "$0: (default) select fixed ${XSELECT}"
elif [ "${XSELECT%h5}" != "${XSELECT}" ] ; then 
  echo "$0 ERROR - arguments are not h5 filenames! "
  XSELECT="help"
fi
if [ "${XSELECT}" = "help" ] ; then 
  echo "Usage: ${CORENAME}_mpb_multi [[k|b] [index] [postfix]"
  echo "$0: k - fix a specific k index and vary bands"
  echo "$0: b - fix a specific band index and vary k"
  echo "$0: defaults are ""k"" and ""01"" "
  exit
fi



if [ -z "${XCHOICE}" ] ; then 
  XCHOICE=01
  echo $0: defaults - ${XSELECT} choice is ${XCHOICE}
fi
if [ -n "${XPOSTFIX}" ] ; then 
  echo $0: h5 data postfixes are ${XPOSTFIX}
  echo $0: beware of BAD_SILENCE
  #echo "$0: ========================================="
  #echo "$0:               W A R N I N G              "
  #echo "$0: ========================================="
  #echo "$0:    no BAD_SILENCE correction is applied  "
  #echo "$0: ========================================="
  #echo "$0: "
fi

ELABEL="${CORENAME}_mpb(${XSELECT}${XCHOICE})"

mkdir -p old
SEDFILE=${HFILE}.sed
echo > ${SEDFILE}
XDMFFILE=${HFILE}.${XSELECT}${XCHOICE}
LOGFILE=${XDMFFILE}.xdmf.log ; mv ${LOGFILE} old/${LOGFILE}

case ${XSELECT} in
    k) KCHOICE=${XCHOICE}
       MEGALIST=$(ls e.k${KCHOICE}.b??.h5 | sed "s/e.k${KCHOICE}.b//" | sed 's/.h5//' )
       echo ${ELABEL}: fake the frame-times using $(echo $MEGALIST | wc -w) bands at selected ${XSELECT}${XCHOICE}
       ;;
    b) BCHOICE=${XCHOICE}
       MEGALIST=$(ls e.k??.b${BCHOICE}.h5 | sed "s/e.k//" | sed "s/.b${BCHOICE}.h5//" )
       echo ${ELABEL}: fake the frame-times using $(echo $MEGALIST | wc -w) k\'s at selected ${XSELECT}${XCHOICE}
       ;;
    *) echo $0: no such selection ${XSELECT}; exit
       ;;
esac

echo "${ELABEL}: [${XSELECT}${XCHOICE}] "$MEGALIST #> ${LOGFILE}

VARLIST=$(safe_treecat P.xdmflist "vector::Electric_field scalar:epsilon.xx:Permittivity")
echo ${ELABEL}: varlist is $VARLIST
echo ${ELABEL}: nb: Paraview swaps axes XYZ to zyx

echo ${ELABEL}: WARNING NOTICE - template processing uses triple underscore to delineate substitutions


  #- - - - - - - - - - 

# pick the first (by sort) h5 file that is lying around and use it to extract/set-up the geometry
# use a sort so that we can be more sure WHICH file will be chosen, in case it matters
  HFILE_ANY=$(ls ${HFILE}*h5 | sort | head -1)
  HFILE_ANYINFO=$(h5ls ${HFILE_ANY} | grep \\\.r${XPOSTFIX}" " | tail -1)
  HFILE_ANYDASET=$(echo ${HFILE_ANYINFO} | awk '{print$1}' )
  echo ${ELABEL}: extracting geometry from $HFILE_ANY and dataset $HFILE_ANYDASET

  GRIDPOINTS=$(echo ${HFILE_ANYINFO} | awk -F\{ '{print$2}' | awk -F\} '{print$1}' | sed 's/,/ /g' | head -1)
  GRIDPVXX=$(echo ${GRIDPOINTS} | awk '{print$1}')
  GRIDPVYY=$(echo ${GRIDPOINTS} | awk '{print$2}')
  GRIDPVZZ=$(echo ${GRIDPOINTS} | awk '{print$3}') 

  GRIDOFFX=$(echo "-(${GRIDPVXX}-1)/2" | bc -l)
  GRIDOFFY=$(echo "-(${GRIDPVYY}-1)/2" | bc -l)
  GRIDOFFZ=$(echo "-(${GRIDPVZZ}-1)/2" | bc -l)

  XXXTOPOLOG=3DCORECTMesh
  XXXGEOMETRY=ORIGIN_DXDYDZ
  XXXGRIDDIMS=3

  XXXGRIDNAME=${HFILE}
  XXXGRIDXYZ=${GRIDPOINTS}
  XXXGRIDORIGIN=" ${GRIDOFFX} ${GRIDOFFY} ${GRIDOFFZ} "
  XXXGRIDSPACING="1.00 1.00 1.00"
  XXXGRIDFILE=${HFILE}

  echo "
s/___GRIDNAME___/${XXXGRIDNAME}/
s/___GRIDTOPOLOGY___/${XXXTOPOLOG}/
s/___GRIDGEOMETRY___/${XXXGEOMETRY}/
s/___GRIDXYZ___/${XXXGRIDXYZ}/g
s/___GRIDDIMS___/${XXXGRIDDIMS}/
s/___GRIDORIGIN___/${XXXGRIDORIGIN}/
s/___GRIDSPACING___/${XXXGRIDSPACING}/
s/___GRIDFILE___/${XXXGRIDFILE}/g" >> ${SEDFILE}

#- - - - - - - - - - 
if [ ! -f geom.h5 ] ; then 
  # make some dummy data as a drop-in, in case of missing files later
  h5math -e "0.00*d1"      -d zero geom.h5 ${HFILE_ANY}:${HFILE_ANYDASET}
  h5math -e "0.00*d1+1" -a -d unit geom.h5 ${HFILE_ANY}:${HFILE_ANYDASET}
fi

TIMELISTRAW=$(echo $MEGALIST)
TIMELIST=$TIMELISTRAW
TIMEDIM=$(echo $TIMELIST | wc -w)

  echo "
s/___TIMELIST___/${TIMELIST}/
s/___TIMEDIM___/${TIMEDIM}/" >> ${SEDFILE}


FTEMPLATE=$(locate_template ${CORENAME}.head.template)
if [ ! -f "${FTEMPLATE}" ] ; then 
  echo ${ELABEL}:  no head template ${FTEMPLATE}
  exit
else
  sed -f ${SEDFILE} ${FTEMPLATE} > ${XDMFFILE}.xdmf
fi


echo -n ${ELABEL}: processing
ITT=0
for TT in $TIMELISTRAW
do
  ITT=$(( ${ITT} + 1 ))
  /bin/echo -n .

  case ${XSELECT} in
     k) BCHOICE=${TT} ;;
     b) KCHOICE=${TT} ;;
     *) echo $0: no such choice ${XSELECT}; exit;;
  esac

  # set up the time label (this bit only needs TIMEINDEX)
  FTEMPLATE=$(locate_template ${CORENAME}.framehead.template)
  INFO_T=$( locate_data ${HFILE} k${KCHOICE} b${BCHOICE} DNX | awk '{print$1}')
  TNAME=$(h5dump -d "description" ${INFO_T} | grep :  | awk -F: '{print$2}' | sed 's/"//g')
  sed  "s/___TIMENAME___/${TNAME}/" $FTEMPLATE >> ${XDMFFILE}.xdmf 

  HSET_X=x.r${XPOSTFIX}
  HSET_Y=y.r${XPOSTFIX}
  HSET_Z=z.r${XPOSTFIX}
  # cope with BAD_SILENCE problem (needed only if -new data)
  if [ "qq${XPOSTFIX}" = "qq-new" ] ; then 
    BAD_SILENCE=$(h5dump -d "bad_silence" ${INFO_T} | grep :  | awk -F: '{print$2}' | sed 's/ //g' )
    if [ "${BAD_SILENCE}" = 1 ] ; then 
      echo "${ELABEL}: ${TT}: Note - BAD_SILENCE fix applied since flag value is ${BAD_SILENCE} and postfix is ${XPOSTFIX}" >> $LOGFILE
      HSET_X=y.r${XPOSTFIX}
      HSET_Y=x.r${XPOSTFIX}
      HSET_Z=z.r${XPOSTFIX}
    else
      if [ -z "${BAD_SILENCE}" ] ; then 
        echo "${ELABEL}: ${TT}: No BAD_SILENCE flag found, assuming not necessary" >> $LOGFILE
      fi
    fi
  fi
  echo ${ELABEL}: ${TT}: vector h5 dataset labels used are: px=${HSET_X} py=${HSET_Y} pz=${HSET_Z} >> $LOGFILE


  ## - - -
  ## automatically add frequency scalar
  XXFREQ=$(echo ${TNAME} | awk -F= '{print$2}')
         cp ${SEDFILE} ${SEDFILE}.t
         echo "
s/___DFORMAT___/XML/
s/___DDIMS___/1/
s/___SCALARNAME___/frequency/
s/___SCALARDATA___/${XXFREQ}/"  >> ${SEDFILE}.t
         FTEMPLATE=$(locate_template ${CORENAME}.scalar1.template)
         if [ ! -f "${FTEMPLATE}" ] ; then 
           echo ${ELABEL}:  no frame template $II $ITT
           exit
         else
           sed -f ${SEDFILE}.t ${FTEMPLATE} >> ${XDMFFILE}.xdmf
         fi
  ## - - -

  for VVV in $VARLIST
  do
     VTYPE=$( echo $VVV | awk -F: '{print$1}')
     VNAME=$( echo $VVV | awk -F: '{print$2}')
     VLABEL=$(echo $VVV | awk -F: '{print$3}')

     # currently this requires individual h5 files at each time point
     #  but in future (if) I can specify file:set[pos;strides] in the xdmf -
     #  as per h5ls/h5dump - then unitary multi-time files could be used.
     case $VTYPE in
       vector)
         INFO_X=$( locate_data ${HFILE} k${KCHOICE} b${BCHOICE} DNX )
           HFILE_X=$(echo $INFO_X | awk '{print$1}')
           DASET_X=${VNAME}${HSET_X}
         INFO_Y=$( locate_data ${HFILE} k${KCHOICE} b${BCHOICE} DNX )
           HFILE_Y=$(echo $INFO_Y | awk '{print$1}')
           DASET_Y=${VNAME}${HSET_Y}
         INFO_Z=$( locate_data ${HFILE} k${KCHOICE} b${BCHOICE} DNX )
           HFILE_Z=$(echo $INFO_Z | awk '{print$1}')
           DASET_Z=${VNAME}${HSET_Z}
         DAFORMAT=HDF

         echo ${ELABEL}:  $VTYPE for ${TT} is ${HFILE_X}:${DASET_X} ${HFILE_Y}:${DASET_Y} ${HFILE_Z}:${DASET_Z} >> $LOGFILE

         # needs some of the global info
         cp ${SEDFILE} ${SEDFILE}.t
         echo "
s/___TIMEINDEX___/${ITT}/
s/___DFORMAT___/${DAFORMAT}/
s/___VECTORNAME___/${VLABEL}/
s/___VECTORDATAX___/${HFILE_X}:${DASET_X}/
s/___VECTORDATAY___/${HFILE_Y}:${DASET_Y}/
s/___VECTORDATAZ___/${HFILE_Z}:${DASET_Z}/"  >> ${SEDFILE}.t

         FTEMPLATE=$(locate_template ${CORENAME}.vector.template)
         if [ ! -f "${FTEMPLATE}" ] ; then 
           echo ${ELABEL}:  no frame template $II $ITT
           exit
         else
           sed -f ${SEDFILE}.t ${FTEMPLATE} >> ${XDMFFILE}.xdmf
         fi
       ;;
       scalar)
         INFO_S=$( locate_data ${HFILE} k${KCHOICE} b${BCHOICE} DNX )
           HFILE_S=$(echo $INFO_S | awk '{print$1}')
           DASET_S=${VNAME}${XPOSTFIX}
           XFOUND=$(h5ls ${HFILE_S} | grep ${DASET_S})
           if [ -z "${XFOUND}" ] ; then
             # field with ${XPOSTFIX} not found, so try without
             DASET_S=${VNAME}
           fi
           DAFORMAT=HDF

         echo ${ELABEL}:  $VTYPE for ${TT} is ${HFILE_S}:${DASET_S} >> $LOGFILE

         # needs some of the global info
         cp ${SEDFILE} ${SEDFILE}.t
         echo "
s/___TIMEINDEX___/${ITT}/
s/___DFORMAT___/${DAFORMAT}/
s/___SCALARNAME___/${VLABEL}/
s/___SCALARDATA___/${HFILE_S}:${DASET_S}/"  >> ${SEDFILE}.t

         FTEMPLATE=$(locate_template ${CORENAME}.scalar.template)
         if [ ! -f "${FTEMPLATE}" ] ; then 
           echo ${ELABEL}:  no frame template $II $ITT
           exit
         else
           sed -f ${SEDFILE}.t ${FTEMPLATE} >> ${XDMFFILE}.xdmf
         fi
       ;;
       *)
         echo ${ELABEL}: no such variable type $VVV $II $ITT
       esac

  done

  FTEMPLATE=$(locate_template ${CORENAME}.frametail.template)
  cat $FTEMPLATE >> ${XDMFFILE}.xdmf

done





  echo # no more progress dots needed

  FTEMPLATE=$(locate_template ${CORENAME}.tail.template)
  if [ ! -f "${FTEMPLATE}" ] ; then 
    echo ${ELABEL}:  no tail template ${FTEMPLATE}
    exit 
  else
    cat ${FTEMPLATE} >> ${XDMFFILE}.xdmf
  fi

echo ${ELABEL}: 
echo ${ELABEL}: log file    is ${LOGFILE}
echo ${ELABEL}: output file is ${XDMFFILE}.xdmf
echo ${ELABEL}: 
echo
