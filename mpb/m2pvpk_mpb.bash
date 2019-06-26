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
  QDSET=$3
  QTIME=$4
  QTBAK=$5

  SFILE=${QFILE}-${QNAME}-${QTIME}.h5
  if [ -f "${SFILE}" ] ; then 
    # there is a time specific data set so all is ok
    DASET=${QDSET}
  else
    # there is NO time specific data set so look for a static one
    SFILE=${QFILE}-${QNAME}-${QTBAK}.h5
    if [ -f "${SFILE}" ] ; then 
      DASET=${QDSET}
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


CORENAME=m2pvpk

if [ "$1" = "help" ] ; then 
  echo "${CORENAME}_mpb: help is not currently implemented to any great extent"
  echo 
#  echo "THIS IS THE WRONG HELP"
#  echo 
#  echo 
#  echo 
#  echo "This is a bash shell script which does a lot of unix stream editing"
#  echo "to turn templates into a complete (or at least workable) xdmf file"
#  echo "that ParaView can load and display.""
#  echo 
#  echo "Behaviour is controlled largely by special local files. If a local"
#  echo "version is not present, it will look at the parent directories, or"
#  echo "(try to) assume something sensible.
#  echo "The files are:"
#  echo "    P.name     - the simulation name as per the mpb ctl file"
#  echo "    P.xdmflist - the list of meep outputs to put into the xdmf file"
#  echo "               - this is a space-separated list of colon-separated quadruplets"
#  echo "               - 1. vector|scalar"
#  echo "               - 2. filetag[?]"
#  echo "               - 3. hdf5_dataset_name[?]"
#  echo "               - 4. readable name"
#  echo "             e.g. \"vector:e?:e?:Electric_field scalar:eps:eps:Permittivity\"."
#  echo "             The optional \"?\" is replaced by x,y,z as needed for vector elements."
#  echo "             Here e?:e? means that (eg) the x component is found in a filename"
#  echo "             containing \"-ex-\", in dataset ex; cf \"e:e?\" would mean that all "
#  echo "             the ex, ey, az datasets are in a file named with just \"-e-\"."
#  echo 
#  echo "WARNING:"
#  echo 
#  echo "Be aware that Paraview reads arrays in a different order to mpb so that"
#  echo "mpb axes of XYZ show up in ParaView in the order zyx (i.e. X and z are swapped)."
#  echo "Worse still, parallel mpb (but not serial) swaps Y and X array order to make a "
#  echo "confusing mess that cost a lot of time to sort out. This was complicated by the "
#  echo "(I strongly suspect, but cant be sure its not my maths libraries) that the latest "
#  echo "parallel mpb has a bug and unecessarily swaps the vector components of x and y."
#  echo "The result complicates the processing below, and you will want to independently test" 
#  echo "that the vector components shown are consistent with what you expect to see."
#  exit
fi

echo

HFILE=$1
SPREFIX=

SEDFILE=${HFILE%.h5}.sed
if [ -f ${SEDFILE} ] ; then 
  mv ${SEDFILE} old/
fi
touch ${SEDFILE}

ELABEL="${CORENAME}_mpb("${HFILE}")"

AXESFILE=MPB.axes
if [ ! -f $AXESFILE ] ; then 
  AXESFILE=../$AXESFILE
fi

if [ -f $AXESFILE ] ; then 
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
  echo ${ELABEL}: no dataset chosen, exitting...
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

echo "
s/___DATAPOST___/${DATAPOST}/" >> ${SEDFILE}

# see old versions for "smart" resample/rebuild
DATASET_RESAMPLE=yes

