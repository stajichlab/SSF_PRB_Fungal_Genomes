#!/usr/bin/bash -l
#SBATCH -p short -c 2 --mem 2gb -N 1 -n 1

module load ncbi-table2asn
module load ncbi-asn_tools
BASE=Penicillium_sp._UM1743
SBT=../../lib/sbt/UM1743.sbt
table2asn -l paired-ends -V v -M n -c ef -i $BASE.fsa -o $BASE.sqn -Z \
	-t $SBT -euk -j "[organism=Penicillium sp.] [strain=UM1743] [gcode=1]"

asn2all -i $BASE.sqn -f d -v $BASE.aa -o $BASE.cds
