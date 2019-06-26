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


echo

CORENAME=m2pvpk

HFILE=$1
if [ "${HFILE}" = "help" ] ; then 
  echo "Usage: m2pvpk_mpb_preprocess.bash h5datafile [r|i]"
  exit
fi

SPREFIX=

ELABEL="${CORENAME}_mpb(${HFILE})"

TESTFILE=${HFILE#run-}
if [ "${HFILE}" != "${TESTFILE}" ] ; then 
  SPREFIX=run-
  echo ${ELABEL}: found \"run-\" prefix on $HFILE, set SPREFIX=$SPREFIX
else
  SPREFIX=
fi

if [ ! -f "${HFILE}" ] ; then 
  echo ${ELABEL}: exact filename ${HFILE} not found, adding run- prefix and recheck
  HFILE="run-"${HFILE}
  if [ ! -f "${HFILE}" ] ; then 
    echo ${ELABEL}:  file ${HFILE} not found, exitting...
    exit 0
  else
    SPREFIX="run-"
    echo ${ELABEL}:  file ${HFILE} found, using that instead; also set SPREFIX=$SPREFIX
  fi
else
  echo ${ELABEL}:  ${HFILE}
fi

DATASET=$2
if [ -z "${DATASET}" ] ; then 
  echo "${ELABEL}: no dataset chosen [typically \"r\" or \"i\"], exitting..."
  exit 0
else
  echo ${ELABEL}:  ${DATASET}
  DATAPREX=$(echo ${DATASET} | awk -F- '{print$1}')
  echo ${ELABEL}:  data prefix is ${DATAPREX}
  DATAPOST=$(echo ${DATASET} | awk -F- '{print$2}')
  if [ -n "${DATAPOST}" ] ; then 
    DATAPOST="-"${DATAPOST}
    echo ${ELABEL}:  data postfix is ${DATAPOST}
  fi
fi

# / / / 

AXESFILE=MPB.axes
if [ ! -f $AXESFILE ] ; then 
  AXESFILE=../$AXESFILE
fi
if [ -f ${AXESFILE} ] ; then 
  QAXES=$(awk -F: '{print$2}' $AXESFILE)
  QAXES=$(echo ${QAXES})
  echo "${ELABEL}: NOTICE - $AXESFILE reports:"$(safex_cat MPB.axes)":"${QAXES}
else
  echo "${ELABEL}: NOTICE - no $AXESFILE report"
  XTEST=$(safex_treecat P.mpi)
  QAXES=
  if [ -n "${XTEST}" ] ; then 
    echo "${ELABEL}: NOTICE - found P.mpi of "$XTEST
    if [ "${XTEST}" = "0" ] ; then
      QAXES="x y z"
      echo "${ELABEL}: assume no MPI axis swap since P.mpi = "$XTEST
    fi 
  fi 
  if [ -z "${QAXES}" ] ; then 
    QAXES="y x z"
    echo "${ELABEL}: assume MPI has swapped to "$QAXES
  fi
fi
if [ "${QAXES}" = "y x z" ] ; then 
  echo "${ELABEL}: NOTICE - found report of mpb-mpi being run, assume standard mpb-mpi swap: "${QAXES}
  QMPIAXESWAP="true"
elif [ "${QAXES}" != "x y z" ] ; then 
  echo "${ELABEL}: ERROR - unknown axis swap type - IGNORING!"
  QMPIAXESWAP="false"
else
  QMPIAXESWAP="false"
fi

# ----------------------------------------------------------------------
# Get the k (wavevector) data
#
KVECTOR=$(h5dump -d "Bloch wavevector"  $HFILE| grep : | awk -F: '{print$2}')
KVECTOX=$(echo $KVECTOR | awk -F, '{print$1}')
KVECTOY=$(echo $KVECTOR | awk -F, '{print$2}')
KVECTOZ=$(echo $KVECTOR | awk -F, '{print$3}')
echo "${ELABEL}: Bloch wavevector: ${KVECTOR}:   ${KVECTOX},${KVECTOY},${KVECTOZ}"

# Calculate the number of periods needed to get a full oscillation cycle in, 
#  but stop at 10 to keep datafiles to minimum
#
#  nb: the trailing "1" is nth decimal and hence negligible
#      but saves me an if-empty-string check

NPPMAX=32
N5X=$(echo "scale=3; 0.5 / ${KVECTOX} " | bc -l 2>/dev/null)1
N5X=$(echo "if (${N5X}>${NPPMAX}) ${NPPMAX} else ${N5X}"  | bc -l 2>/dev/null)

N5Y=$(echo "scale=3; 0.5 / ${KVECTOY} " | bc -l 2>/dev/null)1
N5Y=$(echo "if (${N5Y}>${NPPMAX}) ${NPPMAX} else ${N5Y}"  | bc -l 2>/dev/null)

N5Z=$(echo "scale=3; 0.5 / ${KVECTOZ} " | bc -l 2>/dev/null)1
N5Z=$(echo "if (${N5Z}>${NPPMAX}) ${NPPMAX} else ${N5Z}"  | bc -l 2>/dev/null)

echo ${ELABEL}: "Bloch wavevector k-data: h5_periods ${N5X}, ${N5Y}, ${N5Z}"

#
#
#- - - - - - - - - - 

# . . . . . . . . . . . . 
# define longitudinal and transverse coordinates
#
echo ${ELABEL}: "NOTICE - uppercase axes (XYZ) are geometric, lower (xyz) are mpb equivalents"
CI_L0=$(safex_treecat P.longitudinal)
if [ -z "${CI_L0}" ] ; then 
  CI_L0=X
  echo "${ELABEL}: using default longitudinal = "${CI_L0}
else
  echo "${ELABEL}: using defined P.longitudinal = "${CI_L0}
fi

  case "${CI_L0}" in
    "X")  CI_L0=x; CI_T1=y; CI_T2=z;;
    "Y")  CI_L0=y; CI_T1=z; CI_T2=x;;
    "Z")  CI_L0=z; CI_T1=x; CI_T2=y;;
    *) echo ${ELABEL}: bad CI_L0=${CI_L0}; exit;;
  esac