KTOKEN=$(echo $HFILE | awk -Fk '{print$2}' | awk -F. '{print$1}') 
echo ${ELABEL}: KTOKEN=${KTOKEN}
if [ -f freq.lst ] ; then 
  KLINEW=$(grep "^ "${KTOKEN#0} freq.lst)
  KLINEWGOOD=true
else
  echo ${ELABEL}: "cannot find a freq.lst file!"
  KLINEW="0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0"
  KLINEWGOOD=false
fi
KVALUE=$(echo ${KLINEW} | awk -F, '{print$5}')
KVECTR=$(echo ${KLINEW} | awk -F, '{print$2" "$3" "$4}')
echo ${ELABEL}: KVALUE=${KVALUE}:KVECTR=${KVECTR}

K5VECTOR=$(h5dump -d "Bloch wavevector"  $HFILE| grep : | awk -F: '{print$2}')
K5X=$(echo $K5VECTOR | awk -F, '{print$1}')
K5Y=$(echo $K5VECTOR | awk -F, '{print$2}')
K5Z=$(echo $K5VECTOR | awk -F, '{print$3}')

# echo ${ELABEL}: K5-data: ${K5VECTOR}:${K5X}:${K5Y}:${K5Z}

# Calculate the number of periods needed to get a full oscillation cycle in, 
#  but stop at 10 to keep datafiles to minimum
#
#  nb: the trailing "1" is nth decimal and hence negligible
#      but saves me an if-empty-string check

NPPMAX=32
N5X=$(echo "scale=3; 0.5 / ${K5X} " | bc -l 2>/dev/null)1
N5X=$(echo "if (${N5X}>${NPPMAX}) ${NPPMAX} else ${N5X}"  | bc -l 2>/dev/null)

N5Y=$(echo "scale=3; 0.5 / ${K5Y} " | bc -l 2>/dev/null)1
N5Y=$(echo "if (${N5Y}>${NPPMAX}) ${NPPMAX} else ${N5Y}"  | bc -l 2>/dev/null)

N5Z=$(echo "scale=3; 0.5 / ${K5Z} " | bc -l 2>/dev/null)1
N5Z=$(echo "if (${N5Z}>${NPPMAX}) ${NPPMAX} else ${N5Z}"  | bc -l 2>/dev/null)

echo ${ELABEL}: "k-data: h5_kvector ${K5VECTOR}"
echo ${ELABEL}: "k-data: h5_kvector ${K5X}, ${K5Y}, ${K5Z}"
echo ${ELABEL}: "k-data: h5_periods ${N5X}, ${N5Y}, ${N5Z}"

#- - - - - - - - - - 
# k data

# these are ctl/geometric axes (not mpb-mpi output axes)
KVECTR=$(echo ${KVECTR})
KVECTOX=$(echo ${KVECTR} | awk '{print$1}') 
KVECTOY=$(echo ${KVECTR} | awk '{print$2}') 
KVECTOZ=$(echo ${KVECTR} | awk '{print$3}') 
echo ${ELABEL}: probe freq.lst for k-data: found k$KTOKEN is $KVALUE "(" $KVECTR "), allow smart replace with h5 kvalues"

# allow for mpb-mpi XY swap in 
if [ "${QMPIAXESWAP}" = "true" ] ; then
    KVECTR="${K5Y}, ${K5X}, ${K5Z}"
    KVECTOX=$K5Y
    KVECTOY=$K5X
    KVECTOZ=$K5Z
    echo ${ELABEL}: "k-data (updated): h5_kvector ${K5X}, ${K5Y}, ${K5Z}"
fi

#- - - - - - - - - - 
# data reprocessing - periodicity and resampling...

XH5RESAMPLE=$(safex_treecat P.resample)
if [ -z "${XH5RESAMPLE}" ] ; then 
  XH5RESAMPLE=32
  # echo ${ELABEL}: fallback resampling value: $XH5RESAMPLE
else
  echo ${ELABEL}: specific local resampling request: $XH5RESAMPLE
fi


#XM_RESAMPLE=" -x ${N5X} -y ${N5Y} -z ${N5Z} -n ${XH5RESAMPLE} "
XM_RESAMPLE=

if [ "${DATASET_RESAMPLE}" = "yes" ] ; then 
  if [ "${QMPIAXESWAP}" = "true" ] ; then 
    FIXAXES=" -T "
    QMPIAXESWAP="false"
  else
    FIXAXES=
  fi

  echo ${ELABEL}: "Auto-resample the raw data in ${HFILE} with h5_resample=${XH5RESAMPLE} and FIXAXES=${FIXAXES}"
  # do not specify a real or imag postfix so rephasing can be (is) done correctly 
  if [ -n "${FIXAXES}" ] ; then # mpb-mpi axis swappage
    mpb-data  ${FIXAXES} ${XM_RESAMPLE}  -d x   ${HFILE}
    mpb-data  ${FIXAXES} ${XM_RESAMPLE}  -d y   ${HFILE}
    mpb-data  ${FIXAXES} ${XM_RESAMPLE}  -d z   ${HFILE} 
    #h5ls  ${HFILE} 
    echo h5_periods: ${XM_RESAMPLE} > ${HFILE%.h5}.nnn
  else
    mpb-data  ${XM_RESAMPLE}  -d x   ${HFILE} 
    mpb-data  ${XM_RESAMPLE}  -d y   ${HFILE} 
    mpb-data  ${XM_RESAMPLE}  -d z   ${HFILE} 
    #h5ls  ${HFILE} 
    echo h5_periods: ${XM_RESAMPLE} > ${HFILE%.h5}.nnn
  fi
else
  echo ${ELABEL}: "no resampling requested or done"
fi

BTOKEN=$(echo $HFILE | awk -Fb '{print$2}' | awk -F. '{print$1}') 
BOFFST=$(( ${BTOKEN#0} + 4 ))
WVALUE=$(echo ${KLINEW} | awk -F, '{print$'${BOFFST}'}')
echo ${ELABEL}: "probe freq.lst for w-data: found b$BTOKEN at-column $BOFFST is ${WVALUE}."

#
#
#- - - - - - - - - - 

# ordinary vector component ordering
#JOINVECTORU=" JOIN( \$2, \$1, \$0 )"
JOINVECTOR=" JOIN( \$2, \$1, \$0 )"

# test whether I need the BAD_SILENCE mpb axis swap fixing...
QBADSILENCE=
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
  if [ "${XZHOST}" != "{XHOST}" ] ; then # sim was run on silence, which requires mystery xy swap
    echo ${ELABEL}: "compensate for BAD_SILENCE mpb axis swap in vector components: XYZ becomes yxz"
    JOINVECTOR=" JOIN( \$2, \$0, \$1 )"
    QBADSILENCE=true
  fi
fi 

echo "
s/___JOINVECTOR___/${JOINVECTOR}/"  >> ${SEDFILE}

echo ${ELABEL}: vector components in xdmf are $JOINVECTOR

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

# CI is input (geometric coordinate)
#     ... since vector components are named h5 fields, these are the same as mpb vector components
#     ... i.e. the mpi-mpb data repacking order is irrelevant (and should be fixed by now anyway)
#     -> change CI from geometric XYZ to mpb xyz since these are use in h5 field selection
# CP is the coordinate naming according to Paraview (zyx) not (xyz)

if [ -z "${QBADSILENCE}" ] ; then 
  echo ${ELABEL}: "Consistent or fixed vector components: XYZ stays xyz, but is pz,py,px"
  case "${CI_L0}" in
    "X")  CI_L0=x; CI_T1=y; CI_T2=z; CP_L0=z; CP_T1=y; CP_T2=x;;
    "Y")  CI_L0=y; CI_T1=z; CI_T2=x; CP_L0=y; CP_T1=x; CP_T2=z;;
    "Z")  CI_L0=z; CI_T1=x; CI_T2=y; CP_L0=x; CP_T1=z; CP_T2=y;;
    *) echo ${ELABEL}: bad CI_L0=${CI_L0}; exit;;
  esac
else
  echo ${ELABEL}: "BAD_SILENCE inconsistent vector components: XYZ is yxz, then pz,py,px"
  case "${CI_L0}" in
    "X")  CI_L0=y; CI_T1=x; CI_T2=z; CP_L0=y; CP_T1=z; CP_T2=x;; # XYZ>yxz>yzx
    "Y")  CI_L0=x; CI_T1=z; CI_T2=y; CP_L0=z; CP_T1=x; CP_T2=y;; # YZX>xzy>zxy
    "Z")  CI_L0=z; CI_T1=y; CI_T2=x; CP_L0=x; CP_T1=y; CP_T2=z;; # ZXY>zyx>xyz
    *) echo ${ELABEL}: bad CI_L0=${CI_L0}; exit;;
  esac
fi

echo ${ELABEL}: "Selected longitudinal axis is lg:${CI_L0}:p${CP_L0}"
echo ${ELABEL}: "Selected transverse  axes are t1:${CI_T1}:p${CP_T1}, t2:${CI_T2}:p${CP_T2}"

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
# I can't shuffle these, they are all locked to the h5 dataset structure.

# This "GRID" sizing/information is all based on the mpb-mpi coordinates!

XGOFF=0
GRIDPOINTS=$(h5ls $HFILE | grep x.$DATASET | awk -F\{ '{print$2}' | awk -F\} '{print$1}' | sed 's/,/ /g' | head -1)
GRIDPVXX=$(echo ${GRIDPOINTS} | awk '{print$1}')
GRIDPVYY=$(echo ${GRIDPOINTS} | awk '{print$2}')
GRIDPVZZ=$(echo ${GRIDPOINTS} | awk '{print$3}')

GRIDOFFX=$(echo "-(${GRIDPVXX}-1)/2" | bc -l)
GRIDOFFY=$(echo "-(${GRIDPVYY}-1)/2" | bc -l)
GRIDOFFZ=$(echo "-(${GRIDPVZZ}-1)/2" | bc -l)

XXXGRIDNAME=${XNAME}
XXXGRIDXYZ=${GRIDPOINTS}
XXXGRIDORIGIN=" ${GRIDOFFX} ${GRIDOFFY} ${GRIDOFFZ} "
XXXGRIDSPACING="1.00 1.00 1.00"
XXXGRIDFILE=${HFILE}