echo ${ELABEL}: "Selected longitudinal axis is lg:${CI_L0}"
echo ${ELABEL}: "Selected transverse  axes are t1:${CI_T1}, t2:${CI_T2}"

XNAME=${HFILE%.h5}
XFILE=${XNAME}.${DATASET}.xdmf
XINFO=hdf5-xdmf.info

if [ -f "${XFILE}" ] ; then 
  mv ${XFILE} old/
fi
if [ -f "${XINFO}" ] ; then 
  mv ${XINFO} old/
fi

#- - - - - - - - - - 
echo ${ELABEL}:  
echo ${ELABEL}:  Now to make the derived datasets 

# . . . . . . 
# add some simple data

    WVALUE=$(h5dump -d "description" ${HFILE} | grep :  | awk -F: '{print$2}' | sed 's/"//g' | awk -F= '{print$2}')
    echo -n "${ELABEL}: add frequency and k data: ${WVALUE}: ${KVECTOX}, ${KVECTOY}, ${KVECTOZ}"
    h5math -e "${WVALUE}"  -a -n 1 -d frequency ${HFILE}
    h5math -e "${KVECTOX}" -a -n 1 -d kx       ${HFILE}
    h5math -e "${KVECTOY}" -a -n 1 -d ky       ${HFILE}
    h5math -e "${KVECTOZ}" -a -n 1 -d kz       ${HFILE}
    echo "."


# . . . . . . 
# add permittivity data
    HFILE_EPS=epsilon.h5
    DNAME_EPS=epsilon.xx
    D5SEP_EPS=${DNAME_EPS}
    D5SET_EPS=${DNAME_EPS}

    #echo -n ${ELABEL}: "make permittivity data"
    h5math -e "d1"              -d ${D5SET_EPS} -a ${HFILE}           ${HFILE_EPS}:${D5SEP_EPS}
    HFILE_EPS=${HFILE}
    #echo "."

    #echo ${ELABEL}: ${DNAME_EPS} data is in ${HFILE_EPS}:/${D5SET_EPS}


# . . . . . . 
# add transverse field data
    DNAME_ET=Et
    HFILE_ET=${HFILE}
    D5SEP_ET=${DNAME_ET}.${DATAPREX}
    D5SET_ET=${DNAME_ET}.${DATASET}
    CALC_ET="sqrt(d1*d1+d2*d2)"

    #echo -n ${ELABEL}: "make transverse field data"
    XXMAKEET="${HFILE}:${CI_T1}.${DATAPREX} ${HFILE}:${CI_T2}.${DATAPREX}"
    h5math -e "${CALC_ET}" -d ${D5SET_ET} -a ${HFILE} ${XXMAKEET}
    #echo "."

    echo ${ELABEL}:  ${DNAME_ET} data is in ${HFILE_ET}:/${D5SET_ET}