# use mpb's labels (nb: the mpb-mpi swapped yxz should be fixed by now back to xyz)
#     (there might be a case to be made that I should modify these rather than the 
#     JOINVECTOR definition, in order to cope with BAD_SILENCE)
XXXGRIDDSEX="x.${DATASET}"
XXXGRIDDSEY="y.${DATASET}"
XXXGRIDDSEZ="z.${DATASET}"

# these are CI versions because we are just going to use them as scalar values
#     so that paraview's axes-order choice is irrelevant (it only matters for
#     3d array packing and/or vector fields, and the array packing is sorted
#     out by the importing)
XXXGRIDDSL0="${CI_L0}.${DATASET}"
XXXGRIDDST1="${CI_T1}.${DATASET}"
XXXGRIDDST2="${CI_T2}.${DATASET}"

#- - - - - - - - - - 
echo ${ELABEL}:  
echo ${ELABEL}:  Now to make the derived datasets 



# . . . . . . 
HFILE_EPS=epsilon.h5
DNAME_EPS=epsilon.xx
D5SEP_EPS=${DNAME_EPS}
D5SET_EPS=${DNAME_EPS}

H5BINARYDIR=
#if [ -f P.oldh5bin ] ; then
#  H5BINARYDIR=/d/c1/local-S14.0/bin/
#fi

# - - - - 
# MAKE permittivity data
#if [ "${DATASET_REQUEST}" = "cooked" ] ; then 
#  D5SET_EPS=${DNAME_EPS}-new
#  if [ "${DATASET_REBUILD}" = "rebuild" ] ; then 
#    DATASET_TESTEP=
#  else
#    DATASET_TESTEP=$(h5ls $HFILE | grep ${D5SEP_EPS}-new )
#  fi
#  if [ -z "${DATASET_TESTEP}" ] ; then 
    echo ${ELABEL}: "making permittivity data..."
    echo ${ELABEL}: "cooked ${D5SET_EPS} ${DATASET_BUILDNOTE}, so make it (res ${XH5RESAMPLE}) from ${HFILE_EPS}:/${D5SEP_EPS}"
    # need a unique tmp filename in case this script is run in parallel
    # also remember whether mpb-mpi axes fswap has been fixed at resampling above
    HTEMP_EPS=tmp.${HFILE}
    mpb-data      ${FIXAXES}     ${XM_RESAMPLE}   -d ${D5SEP_EPS} -o ${HTEMP_EPS}       ${HFILE_EPS}
    h5math -e "d1"              -d ${D5SET_EPS} -a ${HFILE}           ${HTEMP_EPS}:${D5SEP_EPS}
    #ls -l ${HTEMP_EPS}
    h5ls ${HTEMP_EPS}
    rm ${HTEMP_EPS}
#  fi
  HFILE_EPS=${HFILE}
#fi
echo ${ELABEL}: ${DNAME_EPS} data is in ${HFILE_EPS}:/${D5SET_EPS}

echo "
s/___EPSIFILE___/${HFILE_EPS}/
s/___EPSISET___/${D5SET_EPS}/" >> ${SEDFILE}


# . . . . . . 
# . . . . . . 
# add some simple data

echo "${ELABEL}: attempt to add frequency $WVALUE, |k| $KVALUE"
h5math -e "${WVALUE}"  -a -n 1 -d frequency ${HFILE}
h5math -e "${KVALUE}"  -a -n 1 -d kmag     ${HFILE}
h5math -e "${KVECTOX}" -a -n 1 -d kx       ${HFILE}
h5math -e "${KVECTOY}" -a -n 1 -d ky       ${HFILE}
h5math -e "${KVECTOZ}" -a -n 1 -d kz       ${HFILE}
echo "${ELABEL}: attempt [end]"


# . . . . . . 
# . . . . . . 
DNAME_ET=Et
HFILE_ET=${HFILE}
D5SEP_ET=${DNAME_ET}.${DATAPREX}
D5SET_ET=${DNAME_ET}.${DATASET}
CALC_ET="sqrt(d1*d1+d2*d2)"

# - - - - 
# MAKE transverse field data
#   do not make a "raw" Et set because of potential confusion from un/swapped yx axes in mpb-mpi
#   only use the cooked "-new" data
#if [ "${DATASET_REBUILD}" = "rebuild" ] ; then 
#  DATASET_TESTET=
#else
#  DATASET_TESTET=$(h5ls ${HFILE} | grep ${D5SEP_ET} )
#fi
#if [ -z "${DATASET_TESTET}" ] ; then 
#  echo ${ELABEL}: "making transverse field data using "${DATAPREX}" ..."
#  XXMAKEET="${HFILE}:${CI_T1}.${DATAPREX} ${HFILE}:${CI_T2}.${DATAPREX}"
#  echo ${ELABEL}: "making raw/derived ${D5SEP_ET} data using "${XXMAKEET}
#  h5math -e "${CALC_ET}" -d ${D5SEP_ET} -a ${HFILE} ${XXMAKEET}
#fi

#if [ "${DATASET_REQUEST}" = "cooked" ] ; then 
#  if [ "${DATASET_REBUILD}" = "rebuild" ] ; then 
#    DATASET_TESTET=
#  else
#    DATASET_TESTET=${D5SEP_ET}-new
#    #DATASET_TESTET=$(h5ls $HFILE | grep ${D5SEP_ET}-new )
#  fi
#  if [ -z "${DATASET_TESTET}" ] ; then 
    XXMAKEET="${HFILE}:${CI_T1}.${DATAPREX}-new ${HFILE}:${CI_T2}.${DATAPREX}-new"
    echo ${ELABEL}: "cooked ${D5SET_ET} ${DATASET_BUILDNOTE}, so make it (res ${XH5RESAMPLE}) using "${XXMAKEET}
    # this has to be built directly from the resampled/rephased fields
    #  so that not only is the resampling/rephasing is correct,
    #  but also the possible mpb-mpi axis swap has been handled (ie reversed) correctly
    h5math -e "${CALC_ET}" -d ${D5SET_ET} -a ${HFILE} ${XXMAKEET}
    # mpb-data      ${FIXAXES}     ${XM_RESAMPLE}   -d ${D5SET_ET} -a ${HFILE} 
#  fi
#fi

echo "
s/___GRETFILE___/${HFILE_ET}/
s/___GRETSET___/${D5SET_ET}/" >> ${SEDFILE}

echo ${ELABEL}:  ${DNAME_ET} data is in ${HFILE_ET}:/${D5SET_ET}

# . . . . . . 
# . . . . . . 
HFILE_ANG=${HFILE}
DNAME_ANG=aL
D5SEP_ANG=${DNAME_ANG}.${DATAPREX}
D5SET_ANG=${DNAME_ANG}.${DATASET}
CALC_ANG="d1*d1/(d1*d1+d2*d2+d3*d3+1.0e-10)"