# . . . . . . 
# add longitudinal fraction data
    HFILE_ANG=${HFILE}
    DNAME_ANG=aL
    D5SEP_ANG=${DNAME_ANG}.${DATAPREX}
    D5SET_ANG=${DNAME_ANG}.${DATASET}
    CALC_ANG="d1*d1/(d1*d1+d2*d2+d3*d3+1.0e-10)"

    #echo -n ${ELABEL}: "make longitudinal fraction data"
    XXMAKEAL="${HFILE}:${CI_L0}.${DATAPREX} ${HFILE}:${CI_T1}.${DATAPREX} ${HFILE}:${CI_T2}.${DATAPREX}"
    h5math -e "${CALC_ANG}" -d ${D5SET_ANG} -a ${HFILE} ${XXMAKEAL}
    #echo "."

    echo ${ELABEL}:  ${DNAME_ANG} data is in ${HFILE_ANG}:/${D5SET_ANG}

# . . . . . . 

if [ ! -f geom.h5 ] ; then 
  # make some dummy data as a drop-in, in case of missing files later
  h5math -e "0.00*d1"      -d zero geom.h5 ${HFILE}:x.${DATASET}
  h5math -e "0.00*d1+1" -a -d unit geom.h5 ${HFILE}:x.${DATASET}
fi

# . . . . . . 
# . . . . . . 
# data reprocessing - periodicity and resampling...

DATASET_RESAMPLE=yes

XH5RESAMPLE=$(safex_treecat P.resample)
XM_RESAMPLE=
if [ -z "${XH5RESAMPLE}" ] ; then 
  XH5RESAMPLE=32
  # echo ${ELABEL}: fallback resampling value: $XH5RESAMPLE
else
  echo ${ELABEL}: specific local resampling request: $XH5RESAMPLE
  XM_RESAMPLE=" -x ${N5X} -y ${N5Y} -z ${N5Z} -n ${XH5RESAMPLE} "
fi

if [ "${DATASET_RESAMPLE}" = "yes" ] ; then 
  if [ "${QMPIAXESWAP}" = "true" ] ; then 
    FIXAXES=" -T "
  else
    FIXAXES=
  fi

  echo ${ELABEL}: "Resample the raw data in ${HFILE} with h5_resample=${XM_RESAMPLE} and FIXAXES=${FIXAXES}"
  # do not specify a real or imag postfix so rephasing can be (is) done correctly 
  #   ... except for Et and aL, which are always real
    for IDATA in x y z Et.r aL.r epsilon.xx
    do 
      mpb-data  ${FIXAXES} ${XM_RESAMPLE}  -d ${IDATA}   ${HFILE}
    done
    echo h5_periods: ${XM_RESAMPLE} > ${HFILE%.h5}.nnn

    if [ "${QMPIAXESWAP}" = "true" ] ; then
      # cannot be a BAD_SILENCE thing because "mpb-data -T" doesnt work on "Bloch wavevector"
      h5math -e "${KVECTOY}" -a -n 1 -d kx-new       ${HFILE}
      h5math -e "${KVECTOX}" -a -n 1 -d ky-new       ${HFILE}
      h5math -e "${KVECTOZ}" -a -n 1 -d kz-new       ${HFILE}
      echo "${ELABEL}: Bloch wavevector (updated): ${KVECTOY},${KVECTOX},${KVECTOZ}"
    fi
else
  echo ${ELABEL}: "no resampling requested or done"
fi

# . . . . . . 
# . . . . . . 
# test whether I need the BAD_SILENCE mpb axis swap fixing...
QBADSILENCE=0
if [ -n "${FIXAXES}" ] ; then # mpb-mpi axis swappage was required 
  if [ -f MPB.hostname ] ; then 
    XHOST=$(safex_cat MPB.hostname)
    echo ${ELABEL}: simulation host reported as ${XHOST}
  else
    XHOST=notbroken
    echo ${ELABEL}: simulation host unreported, assuming ${XHOST}
  fi
  # BAD_SILENCE hosts are silence, dlccroft23 (S14.2), and sdz93336lin (prob)
  XXHOST=${XHOST#silence}
  XYHOST=${XXHOST#dlccroft23}
  XZHOST=${XYHOST#sdz93336lin}
  if [ "${XZHOST}" != "{XHOST}" ] ; then # sim was run on silence etc, which requires mystery xy swap
    echo ${ELABEL}: "set flag to indicate BAD_SILENCE compensation needed - axis swap in vector components: XYZ becomes yxz"
    QBADSILENCE=1
  fi
fi 

h5math -e "${QBADSILENCE}"  -a -n 1 -d bad_silence ${HFILE}


echo ${ELABEL}: 
echo