# - - - - 
# MAKE longitudinal field data
#   do not make a "raw" aL set because of potential confusion from un/swapped yx axes in mpb-mpi
#   only use the cooked "-new" data
#if [ "${DATASET_REBUILD}" = "rebuild" ] ; then 
#  DATASET_TESTAL=
#else
#  DATASET_TESTAL=$(h5ls ${HFILE} | grep ${D5SEP_ANG} )
#fi
#if [ -z "${DATASET_TESTAL}" ] ; then 
#  XXXLONG="${HFILE}:${CI_L0}.${DATAPREX}"
#  XXXTRAN="${HFILE}:${CI_T1}.${DATAPREX} ${HFILE}:${CI_T2}.${DATAPREX}"
#  echo ${ELABEL}: "making raw/derived ${D5SET_ANG} data using L@ "${XXXLONG} T@ ${XXXTRAN}
#    h5math -e "${CALC_ANG}" -d ${D5SEP_ANG} -a ${HFILE} ${XXXLONG} ${XXXTRAN}
#fi
#if [ "${DATASET_REQUEST}" = "cooked" ] ; then 
#  if [ "${DATASET_REBUILD}" = "rebuild" ] ; then 
#    DATASET_TESTAL=
#  else
#    DATASET_TESTAL={D5SEP_ANG}-new
#    #DATASET_TESTAL=$(h5ls $HFILE | grep ${D5SEP_ANG}-new )
#  fi
#  if [ -z "${DATASET_TESTAL}" ] ; then 
    echo ${ELABEL}: "cooked ${D5SET_ANG} ${DATASET_BUILDNOTE}, so make it (res ${XH5RESAMPLE})"
    XXMAKEAL="${HFILE}:${CI_L0}.${DATAPREX}-new ${HFILE}:${CI_T1}.${DATAPREX}-new ${HFILE}:${CI_T2}.${DATAPREX}-new"
    echo ${ELABEL}: "... using "${XXMAKEAL}
    # this has to be built directly from the resampled/rephased fields
    #  so that not only is the resampling/rephasing is correct,
    #  but also the possible mpb-mpi axis swap has been handled (ie reversed) correctly
    h5math -e "${CALC_ANG}" -d ${D5SET_ANG} -a ${HFILE} ${XXMAKEAL}
    # mpb-data      ${FIXAXES}     ${XM_RESAMPLE}   -d ${D5SET_ANG} -a ${HFILE}
#  fi
#fi

echo "
s/___ANGFILE___/${HFILE_ANG}/
s/___GRALSET___/${D5SET_ANG}/"   >> ${SEDFILE}

echo ${ELABEL}:  ${DNAME_ANG} data is in ${HFILE_ANG}:/${D5SET_ANG}

# . . . . . . 

if [ ! -f geom.h5 ] ; then 
  # make some dummy data as a drop-in, in case of missing files later
  h5math -e "0.00*d1"      -d zero geom.h5 ${HFILE}:x.${DATASET}
  h5math -e "0.00*d1+1" -a -d unit geom.h5 ${HFILE}:x.${DATASET}
fi

#- - - - - - - - - - 
# make some png's as a guide
if [ -f P.pngbuild ] ; then
  BUILD_PNGS=$(safex_cat P.pngbuild)
else
  BUILD_PNGS=
fi

#   attempt to match P/X axis choices
if [ -f P.pngcscale ] ; then 
  CSCALE=$(safex_cat P.pngcscale)" -C ${EPSIFILE} "
else
  CSCALE=" -m -0.5 -M 0.5 -C ${EPSIFILE} "
fi

if [ -z "${BUILD_PNGS}" ] ; then 
  echo ${ELABEL}: pngs not being built
else
  # longitudinal: input-X is my and py
  h5topng -Zc dkbluered  -S 2 -0 -${CM_L0} 0 -d ${CM_L0}.${DATASET} $CSCALE -o ${XNAME}-${CI_L0}E${CI_L0}-${DATASET}.png  ${HFILE}
  h5topng -Zc dkbluered  -S 2 -0 -${CM_L0} 0 -d ${CM_T1}.${DATASET} $CSCALE -o ${XNAME}-${CI_L0}E${CI_T1}-${DATASET}.png  ${HFILE}
  h5topng -Zc dkbluered  -S 2 -0 -${CM_L0} 0 -d ${CM_T2}.${DATASET} $CSCALE -o ${XNAME}-${CI_L0}E${CI_T2}-${DATASET}.png  ${HFILE}
  
  # transverse: true-YZ, but mpb-mpi xz, or P/X z'x'
  h5topng -Zc dkbluered  -S 2 -0 -${CM_T1} 0 -d ${CM_L0}.${DATASET}  $CSCALE  -o ${XNAME}-${CI_T1}E${CI_L0}-${DATASET}.png    ${HFILE}
  h5topng -Zc dkbluered  -S 2 -0 -${CM_T1} 0 -d ${CM_T1}.${DATASET}  $CSCALE  -o ${XNAME}-${CI_T1}E${CI_T1}-${DATASET}.png    ${HFILE}
  h5topng -Zc dkbluered  -S 2 -0 -${CM_T1} 0 -d ${CM_T2}.${DATASET}  $CSCALE  -o ${XNAME}-${CI_T1}E${CI_T2}-${DATASET}.png    ${HFILE}
  #
  h5topng -Zc dkbluered  -S 2 -0 -${CM_T2} 0 -d ${CM_L0}.${DATASET}  $CSCALE  -o ${XNAME}-${CI_T2}E${CI_L0}-${DATASET}.png    ${HFILE}
  h5topng -Zc dkbluered  -S 2 -0 -${CM_T2} 0 -d ${CM_T1}.${DATASET}  $CSCALE  -o ${XNAME}-${CI_T2}E${CI_T1}-${DATASET}.png    ${HFILE}
  h5topng -Zc dkbluered  -S 2 -0 -${CM_T2} 0 -d ${CM_T2}.${DATASET}  $CSCALE  -o ${XNAME}-${CI_T2}E${CI_T2}-${DATASET}.png    ${HFILE}
  #

  if [ ! -d png ] ; then 
    mkdir png
  fi
  mv *.png png/
fi

#- - - - - - - - - - 
#XXXGRIDDSET="x.${DATASET} \/y.${DATASET} \/z.${DATASET}"

  XXXTOPOLOG=3DCORECTMesh
  XXXGEOMETRY=ORIGIN_DXDYDZ
  XXXGRIDDIMS=3
  echo ${ELABEL}: XXXTOPOLOG=$XXXTOPOLOG
  echo ${ELABEL}: XXXGEOMETRY=$XXXGEOMETRY
  echo ${ELABEL}: XXXGRIDDIMS=$XXXGRIDDIMS

echo ${ELABEL}: XXXGRIDNAME=$XXXGRIDNAME
echo ${ELABEL}: XXXGRIDXYZ=$XXXGRIDXYZ
echo ${ELABEL}: XXXGRIDORIGIN=$XXXGRIDORIGIN
echo ${ELABEL}: XXXGRIDSPACING=$XXXGRIDSPACING
echo ${ELABEL}: XXXGRIDFILE=$XXXGRIDFILE
echo ${ELABEL}: XXXGRIDDSETx=$XXXGRIDDSEX
echo ${ELABEL}: XXXGRIDDSETy=$XXXGRIDDSEY
echo ${ELABEL}: XXXGRIDDSETz=$XXXGRIDDSEZ
echo ${ELABEL}: XXXGRIDDS_L0=$XXXGRIDDSL0
echo ${ELABEL}: XXXGRIDDS_T1=$XXXGRIDDST1
echo ${ELABEL}: XXXGRIDDS_T2=$XXXGRIDDST2

# relies on template using method of Jens Kleimann 
# http://permalink.gmane.org/gmane.comp.science.paraview.user/18156


FTEMPLATE=$(locate_template ${CORENAME}.mpb.template)

if [ ! -f "${FTEMPLATE}" ] ; then 
  echo ${ELABEL}: lib template $FTEMPLATE NOT found either, halt.
  exit 1
fi
FSCRIPT=$0

echo "
s/___KVALUE___/${KVALUE}/
s/___KVECTOX___/${KVECTOX}/
s/___KVECTOY___/${KVECTOY}/
s/___KVECTOZ___/${KVECTOZ}/
s/___KVECTR___/${KVECTR}/
s/___WVALUE___/${WVALUE}/" >> ${SEDFILE}

echo "
s/___GRIDNAME___/${XXXGRIDNAME}/
s/___GRIDTOPOLOGY___/${XXXTOPOLOG}/
s/___GRIDGEOMETRY___/${XXXGEOMETRY}/
s/___GRIDXYZ___/${XXXGRIDXYZ}/g
s/___GRIDDIMS___/${XXXGRIDDIMS}/
s/___GRIDORIGIN___/${XXXGRIDORIGIN}/
s/___GRIDSPACING___/${XXXGRIDSPACING}/
s/___GRIDFILE___/${XXXGRIDFILE}/g" >> ${SEDFILE}

echo "
s/___GRIDDSEX___/${XXXGRIDDSEX}/
s/___GRIDDSEY___/${XXXGRIDDSEY}/
s/___GRIDDSEZ___/${XXXGRIDDSEZ}/
s/___GRIDDSL0___/${XXXGRIDDSL0}/
s/___GRIDDST1___/${XXXGRIDDST1}/
s/___GRIDDST2___/${XXXGRIDDST2}/" >> ${SEDFILE}

SEDSMART=yes
if [ ${SEDSMART} = "yes" ] ; then
  echo ${ELABEL}: smart processing using custom sed file
  sed -f ${SEDFILE} ${FTEMPLATE} > ${XFILE}
else
  echo ${ELABEL}: standard processing using pipes
  sed    "s/___GRIDNAME___/${XXXGRIDNAME}/"         ${FTEMPLATE} \
  | sed  "s/___GRIDXYZ___/${XXXGRIDXYZ}/g"          \
  | sed  "s/___GRIDORIGIN___/${XXXGRIDORIGIN}/"     \
  | sed  "s/___GRIDSPACING___/${XXXGRIDSPACING}/"   \
  | sed  "s/___GRIDFILE___/${XXXGRIDFILE}/g"        \
  | sed  "s/___GRIDDSEX___/${XXXGRIDDSEX}/"         \
  | sed  "s/___GRIDDSEY___/${XXXGRIDDSEY}/"         \
  | sed  "s/___GRIDDSEZ___/${XXXGRIDDSEZ}/"         \
  | sed  "s/___GRIDDSL0___/${XXXGRIDDSL0}/"         \
  | sed  "s/___GRIDDST1___/${XXXGRIDDST1}/"         \
  | sed  "s/___GRIDDST2___/${XXXGRIDDST2}/"         \
  | sed  "s/___DATAPOST___/${DATAPOST}/"            \
  | sed  "s/___JOINVECTOR___/${JOINVECTOR}/"        \
  | sed  "s/___KVALUE___/${KVALUE}/"        \
  | sed  "s/___KVECTOX___/${KVECTOX}/"        \
  | sed  "s/___KVECTOY___/${KVECTOY}/"        \
  | sed  "s/___KVECTOZ___/${KVECTOZ}/"        \
  | sed  "s/___KVECTR___/${KVECTR}/"        \
  | sed  "s/___WVALUE___/${WVALUE}/"        \
  | sed  "s/___EPSIFILE___/${HFILE_EPS}/"            \
  | sed  "s/___EPSISET___/${D5SET_EPS}/"              \
  | sed  "s/___GRETFILE___/${HFILE_ET}/"            \
  | sed  "s/___GRETSET___/${D5SET_ET}/"              \
  | sed  "s/___ANGFILE___/${HFILE_ANG}/"        \
  | sed  "s/___GRALSET___/${D5SET_ANG}/"              \
  > ${XFILE}
fi

mv ${SEDFILE} old/

echo ${ELABEL}: WARNING NOTICE - template processing uses triple underscore to delineate substitutions
#echo ${ELABEL}: ${XFILE} pngs - $(ls ${XNAME}*png)

#paraview swaps axes xyz to zyx, but unclear if it handles vectors similarly!

if [ -f P.bundles ] ; then 
  tar --dereference -cjf ${XNAME}-bundle-${DATASET}.tar.bz2 ${XFILE} ${XINFO} ${FSCRIPT} ${FTEMPLATE} ${HFILE}  ${EPSIFILE} zero.h5 unit.h5 ${XNAME}*-${DATASET}.png

  #remove the info file since it's intended to explain make the tar/bundle
  rm ${XINFO}

  echo ${ELABEL}: bundle created as ${XNAME}-bundle-${DATASET}.tar.bz2
fi

echo ${ELABEL}: 
echo
